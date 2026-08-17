package com.shaheer.mediarescue.mediarescue

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Environment
import android.provider.Settings
import android.webkit.MimeTypeMap
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
                paths?.forEach { path ->
                    try {
                        val file = File(path)
                        if (file.exists()) {
                            if (!deleteRecursively(file)) allDeleted = false
                        }
                    } catch (e: Exception) {
                        allDeleted = false
                    }
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
                if (destDir.exists() && destDir.isDirectory) {
                    sourcePaths?.forEach { path ->
                        try {
                            val source = File(path)
                            if (source.exists()) {
                                val target = File(destDir, source.name)
                                if (!copyRecursively(source, target)) allCopied = false
                            }
                        } catch (e: Exception) {
                            allCopied = false
                        }
                    }
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
                            }
                        } catch (e: Exception) {
                            allMoved = false
                        }
                    }
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
                val success = if (file.exists() && !newName.isNullOrEmpty()) {
                    val parent = file.parentFile
                    val newFile = File(parent, newName)
                    file.renameTo(newFile)
                } else {
                    false
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