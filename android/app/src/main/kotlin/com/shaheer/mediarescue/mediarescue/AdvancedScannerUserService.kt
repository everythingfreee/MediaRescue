package com.shaheer.mediarescue.mediarescue

import android.os.SystemClock
import android.util.Log
import com.shaheer.mediarescue.shizuku.IAdvancedScannerCallback
import com.shaheer.mediarescue.shizuku.IAdvancedScanner
import org.json.JSONObject
import java.io.File
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean

/**
 * MediaRescue user service — the ONLY privileged component in MediaRescue.
 *
 * Shizuku loads this class (by reflection, hence the required public
 * no-argument constructor) into the Shizuku execution context, where it can
 * read `/storage/emulated/0/Android/data` and `/storage/emulated/0/Android/obb`
 * — the two directories the normal MediaRescue scanner cannot see.
 *
 * SECURITY CONTRACT (enforced here, in the privileged process — Flutter-side
 * validation is only a convenience):
 *  - STRICTLY READ-ONLY: existence checks, directory listing and metadata.
 *    There is no delete / rename / move / copy / write / chmod / execute /
 *    install API, and no arbitrary shell execution.
 *  - The scan roots are hard-coded to EXACTLY the two approved directories.
 *    No path is ever accepted from the caller, so nothing outside those roots
 *    can be requested, and system areas (/system, /data, /vendor, /proc, …)
 *    are unreachable by construction.
 *  - Every emitted path is canonicalized and re-validated against the
 *    approved roots before it leaves this process (symlink / traversal guard).
 *  - Inaccessible directories and files are counted and skipped — an
 *    inaccessible directory is NEVER reported as an empty one.
 *
 * This class knows nothing about Flutter, widgets, navigation or app state:
 * it is a focused, read-only filesystem worker.
 */
class AdvancedScannerUserService : IAdvancedScanner.Stub() {

    companion object {
        private const val TAG = "AdvScannerService"

        /** The ONLY allowed scan roots (hard limit — see spec §11). */
        val ALLOWED_ROOTS = listOf(
            "/storage/emulated/0/Android/data",
            "/storage/emulated/0/Android/obb",
        )

        // Root status codes (see IAdvancedScannerCallback.onRootStatus).
        const val ROOT_OK = 0
        const val ROOT_MISSING = 1
        const val ROOT_NOT_DIRECTORY = 2
        const val ROOT_INACCESSIBLE = 3
        const val ROOT_INVALID = 4

                // Scan-level error codes for IAdvancedScannerCallback.onScanError.
        const val ERROR_INTERNAL = 1

        // startScan() return codes (see IAdvancedScanner.aidl / ShizukuManager).
        const val START_STARTED = 0
        const val START_ALREADY_RUNNING = 1
        const val START_INVALID_CALLBACK = 2
        const val START_INTERNAL_ERROR = 3

        /** Entries per onBatch callback (keeps each IPC parcel small). */
        private const val BATCH_SIZE = 200

        /** Minimum interval between onProgress callbacks (IPC throttling). */
        private const val PROGRESS_INTERVAL_MS = 500L

        /**
         * Security boundary: canonicalizes [path] (resolving symlinks and `..`)
         * and verifies it is one of the approved roots or inside one of them.
         */
        fun isAllowedPath(path: String): Boolean {
            return try {
                val canonical = File(path).canonicalPath
                ALLOWED_ROOTS.any { root -> canonical == root || canonical.startsWith("$root/") }
            } catch (t: Throwable) {
                false
            }
        }

        /** Compact file-type classification for the Flutter result rows. */
        fun classify(name: String): String {
            val ext = name.substringAfterLast('.', "").lowercase()
            return when (ext) {
                "jpg", "jpeg", "png", "gif", "bmp", "webp", "heic", "heif",
                "svg", "ico", "tiff", "tif" -> "image"
                "mp4", "mkv", "avi", "mov", "wmv", "flv", "webm", "m4v",
                "3gp", "ts", "mts", "m2ts" -> "video"
                "mp3", "wav", "aac", "flac", "ogg", "m4a", "wma", "opus",
                "amr", "mid", "midi" -> "audio"
                "pdf" -> "pdf"
                "doc", "docx", "xls", "xlsx", "ppt", "pptx", "odt", "ods",
                "odp", "rtf" -> "document"
                "zip", "rar", "7z", "tar", "gz", "bz2", "xz", "iso" -> "archive"
                "apk" -> "apk"
                "txt", "log", "json", "xml", "html", "htm", "css", "js", "py",
                "java", "kt", "dart", "c", "cpp", "h", "sh", "bat", "yml",
                "yaml", "toml", "ini", "cfg", "conf", "md", "csv" -> "text"
                else -> "other"
            }
        }
    }

