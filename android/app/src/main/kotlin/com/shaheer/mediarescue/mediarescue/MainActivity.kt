package com.shaheer.mediarescue.mediarescue

import android.Manifest
import android.content.ActivityNotFoundException
import android.content.Intent
import android.content.SharedPreferences
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaMetadataRetriever
import android.media.MediaScannerConnection
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Environment
import android.provider.Settings
import android.provider.DocumentsContract
import android.webkit.MimeTypeMap
import androidx.core.content.FileProvider
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean
import org.json.JSONArray
import org.json.JSONObject

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.shaheer.mediarescue/storage"
    private val SCAN_EVENTS = "com.shaheer.mediarescue/scan_events"
    private val REQUEST_CODE_STORAGE_PERMISSION = 2001

    private val executor = Executors.newSingleThreadExecutor()
    private val scanning = AtomicBoolean(false)
    private var scanEventSink: EventChannel.EventSink? = null

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // ── Method channel for storage operations ─────────────────────────────
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "hasAllFilesAccess" -> result.success(hasAllFilesAccess())
                    "requestAllFilesAccess" -> {
                        requestAllFilesAccess()
                        result.success(true)
                    }
                    "listDirectory" -> handleListDirectory(call, result)
                    "scanDirectory" -> handleScanDirectory(call, result)
                    "getStorageRoots" -> handleGetStorageRoots(result)
                    "getThumbnail" -> handleGetThumbnail(call, result)
                    "deleteFiles" -> handleDeleteFiles(call, result)
                    "copyFiles" -> handleCopyFiles(call, result)
                    "moveFiles" -> handleMoveFiles(call, result)
                    "getFileBytes" -> handleGetFileBytes(call, result)
                    "renameFile" -> handleRenameFile(call, result)
                    "copyFileVerified" -> handleCopyFileVerified(call, result)
                    "getFileMediaInfo" -> handleGetFileMediaInfo(call, result)
                    "indexMedia" -> handleIndexMedia(call, result)
                    "createDirectory" -> handleCreateDirectory(call, result)
                    "shareFile" -> handleShareFile(call, result)
                    "openFileLocation" -> handleOpenFileLocation(call, result)
                    "getRescueSettings" -> handleGetRescueSettings(result)
                    "saveRescueSettings" -> handleSaveRescueSettings(call, result)
                    "getAppPrefBool" -> handleGetAppPrefBool(call, result)
                    "setAppPrefBool" -> handleSetAppPrefBool(call, result)
                    "startScan" -> handleStartScan(result)
                    "stopScan" -> {
                        scanning.set(false)
                        result.success(true)
                    }
                    "saveScanData" -> handleSaveScanData(call, result)
                    "loadScanData" -> handleLoadScanData(result)
                    "clearScanData" -> handleClearScanData(result)
                    else -> result.notImplemented()
                }
            }

        // ── Event channel for scan progress streaming ─────────────────────────
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, SCAN_EVENTS)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    scanEventSink = events
                }

                override fun onCancel(arguments: Any?) {
                    scanEventSink = null
                }
            })
    }

    // ═══════════════════════════════════════════════════════════════════════════
    //  PERMISSION
    // ═══════════════════════════════════════════════════════════════════════════

    private fun hasAllFilesAccess(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            Environment.isExternalStorageManager()
        } else {
            val readGranted = checkSelfPermission(Manifest.permission.READ_EXTERNAL_STORAGE) ==
                PackageManager.PERMISSION_GRANTED
            val writeGranted = checkSelfPermission(Manifest.permission.WRITE_EXTERNAL_STORAGE) ==
                PackageManager.PERMISSION_GRANTED
            readGranted && writeGranted
        }
    }

    private fun requestAllFilesAccess() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            // Android 11+ → open the official "All files access" settings page
            try {
                val intent = Intent(Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION)
                intent.data = Uri.parse("package:$packageName")
                startActivity(intent)
            } catch (e: Exception) {
                try {
                    val intent = Intent(Settings.ACTION_MANAGE_ALL_FILES_ACCESS_PERMISSION)
                    startActivity(intent)
                } catch (e2: Exception) {
                    val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                    intent.data = Uri.parse("package:$packageName")
                    startActivity(intent)
                }
            }
        } else {
            // Android 10 and below → request runtime storage permissions
            requestPermissions(
                arrayOf(
                    Manifest.permission.READ_EXTERNAL_STORAGE,
                    Manifest.permission.WRITE_EXTERNAL_STORAGE
                ),
                REQUEST_CODE_STORAGE_PERMISSION
            )
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        // Result is polled by Flutter via hasAllFilesAccess() on resume.
    }

    // ═══════════════════════════════════════════════════════════════════════════
    //  DIRECTORY LISTING
    // ═══════════════════════════════════════════════════════════════════════════

    private fun handleListDirectory(call: MethodCall, result: MethodChannel.Result) {
        val path = call.argument<String>("path")
        executor.execute {
            try {
                val dir = if (path.isNullOrEmpty()) {
                    Environment.getExternalStorageDirectory() ?: File("/storage/emulated/0")
                } else {
                    File(path)
                }
                val filesList = mutableListOf<Map<String, Any>>()
                if (dir.exists() && dir.isDirectory) {
                    val children = dir.listFiles() ?: emptyArray()
                    for (child in children) {
                        try {
                            filesList.add(fileToMap(child))
                        } catch (e: Exception) {
                            // Skip inaccessible file, continue listing
                        }
                    }
                }
                runOnUiThread { result.success(filesList) }
            } catch (e: Exception) {
                runOnUiThread { result.error("LIST_ERROR", e.message, null) }
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════════════════
    //  DIRECTORY SCANNER (for Gallery)
    // ═══════════════════════════════════════════════════════════════════════════

    private fun handleScanDirectory(call: MethodCall, result: MethodChannel.Result) {
        val path = call.argument<String>("path")
        executor.execute {
            try {
                val root = File(path ?: Environment.getExternalStorageDirectory()?.absolutePath ?: "/storage/emulated/0")
                val filesList = mutableListOf<Map<String, Any>>()
                if (root.exists() && root.isDirectory) {
                    val stack = ArrayDeque<File>()
                    stack.add(root)
                    while (stack.isNotEmpty()) {
                        val dir = stack.removeLast()
                        val children = try {
                            dir.listFiles()
                        } catch (e: Exception) {
                            null
                        } ?: continue
                        for (child in children) {
                            try {
                                if (child.isDirectory) {
                                    if (!isSymlink(child)) {
                                        stack.add(child)
                                    }
                                } else {
                                    filesList.add(fileToMap(child))
                                }
                            } catch (e: Exception) {
                                // Skip inaccessible file
                            }
                        }
                    }
                }
                runOnUiThread { result.success(filesList) }
            } catch (e: Exception) {
                runOnUiThread { result.error("SCAN_DIR_ERROR", e.message, null) }
            }
        }
    }

    private fun handleGetStorageRoots(result: MethodChannel.Result) {
        executor.execute {
            try {
                val roots = mutableListOf<Map<String, Any>>()
                val primary = Environment.getExternalStorageDirectory()
                if (primary != null && primary.exists()) {
                    roots.add(
                        mapOf(
                            "path" to primary.absolutePath,
                            "name" to "Internal Storage",
                            "type" to "internal"
                        )
                    )
                }
                // Add external SD card if present
                val externalDirs = getExternalFilesDirs(null)
                val seen = mutableSetOf<String>()
                for (dir in externalDirs) {
                    if (dir == null) continue
                    val path = dir.absolutePath
                    // Extract the actual storage root (e.g. /storage/XXXX-XXXX)
                    val storageRoot = extractStorageRoot(path) ?: continue
                    if (seen.add(storageRoot) && storageRoot != primary?.absolutePath) {
                        roots.add(
                            mapOf(
                                "path" to storageRoot,
                                "name" to "SD Card",
                                "type" to "external"
                            )
                        )
                    }
                }
                runOnUiThread { result.success(roots) }
            } catch (e: Exception) {
                runOnUiThread { result.error("ROOTS_ERROR", e.message, null) }
            }
        }
    }

    private fun extractStorageRoot(path: String): String? {
        // Paths look like /storage/XXXX-XXXX/Android/data/...
        val parts = path.split("/")
        if (parts.size >= 3 && parts[1] == "storage") {
            return "/${parts[1]}/${parts[2]}"
        }
        return null
    }

    // ═══════════════════════════════════════════════════════════════════════════
    //  FULL STORAGE SCANNER
    // ═══════════════════════════════════════════════════════════════════════════

    private fun handleStartScan(result: MethodChannel.Result) {
        if (scanning.get()) {
            result.success(false)
            return
        }
        scanning.set(true)
        result.success(true)

        executor.execute {
            try {
                scanStorage()
            } catch (e: Exception) {
                emitError(e.message ?: "Scan failed")
            } finally {
                scanning.set(false)
            }
        }
    }

    private fun scanStorage() {
        val root = Environment.getExternalStorageDirectory() ?: File("/storage/emulated/0")
        val stack = ArrayDeque<File>()
        stack.add(root)

        var filesDiscovered = 0
        var dirsScanned = 0
        val batch = mutableListOf<Map<String, Any>>()

        while (stack.isNotEmpty() && scanning.get()) {
            val dir = stack.removeLast()
            dirsScanned++

            // Emit progress periodically so the UI stays responsive
            if (dirsScanned % 25 == 0) {
                emitProgress(filesDiscovered, dir.absolutePath, dirsScanned)
            }

            val children = try {
                dir.listFiles()
            } catch (e: Exception) {
                null // Inaccessible directory → skip it, keep scanning
            } ?: continue

            for (child in children) {
                if (!scanning.get()) break
                try {
                    if (child.isDirectory) {
                        // Skip symlinks to avoid infinite loops
                        if (!isSymlink(child)) {
                            stack.add(child)
                        }
                    } else {
                        filesDiscovered++
                        batch.add(fileToMap(child))
                        if (batch.size >= 500) {
                            emitBatch(batch.toList())
                            batch.clear()
                        }
                    }
                } catch (e: Exception) {
                    // Skip inaccessible file, continue scanning
                }
            }
        }

        if (batch.isNotEmpty()) {
            emitBatch(batch)
        }
        emitComplete(filesDiscovered)
    }

    private fun isSymlink(file: File): Boolean {
        return try {
            file.canonicalPath != file.absolutePath
        } catch (e: Exception) {
            true
        }
    }

    // ── Scan event emission ────────────────────────────────────────────────────

    private fun emitProgress(files: Int, path: String, dirs: Int) {
        runOnUiThread {
            scanEventSink?.success(
                mapOf(
                    "type" to "progress",
                    "filesDiscovered" to files,
                    "currentPath" to path,
                    "dirsScanned" to dirs
                )
            )
        }
    }

    private fun emitBatch(files: List<Map<String, Any>>) {
        runOnUiThread {
            scanEventSink?.success(
                mapOf(
                    "type" to "batch",
                    "files" to files
                )
            )
        }
    }

    private fun emitComplete(totalFiles: Int) {
        runOnUiThread {
            scanEventSink?.success(
                mapOf(
                    "type" to "complete",
                    "totalFiles" to totalFiles
                )
            )
        }
    }

    private fun emitError(message: String) {
        runOnUiThread {
            scanEventSink?.success(
                mapOf(
                    "type" to "error",
                    "message" to message
                )
            )
        }
    }

    // ═══════════════════════════════════════════════════════════════════════════
    //  SCAN DATA PERSISTENCE
    // ═══════════════════════════════════════════════════════════════════════════

    private fun getScanDataFile(): File {
        return File(filesDir, "scan_data.json")
    }

    private fun handleSaveScanData(call: MethodCall, result: MethodChannel.Result) {
        val files = call.argument<List<Map<String, Any>>>("files") ?: emptyList()
        executor.execute {
            try {
                val jsonArray = JSONArray()
                for (file in files) {
                    jsonArray.put(JSONObject(file))
                }
                val json = JSONObject().put("files", jsonArray)
                val file = getScanDataFile()
                FileOutputStream(file).use { it.write(json.toString().toByteArray()) }
                runOnUiThread { result.success(true) }
            } catch (e: Exception) {
                runOnUiThread { result.error("SAVE_ERROR", e.message, null) }
            }
        }
    }

    private fun handleLoadScanData(result: MethodChannel.Result) {
        executor.execute {
            try {
                val file = getScanDataFile()
                if (!file.exists()) {
                    runOnUiThread { result.success(emptyList<Map<String, Any>>()) }
                    return@execute
                }
                val jsonStr = file.readText()
                val json = JSONObject(jsonStr)
                val jsonArray = json.getJSONArray("files")
                val files = mutableListOf<Map<String, Any>>()
                for (i in 0 until jsonArray.length()) {
                    val obj = jsonArray.getJSONObject(i)
                    val map = mutableMapOf<String, Any>()
                    val keys = obj.keys()
                    while (keys.hasNext()) {
                        val key = keys.next()
                        map[key] = obj.get(key)
                    }
                    files.add(map)
                }
                runOnUiThread { result.success(files) }
            } catch (e: Exception) {
                runOnUiThread { result.success(emptyList<Map<String, Any>>()) }
            }
        }
    }

    private fun handleClearScanData(result: MethodChannel.Result) {
        executor.execute {
            try {
                val file = getScanDataFile()
                if (file.exists()) file.delete()
                runOnUiThread { result.success(true) }
            } catch (e: Exception) {
                runOnUiThread { result.success(false) }
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════════════════
    //  FILE OPERATIONS
    // ═══════════════════════════════════════════════════════════════════════════

    private fun handleDeleteFiles(call: MethodCall, result: MethodChannel.Result) {
        val paths = call.argument<List<String>>("paths")
        executor.execute {
            try {
                var allDeleted = true
                // Collect all concrete file paths before deleting so MediaStore
                // entries can be removed after the operation.
                val scannedPaths = mutableListOf<String>()
                paths?.forEach { path ->
                    try {
                        val file = File(path)
                        if (file.exists()) {
                            collectFilePathsRecursively(file, scannedPaths)
                            if (!deleteRecursively(file)) allDeleted = false
                        }
                    } catch (e: Exception) {
                        allDeleted = false
                    }
                }
                if (scannedPaths.isNotEmpty()) {
                    scanMediaPaths(scannedPaths)
                }
                runOnUiThread { result.success(allDeleted) }
            } catch (e: Exception) {
                runOnUiThread { result.error("DELETE_ERROR", e.message, null) }
            }
        }
    }

    private fun deleteRecursively(file: File): Boolean {
        return if (file.isDirectory) {
            val children = file.listFiles() ?: return file.delete()
            var success = true
            for (child in children) {
                if (!deleteRecursively(child)) success = false
            }
            file.delete() && success
        } else {
            file.delete()
        }
    }

    private fun handleCopyFiles(call: MethodCall, result: MethodChannel.Result) {
        val sourcePaths = call.argument<List<String>>("sourcePaths")
        val destPath = call.argument<String>("destinationPath")
        executor.execute {
            try {
                val destDir = File(destPath)
                var allCopied = true
                val scannedPaths = mutableListOf<String>()
                if (destDir.exists() && destDir.isDirectory) {
                    sourcePaths?.forEach { path ->
                        try {
                            val source = File(path)
                            if (source.exists()) {
                                val target = File(destDir, source.name)
                                if (!copyRecursively(source, target)) allCopied = false
                                scannedPaths.add(target.absolutePath)
                            }
                        } catch (e: Exception) {
                            allCopied = false
                        }
                    }
                }
                // Index the freshly created copies so gallery apps see them immediately.
                if (scannedPaths.isNotEmpty()) {
                    scanMediaPaths(scannedPaths)
                }
                runOnUiThread { result.success(allCopied) }
            } catch (e: Exception) {
                runOnUiThread { result.error("COPY_ERROR", e.message, null) }
            }
        }
    }

    private fun copyRecursively(source: File, target: File): Boolean {
        return if (source.isDirectory) {
            if (!target.exists() && !target.mkdirs()) return false
            val children = source.listFiles() ?: return true
            var success = true
            for (child in children) {
                if (!copyRecursively(child, File(target, child.name))) success = false
            }
            success
        } else {
            try {
                FileInputStream(source).use { input ->
                    target.outputStream().use { output ->
                        input.copyTo(output)
                    }
                }
                true
            } catch (e: Exception) {
                false
            }
        }
    }

    private fun handleMoveFiles(call: MethodCall, result: MethodChannel.Result) {
        val sourcePaths = call.argument<List<String>>("sourcePaths")
        val destPath = call.argument<String>("destinationPath")
        executor.execute {
            try {
                val destDir = File(destPath)
                var allMoved = true
                val scannedPaths = mutableListOf<String>()
                if (destDir.exists() && destDir.isDirectory) {
                    sourcePaths?.forEach { path ->
                        try {
                            val source = File(path)
                            if (source.exists()) {
                                val target = File(destDir, source.name)
                                val moved = source.renameTo(target)
                                if (!moved) {
                                    // Fallback: copy + delete
                                    if (copyRecursively(source, target)) {
                                        if (!deleteRecursively(source)) allMoved = false
                                    } else {
                                        allMoved = false
                                    }
                                }
                                scannedPaths.add(target.absolutePath)
                                scannedPaths.add(source.absolutePath)
                            }
                        } catch (e: Exception) {
                            allMoved = false
                        }
                    }
                }
                // Index the new location and *also* scan the old (now missing) paths so
                // stale MediaStore entries are removed and gallery apps update instantly.
                if (scannedPaths.isNotEmpty()) {
                    scanMediaPaths(scannedPaths)
                }
                runOnUiThread { result.success(allMoved) }
            } catch (e: Exception) {
                runOnUiThread { result.error("MOVE_ERROR", e.message, null) }
            }
        }
    }

    private fun handleRenameFile(call: MethodCall, result: MethodChannel.Result) {
        val path = call.argument<String>("path")
        val newName = call.argument<String>("newName")
        executor.execute {
            try {
                val file = File(path)
                var scannedPaths = mutableListOf<String>()
                val success = if (file.exists() && !newName.isNullOrEmpty()) {
                    val parent = file.parentFile
                    val newFile = File(parent, newName)
                    if (file.renameTo(newFile)) {
                        scannedPaths = mutableListOf(file.absolutePath, newFile.absolutePath)
                        true
                    } else {
                        false
                    }
                } else {
                    false
                }
                if (scannedPaths.isNotEmpty()) {
                    scanMediaPaths(scannedPaths)
                }
                runOnUiThread { result.success(success) }
            } catch (e: Exception) {
                runOnUiThread { result.error("RENAME_ERROR", e.message, null) }
            }
        }
    }

    private fun handleGetFileBytes(call: MethodCall, result: MethodChannel.Result) {
        val path = call.argument<String>("path")
        executor.execute {
            try {
                val file = File(path)
                var bytes: ByteArray? = null
                if (file.exists() && file.isFile) {
                    bytes = FileInputStream(file).use { it.readBytes() }
                }
                runOnUiThread { result.success(bytes) }
            } catch (e: Exception) {
                runOnUiThread { result.error("FILE_READ_ERROR", e.message, null) }
            }
        }
    }

    private fun handleGetThumbnail(call: MethodCall, result: MethodChannel.Result) {
        val path = call.argument<String>("path")
        executor.execute {
            try {
                val file = File(path)
                var thumbnailBytes: ByteArray? = null
                if (file.exists() && file.isFile) {
                    val ext = file.name.substringAfterLast('.', "").lowercase()
                    val isImage = ext in listOf("jpg", "jpeg", "png", "gif", "bmp", "webp", "heic", "heif", "svg", "ico", "tiff", "tif")
                    val isVideo = ext in listOf("mp4", "mkv", "avi", "mov", "wmv", "flv", "webm", "m4v", "3gp", "ts", "mts", "m2ts")

                    if (isImage) {
                        // Decode image with inSampleSize for performance
                        val opts = BitmapFactory.Options().apply { inJustDecodeBounds = true }
                        BitmapFactory.decodeFile(path, opts)
                        var sampleSize = 1
                        while (opts.outWidth / sampleSize > 256 || opts.outHeight / sampleSize > 256) {
                            sampleSize *= 2
                        }
                        val decodeOpts = BitmapFactory.Options().apply { inSampleSize = sampleSize }
                        val bitmap = BitmapFactory.decodeFile(path, decodeOpts)
                        if (bitmap != null) {
                            val stream = ByteArrayOutputStream()
                            bitmap.compress(Bitmap.CompressFormat.JPEG, 80, stream)
                            thumbnailBytes = stream.toByteArray()
                        }
                    } else if (isVideo) {
                        // Extract video frame as thumbnail
                        try {
                            val retriever = android.media.MediaMetadataRetriever()
                            retriever.setDataSource(path)
                            val frame = retriever.getFrameAtTime(1000000, android.media.MediaMetadataRetriever.OPTION_CLOSEST_SYNC)
                            retriever.release()
                            if (frame != null) {
                                val stream = ByteArrayOutputStream()
                                frame.compress(Bitmap.CompressFormat.JPEG, 80, stream)
                                thumbnailBytes = stream.toByteArray()
                            }
                        } catch (e: Exception) {
                            // Fall through - no thumbnail for video
                        }
                    }
                }
                runOnUiThread { result.success(thumbnailBytes) }
            } catch (e: Exception) {
                runOnUiThread { result.success(null) } // fail gracefully for thumbnails
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════════════════
    //  MEDIA INDEXING / PREVIEW + RESCUE SUPPORT
    // ═══════════════════════════════════════════════════════════════════════════

    /// Asks Android's MediaScanner to index (or re-index) the given paths so
    /// gallery apps see changes immediately. Scanning a path that no longer
    /// exists removes its stale MediaStore entry.
    private fun scanMediaPaths(paths: List<String>) {
        val validPaths = paths.filter { it.isNotBlank() }.distinct()
        if (validPaths.isEmpty()) return
        val mimeTypes = validPaths.map { getMimeType(File(it).name) }.toTypedArray()
        try {
            MediaScannerConnection.scanFile(this, validPaths.toTypedArray(), mimeTypes, null)
        } catch (e: Exception) {
            // Indexing is best-effort — never crash due to a scan failure.
        }
    }

    private fun collectFilePathsRecursively(file: File, out: MutableList<String>) {
        if (file.isDirectory) {
            file.listFiles()?.forEach { collectFilePathsRecursively(it, out) }
        } else {
            out.add(file.absolutePath)
        }
    }

    private fun handleIndexMedia(call: MethodCall, result: MethodChannel.Result) {
        val paths = call.argument<List<String>>("paths") ?: emptyList()
        executor.execute {
            scanMediaPaths(paths)
            runOnUiThread { result.success(true) }
        }
    }

    private fun handleCreateDirectory(call: MethodCall, result: MethodChannel.Result) {
        val path = call.argument<String>("path")
        executor.execute {
            try {
                val dir = File(path ?: "")
                val ok = if (dir.exists()) dir.isDirectory else dir.mkdirs()
                runOnUiThread { result.success(ok) }
            } catch (e: Exception) {
                runOnUiThread { result.error("MKDIR_ERROR", e.message, null) }
            }
        }
    }

    private fun handleCopyFileVerified(call: MethodCall, result: MethodChannel.Result) {
        val sourcePath = call.argument<String>("sourcePath")
        val destDirPath = call.argument<String>("destDirPath")
        val overwrite = call.argument<Boolean>("overwrite") ?: false
        executor.execute {
            try {
                val source = File(sourcePath ?: "")
                val destDir = File(destDirPath ?: "")
                var success = false
                var alreadyExists = false
                var targetPath = ""
                if (source.isFile) {
                    if (!destDir.exists() && !destDir.mkdirs()) {
                        runOnUiThread {
                            result.success(
                                mapOf(
                                    "success" to false,
                                    "targetPath" to targetPath,
                                    "alreadyExists" to false
                                )
                            )
                        }
                        return@execute
                    }
                    val target = File(destDir, source.name)
                    targetPath = target.absolutePath
                    if (target.exists()) {
                        if (overwrite) {
                            success = copyVerified(source, target)
                        } else {
                            alreadyExists = true
                        }
                    } else {
                        success = copyVerified(source, target)
                    }
                }
                runOnUiThread {
                    result.success(
                        mapOf(
                            "success" to success,
                            "targetPath" to targetPath,
                            "alreadyExists" to alreadyExists
                        )
                    )
                }
            } catch (e: Exception) {
                runOnUiThread { result.error("COPY_VERIFY_ERROR", e.message, null) }
            }
        }
    }

    private fun copyVerified(source: File, target: File): Boolean {
        val tmp = File(target.parentFile, "${target.name}.mr_tmp")
        return try {
            source.inputStream().use { input ->
                tmp.outputStream().use { output -> input.copyTo(output) }
            }
            val verified = tmp.exists() && tmp.length() == source.length()
            if (!verified) {
                tmp.delete()
                return false
            }
            if (target.exists() && !target.delete()) {
                tmp.delete()
                return false
            }
            val renamed = tmp.renameTo(target)
            if (renamed) return true
            // Fallback: stream tmp -> target, then verify again.
            try {
                target.outputStream().use { output ->
                    tmp.inputStream().use { input -> input.copyTo(output) }
                }
                val ok = target.exists() && target.length() == source.length()
                tmp.delete()
                ok
            } catch (e: Exception) {
                tmp.delete()
                false
            }
        } catch (e: Exception) {
            try { tmp.delete() } catch (_: Exception) {}
            false
        }
    }

    /// Extracts rich metadata for the Info panel using
    /// MediaMetadataRetriever / MediaExtractor / BitmapFactory.
    private fun handleGetFileMediaInfo(call: MethodCall, result: MethodChannel.Result) {
        val path = call.argument<String>("path")
        executor.execute {
            try {
                val file = File(path ?: "")
                if (!file.isFile) {
                    runOnUiThread { result.error("INFO_ERROR", "File not found", null) }
                    return@execute
                }
                val info = mutableMapOf<String, Any>()
                info["name"] = file.name
                info["size"] = file.length()
                info["modifiedDate"] = file.lastModified()
                info["extension"] = file.extension.lowercase()
                info["mimeType"] = getMimeType(file.name)

                var retriever: MediaMetadataRetriever? = null
                try {
                    retriever = MediaMetadataRetriever()
                    retriever.setDataSource(file.absolutePath)
                    val w = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_WIDTH)
                    val h = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_HEIGHT)
                    if (w != null && h != null) {
                        info["width"] = w.toInt()
                        info["height"] = h.toInt()
                    }
                    val dur = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)?.toLongOrNull()
                    if (dur != null && dur > 0) info["durationMs"] = dur
                    val frameRate = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_CAPTURE_FRAMERATE)?.toDoubleOrNull()
                    if (frameRate != null && frameRate > 0) info["frameRate"] = frameRate
                    val bitrate = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_BITRATE)?.toLongOrNull()
                    if (bitrate != null && bitrate > 0) info["bitrate"] = bitrate
                    val hasAudio = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_HAS_AUDIO)?.toIntOrNull()
                    if (hasAudio != null) info["hasAudio"] = hasAudio == 1
                    val hasVideo = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_HAS_VIDEO)?.toIntOrNull()
                    if (hasVideo != null) info["hasVideo"] = hasVideo == 1
                    val date = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DATE)
                    if (!date.isNullOrBlank()) info["creationDate"] = date
                } catch (e: Exception) {
                    // Not a media container (e.g. plain image) — continue.
                } finally {
                    try { retriever?.release() } catch (_: Exception) {}
                }

                // Image resolution fallback.
                if (!info.containsKey("width")) {
                    val opts = BitmapFactory.Options().apply { inJustDecodeBounds = true }
                    BitmapFactory.decodeFile(file.absolutePath, opts)
                    if (opts.outWidth > 0 && opts.outHeight > 0) {
                        info["width"] = opts.outWidth
                        info["height"] = opts.outHeight
                    }
                }

                // Per-track metadata (sample rate, channels, codecs, bitrate fallback).
                try {
                    val extractor = MediaExtractor()
                    extractor.setDataSource(file.absolutePath)
                    for (i in 0 until extractor.trackCount) {
                        val format = extractor.getTrackFormat(i)
                        val mime = format.getString(MediaFormat.KEY_MIME) ?: continue
                        if (mime.startsWith("audio/")) {
                            info["audioCodec"] = mime
                            if (format.containsKey(MediaFormat.KEY_SAMPLE_RATE)) {
                                info["sampleRate"] = format.getInteger(MediaFormat.KEY_SAMPLE_RATE)
                            }
                            if (format.containsKey(MediaFormat.KEY_CHANNEL_COUNT)) {
                                info["channels"] = format.getInteger(MediaFormat.KEY_CHANNEL_COUNT)
                            }
                            if (!info.containsKey("bitrate") && format.containsKey(MediaFormat.KEY_BIT_RATE)) {
                                info["bitrate"] = format.getLong(MediaFormat.KEY_BIT_RATE)
                            }
                        } else if (mime.startsWith("video/")) {
                            info["videoCodec"] = mime
                            if (!info.containsKey("bitrate") && format.containsKey(MediaFormat.KEY_BIT_RATE)) {
                                info["bitrate"] = format.getLong(MediaFormat.KEY_BIT_RATE)
                            }
                        }
                    }
                    extractor.release()
                } catch (e: Exception) {
                    // Optional — leave track info absent.
                }

                runOnUiThread { result.success(info) }
            } catch (e: Exception) {
                runOnUiThread { result.error("INFO_ERROR", e.message, null) }
            }
        }
    }

    /// Shares a local file via an ACTION_SEND intent (FileProvider uri).
    private fun handleShareFile(call: MethodCall, result: MethodChannel.Result) {
        val path = call.argument<String>("path")
        runOnUiThread {
            try {
                val file = File(path ?: "")
                if (!file.isFile) {
                    result.success(false)
                    return@runOnUiThread
                }
                val uri = FileProvider.getUriForFile(this, "$packageName.fileprovider", file)
                val intent = Intent(Intent.ACTION_SEND).apply {
                    type = getMimeType(file.name)
                    putExtra(Intent.EXTRA_STREAM, uri)
                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                }
                startActivity(Intent.createChooser(intent, "Share file"))
                result.success(true)
            } catch (e: Exception) {
                result.error("SHARE_ERROR", e.message ?: "Share failed", null)
            }
        }
    }

    /// Opens the phone's built-in file manager showing the folder that
    /// contains [path] (best effort — managers that ignore EXTRA_INITIAL_URI
    /// still open, but at their default location).
    private fun handleOpenFileLocation(call: MethodCall, result: MethodChannel.Result) {
        val path = call.argument<String>("path")
        runOnUiThread {
            val ok = revealFileLocation(path ?: "")
            result.success(ok)
        }
    }

    private val documentsAuthority = "com.android.externalstorage.documents"

    /// Builds a DocumentsContract document URI for a folder on the primary
    /// external storage volume, e.g.
    /// content://com.android.externalstorage.documents/document/primary%3ADCIM%2FCamera
    private fun buildPrimaryDirDocumentUri(relativeDir: String): Uri {
        val rel = relativeDir.trim('/', ' ')
        val documentId = if (rel.isEmpty()) "primary" else "primary:$rel"
        return DocumentsContract.buildDocumentUri(documentsAuthority, documentId)
    }

    private fun revealFileLocation(path: String): Boolean {
        val file = File(path)
        val parent = file.parentFile ?: file
        if (!parent.exists()) return false

        val storageRoot =
            Environment.getExternalStorageDirectory()?.absolutePath
                ?: return false
        val parentPath = parent.absolutePath

        // Only the primary volume can be addressed with a "primary:…" document
        // id; anything else falls back to opening the file manager directly.
        val targetDirUri: Uri? = if (parentPath == storageRoot || parentPath.startsWith("$storageRoot/")) {
            buildPrimaryDirDocumentUri(parentPath.removePrefix(storageRoot))
        } else {
            null
        }

        // 1) The built-in DocumentsUI (AOSP / Google Files), launched directly
        //    with the folder pre-selected.
        val dirMime = DocumentsContract.Document.MIME_TYPE_DIR
        if (targetDirUri != null) {
            for (pkg in listOf("com.android.documentsui", "com.google.android.documentsui")) {
                try {
                    val intent = Intent(Intent.ACTION_VIEW).apply {
                        setDataAndType(targetDirUri, dirMime)
                        addFlags(
                            Intent.FLAG_GRANT_READ_URI_PERMISSION or
                                Intent.FLAG_ACTIVITY_NEW_TASK
                        )
                        setPackage(pkg)
                        putExtra(DocumentsContract.EXTRA_INITIAL_URI, targetDirUri)
                    }
                    startActivity(intent)
                    return true
                } catch (e: Exception) {
                    // Try the next launcher.
                }
            }
            // 2) Any file manager that understands DocumentsContract folders.
            try {
                val intent = Intent(Intent.ACTION_VIEW).apply {
                    setDataAndType(targetDirUri, dirMime)
                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                    putExtra(DocumentsContract.EXTRA_INITIAL_URI, targetDirUri)
                }
                startActivity(intent)
                return true
            } catch (e: ActivityNotFoundException) {
                // Fall through to the storage-root fallback.
            }
            // 3) Last resort: the storage root, so the user at least lands in
            //    the file manager instead of an error.
            try {
                val rootUri = buildPrimaryDirDocumentUri("")
                val intent = Intent(Intent.ACTION_VIEW).apply {
                    setDataAndType(rootUri, dirMime)
                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                    putExtra(DocumentsContract.EXTRA_INITIAL_URI, rootUri)
                }
                startActivity(intent)
                return true
            } catch (e: Exception) {
                return false
            }
        }

        // Path outside the primary volume: open the file manager without a
        // pre-selected folder.
        return try {
            val intent = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(buildPrimaryDirDocumentUri(""), dirMime)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }
            startActivity(intent)
            true
        } catch (e: Exception) {
            false
        }
    }

    // ── Rescue destination settings persistence ─────────────────────────────────

    private fun getRescueSettingsFile(): File = File(filesDir, "rescue_settings.json")

    private fun defaultRescueSettings(): Map<String, Any> {
        val storage = Environment.getExternalStorageDirectory()?.absolutePath ?: "/storage/emulated/0"
        return mapOf(
            "singleDestination" to false,
            "singlePath" to "$storage/Pictures/MediaRescue",
            "images" to "$storage/Pictures/MediaRescue",
            "videos" to "$storage/Movies/MediaRescue",
            "audio" to "$storage/Music/MediaRescue",
            "other" to "$storage/Documents/MediaRescue"
        )
    }

    private fun handleGetRescueSettings(result: MethodChannel.Result) {
        executor.execute {
            try {
                val file = getRescueSettingsFile()
                val map = if (file.exists()) {
                    val obj = JSONObject(file.readText())
                    val defaults = defaultRescueSettings()
                    mapOf(
                        "singleDestination" to obj.optBoolean("singleDestination", false),
                        "singlePath" to obj.optString("singlePath", defaults["singlePath"] as String),
                        "images" to obj.optString("images", defaults["images"] as String),
                        "videos" to obj.optString("videos", defaults["videos"] as String),
                        "audio" to obj.optString("audio", defaults["audio"] as String),
                        "other" to obj.optString("other", defaults["other"] as String)
                    )
                } else {
                    defaultRescueSettings()
                }
                runOnUiThread { result.success(map) }
            } catch (e: Exception) {
                runOnUiThread { result.error("GET_SETTINGS_ERROR", e.message, null) }
            }
        }
    }

    private fun handleSaveRescueSettings(call: MethodCall, result: MethodChannel.Result) {
        val singleDestination = call.argument<Boolean>("singleDestination") ?: true
        val singlePath = call.argument<String>("singlePath") ?: ""
        val images = call.argument<String>("images") ?: ""
        val videos = call.argument<String>("videos") ?: ""
        val audio = call.argument<String>("audio") ?: ""
        val other = call.argument<String>("other") ?: ""
        executor.execute {
            try {
                val obj = JSONObject()
                obj.put("singleDestination", singleDestination)
                obj.put("singlePath", singlePath)
                obj.put("images", images)
                obj.put("videos", videos)
                obj.put("audio", audio)
                obj.put("other", other)
                FileOutputStream(getRescueSettingsFile()).use {
                    it.write(obj.toString().toByteArray())
                }
                runOnUiThread { result.success(true) }
            } catch (e: Exception) {
                runOnUiThread { result.error("SAVE_SETTINGS_ERROR", e.message, null) }
            }
        }
    }

    // ── Simple app preferences (used for one-time UI state, e.g. the player
    //    tour) ─────────────────────────────────────────────────────────────────

    private val appPrefs: SharedPreferences by lazy {
        getSharedPreferences("mediarescue_prefs", MODE_PRIVATE)
    }

    private fun handleGetAppPrefBool(call: MethodCall, result: MethodChannel.Result) {
        val key = call.argument<String>("key") ?: ""
        result.success(appPrefs.getBoolean(key, false))
    }

    private fun handleSetAppPrefBool(call: MethodCall, result: MethodChannel.Result) {
        val key = call.argument<String>("key")
        if (key.isNullOrEmpty()) {
            result.error("PREF_ERROR", "Missing preference key", null)
            return
        }
        val value = call.argument<Boolean>("value") ?: false
        appPrefs.edit().putBoolean(key, value).apply()
        result.success(true)
    }

    // ═══════════════════════════════════════════════════════════════════════════
    //  FILE METADATA HELPERS
    // ═══════════════════════════════════════════════════════════════════════════

    private fun fileToMap(file: File): Map<String, Any> {
        val isDir = file.isDirectory
        val name = file.name
        val ext = if (isDir) "" else name.substringAfterLast('.', "").lowercase()
        val mime = if (isDir) "" else getMimeType(name)
        val fileType = classifyFile(ext, mime, isDir)

        return mapOf(
            "path" to file.absolutePath,
            "name" to name,
            "extension" to ext,
            "mimeType" to mime,
            "size" to (if (isDir) 0L else file.length()),
            "modifiedDate" to file.lastModified(),
            "isDirectory" to isDir,
            "fileType" to fileType,
            "parentDirectory" to (file.parent ?: "")
        )
    }

    private fun getMimeType(name: String): String {
        val ext = name.substringAfterLast('.', "").lowercase()
        return MimeTypeMap.getSingleton().getMimeTypeFromExtension(ext)
            ?: "application/octet-stream"
    }

    private fun classifyFile(ext: String, mime: String, isDir: Boolean): String {
        if (isDir) return "folder"
        return when (ext) {
            "jpg", "jpeg", "png", "gif", "bmp", "webp", "heic", "heif", "svg", "ico", "tiff", "tif" -> "image"
            "mp4", "mkv", "avi", "mov", "wmv", "flv", "webm", "m4v", "3gp", "ts", "mts", "m2ts" -> "video"
            "mp3", "wav", "aac", "flac", "ogg", "m4a", "wma", "opus", "amr", "mid", "midi" -> "audio"
            "pdf" -> "pdf"
            "doc", "docx", "xls", "xlsx", "ppt", "pptx", "odt", "ods", "odp", "rtf" -> "document"
            "zip", "rar", "7z", "tar", "gz", "bz2", "xz", "iso" -> "archive"
            "apk" -> "apk"
            "txt", "log", "json", "xml", "html", "htm", "css", "js", "py", "java", "kt", "dart",
            "c", "cpp", "h", "sh", "bat", "yml", "yaml", "toml", "ini", "cfg", "conf", "md", "csv" -> "text"
            else -> "other"
        }
    }
}