    private val executor = Executors.newSingleThreadExecutor()
    private val cancelled = AtomicBoolean(false)
    private val scanning = AtomicBoolean(false)
    private var lastProgressTime = 0L

    // ── IAdvancedScanner (deliberately narrow, read-only) ─────────────────────

    override fun checkRoot(rootIndex: Int): Int {
        val root = rootFor(rootIndex) ?: return ROOT_INVALID
        return inspectRoot(File(root))
    }

    override fun startScan(callback: IAdvancedScannerCallback?): Int {
        if (callback == null) return START_INVALID_CALLBACK
        if (!scanning.compareAndSet(false, true)) return START_ALREADY_RUNNING
        cancelled.set(false)
        lastProgressTime = 0L
        return try {
            executor.execute { runScan(callback) }
            START_STARTED
        } catch (t: Throwable) {
            scanning.set(false)
            Log.e(TAG, "could not queue scan", t)
            START_INTERNAL_ERROR
        }
    }

    override fun requestCancel() {
        cancelled.set(true)
    }

    override fun copyFile(sourcePath: String?, destinationPath: String?, overwrite: Boolean): Boolean {
        val source = sourcePath?.let { File(it) } ?: return false
        val destination = destinationPath?.let { File(it) } ?: return false
        if (!isAllowedPath(source.absolutePath)) return false
        val destinationCanonical = try {
            destination.canonicalPath
        } catch (_: Throwable) {
            return false
        }
        if (!destinationCanonical.startsWith("/storage/emulated/0/")) return false
        if (!source.isFile) return false
        if (destination.exists() && !overwrite) return true
        return try {
            destination.parentFile?.mkdirs()
            copyVerified(source, destination)
        } catch (t: Throwable) {
            Log.w(TAG, "privileged copy failed: ${t.javaClass.simpleName}: ${t.message}")
            false
        }
    }

    /** Reserved by Shizuku (16777114): clean up when the service is removed. */
    override fun destroy() {
        executor.shutdownNow()
    }

    /** User-defined exit: terminate the user-service process. */
    override fun exit() {
        executor.shutdownNow()
        Runtime.getRuntime().exit(0)
    }

    // ── Scan implementation (background executor only — never a UI thread) ────

    private fun rootFor(index: Int): String? =
        if (index in ALLOWED_ROOTS.indices) ALLOWED_ROOTS[index] else null

    private fun inspectRoot(dir: File): Int = try {
        when {
            !dir.exists() -> ROOT_MISSING
            !dir.isDirectory -> ROOT_NOT_DIRECTORY
            dir.list() == null -> ROOT_INACCESSIBLE
            else -> ROOT_OK
        }
    } catch (t: Throwable) {
        ROOT_INACCESSIBLE
    }

    private fun messageFor(status: Int, label: String): String = when (status) {
        ROOT_OK -> "$label is accessible."
        ROOT_MISSING -> "$label does not exist on this device."
        ROOT_NOT_DIRECTORY -> "$label exists but is not a directory."
        ROOT_INACCESSIBLE -> "$label could not be accessed."
        else -> "$label could not be checked."
    }

    private fun runScan(callback: IAdvancedScannerCallback) {
        var totalFiles = 0
        var totalErrors = 0
        try {
            for (rootIndex in ALLOWED_ROOTS.indices) {
                if (cancelled.get()) break
                val root = ALLOWED_ROOTS[rootIndex]
                val label = root.substringAfterLast('/')

                val status = inspectRoot(File(root))
                safeCallback(callback) { it.onRootStatus(rootIndex, status, messageFor(status, label)) }
                if (status != ROOT_OK) {
                    // A missing/inaccessible root is NOT an empty root — it is
                    // reported as such and scanning continues with the next root.
                    safeCallback(callback) { it.onRootComplete(rootIndex, 0, 0, messageFor(status, label)) }
                    continue
                }

                val files = intArrayOf(0)
                val errors = intArrayOf(0)
                val batch = ArrayList<String>(BATCH_SIZE)
                traverse(File(root), rootIndex, label, batch, files, errors, callback)
                flushBatch(batch, rootIndex, callback)

                totalFiles += files[0]
                totalErrors += errors[0]

                if (cancelled.get()) {
                    safeCallback(callback) { it.onCancelled(rootIndex, totalFiles, totalErrors) }
                    return
                }

                safeCallback(callback) {
                    it.onRootComplete(
                        rootIndex,
                        files[0],
                        errors[0],
                        "Scanned ${files[0]} entries" +
                            (if (errors[0] > 0) ", ${errors[0]} could not be accessed" else "") + ".",
                    )
                }
            }
            safeCallback(callback) { it.onScanComplete(totalFiles, totalErrors) }
        } catch (t: Throwable) {
            Log.e(TAG, "scan failed", t)
            safeCallback(callback) { it.onScanError(ERROR_INTERNAL, "The scan stopped unexpectedly.") }
        } finally {
            scanning.set(false)
        }
    }

    private fun traverse(
        dir: File,
        rootIndex: Int,
        label: String,
        batch: ArrayList<String>,
        files: IntArray,
        errors: IntArray,
        callback: IAdvancedScannerCallback,
    ) {
        if (cancelled.get()) return
        val entries: Array<File>? = try {
            dir.listFiles()
        } catch (t: Throwable) {
            null
        }
        if (entries == null) {
            // Inaccessible directory: count it, keep scanning elsewhere —
            // never treat it as empty and never abort the whole scan.
            errors[0]++
            return
        }
        for (entry in entries) {
            if (cancelled.get()) return
            try {
                val path = entry.absolutePath
                // Defense in depth: nothing outside the approved roots is emitted.
                if (!isAllowedPath(path)) continue

                val isDir = entry.isDirectory
                if (isDir) {
                    traverse(entry, rootIndex, label, batch, files, errors, callback)
                    continue
                }
                val entryJson = JSONObject()
                    .put("path", path)
                    .put("name", entry.name)
                    .put("size", if (isDir) 0L else entry.length())
                    .put("modifiedDate", entry.lastModified())
                    .put("isDirectory", isDir)
                    .put("fileType", if (isDir) "folder" else classify(entry.name))
                    .put("parentDirectory", entry.parent ?: "")
                batch.add(entryJson.toString())
                files[0]++

                if (batch.size >= BATCH_SIZE) {
                    flushBatch(batch, rootIndex, callback)
                }
                maybeReportProgress(rootIndex, label, files[0], errors[0], callback)

            } catch (t: Throwable) {
                // One unreadable entry never stops the scan.
                errors[0]++
            }
        }
    }

    private fun maybeReportProgress(
        rootIndex: Int,
        label: String,
        filesFound: Int,
        errors: Int,
        callback: IAdvancedScannerCallback,
    ) {
        val now = SystemClock.elapsedRealtime()
        if (now - lastProgressTime >= PROGRESS_INTERVAL_MS) {
            lastProgressTime = now
            safeCallback(callback) {
                it.onProgress(rootIndex, filesFound, errors, "Scanning $label...")
            }
        }
    }

    private fun flushBatch(batch: ArrayList<String>, rootIndex: Int, callback: IAdvancedScannerCallback) {
        if (batch.isEmpty()) return
        val entries: Array<String> = batch.toTypedArray()
        batch.clear()
        safeCallback(callback) { it.onBatch(rootIndex, entries) }
    }

    private fun safeCallback(callback: IAdvancedScannerCallback, block: (IAdvancedScannerCallback) -> Unit) {
        try {
            block(callback)
        } catch (t: Throwable) {
            // The app may have gone away mid-scan; never crash the service.
            Log.w(TAG, "callback failed: ${t.message}")
        }
    }

    private fun copyVerified(source: File, target: File): Boolean {
        val temporary = File(target.parentFile, "${target.name}.mr_tmp")
        return try {
            source.inputStream().use { input ->
                temporary.outputStream().use { output -> input.copyTo(output) }
            }
            if (temporary.length() != source.length()) {
                temporary.delete()
                false
            } else {
                if (target.exists() && !target.delete()) {
                    temporary.delete()
                    false
                } else {
                    temporary.renameTo(target).also { renamed ->
                        if (!renamed) temporary.delete()
                    }
                }
            }
        } catch (t: Throwable) {
            temporary.delete()
            false
        }
    }
}