import 'dart:async';
import 'package:flutter/services.dart';
import '../models/file_item.dart';

abstract class StorageService {
  /// Checks whether "All files access" (MANAGE_EXTERNAL_STORAGE) is granted.
  Future<bool> hasAccess();

  /// Opens the system settings page for "All files access".
  /// Returns immediately; the actual grant is detected on app resume.
  Future<bool> requestAccess();

  /// Lists the contents of a directory by absolute path.
  /// An empty/null path lists the shared-storage root (/storage/emulated/0).
  Future<List<FileItem>> listDirectory(String? path);

  /// Recursively scans a directory and all sub-directories for files.
  Future<List<FileItem>> scanDirectory(String path);

  /// Returns the available storage roots (internal storage, SD card, etc.).
  Future<List<StorageRoot>> getStorageRoots();

  /// Starts a full recursive scan of /storage/emulated/0 in the background.
  /// Progress is delivered through [scanEvents].
  Future<bool> startScan();

  /// Stops an in-progress scan.
  Future<bool> stopScan();

  /// Stream of scan progress events:
  ///   {type: 'progress', filesDiscovered, currentPath, dirsScanned}
  ///   {type: 'batch', files: [FileItem...]}
  ///   {type: 'complete', totalFiles}
  ///   {type: 'error', message}
  Stream<Map<Object?, Object?>> scanEvents();

  Future<Uint8List?> getThumbnail(String path);
  Future<bool> deleteFiles(List<String> paths);
  Future<bool> copyFiles(List<String> sourcePaths, String destinationPath);
  Future<bool> moveFiles(List<String> sourcePaths, String destinationPath);
  Future<bool> renameFile(String path, String newName);
  Future<Uint8List?> getFileBytes(String path);
  Future<bool> saveScanData(List<FileItem> files);
  Future<List<FileItem>> loadScanData();
  Future<bool> clearScanData();

  // ── Preview + Rescue support ─────────────────────────────────────────────

  /// Copies a single file into [destDirPath] with size verification and return:
  /// {success, targetPath, alreadyExists}.
  Future<Map<String, Object?>> copyFileVerified(
    String sourcePath,
    String destDirPath,
    bool overwrite,
  );

  /// Rich metadata map for a file (resolution, duration, bitrate, audio info…).
  Future<Map<String, Object?>> getFileMediaInfo(String path);

  /// Asks Android's MediaScanner to index (or re-index) the given paths.
  Future<bool> indexMedia(List<String> paths);

  /// Creates a directory (and parents).
  Future<bool> createDirectory(String path);

  /// Shares a local file with other apps. Returns false when it fails.
  Future<bool> shareFile(String path);

  /// Best-effort "open file location" in a file manager.
  Future<bool> openFileLocation(String path);

  /// Loads the persisted rescue-destination settings.
  Future<Map<Object?, Object?>> getRescueSettings();

  /// Persists the rescue-destination settings.
  Future<bool> saveRescueSettings(Map<String, Object?> settings);

  /// Reads a boolean app preference stored natively (SharedPreferences).
  Future<bool> getAppPrefBool(String key);

  /// Writes a boolean app preference natively (SharedPreferences).
  Future<bool> setAppPrefBool(String key, bool value);
}

/// Represents a storage root (internal storage, SD card, etc.).
class StorageRoot {
  final String path;
  final String name;
  final String type;

  const StorageRoot({
    required this.path,
    required this.name,
    required this.type,
  });

  factory StorageRoot.fromMap(Map<Object?, Object?> map) {
    return StorageRoot(
      path: map['path'] as String? ?? '',
      name: map['name'] as String? ?? '',
      type: map['type'] as String? ?? 'internal',
    );
  }
}

class MethodChannelStorageService implements StorageService {
  static const MethodChannel _channel = MethodChannel(
    'com.shaheer.mediarescue/storage',
  );
  static const EventChannel _scanEvents = EventChannel(
    'com.shaheer.mediarescue/scan_events',
  );

  @override
  Future<bool> hasAccess() async {
    try {
      final bool? result = await _channel.invokeMethod('hasAllFilesAccess');
      return result ?? false;
    } on PlatformException catch (_) {
      return false;
    }
  }

  @override
  Future<bool> requestAccess() async {
    try {
      final bool? result = await _channel.invokeMethod('requestAllFilesAccess');
      return result ?? false;
    } on PlatformException catch (_) {
      return false;
    }
  }

  @override
  Future<List<FileItem>> listDirectory(String? path) async {
    try {
      final List<dynamic>? result =
          await _channel.invokeMethod('listDirectory', {'path': path});
      if (result == null) return [];
      return result.map((e) => FileItem.fromMap(e as Map<Object?, Object?>)).toList();
    } on PlatformException catch (_) {
      return [];
    }
  }

  @override
  Future<List<FileItem>> scanDirectory(String path) async {
    try {
      final List<dynamic>? result =
          await _channel.invokeMethod('scanDirectory', {'path': path});
      if (result == null) return [];
      return result.map((e) => FileItem.fromMap(e as Map<Object?, Object?>)).toList();
    } on PlatformException catch (_) {
      return [];
    }
  }

  @override
  Future<List<StorageRoot>> getStorageRoots() async {
    try {
      final List<dynamic>? result =
          await _channel.invokeMethod('getStorageRoots');
      if (result == null) return [];
      return result
          .map((e) => StorageRoot.fromMap(e as Map<Object?, Object?>))
          .toList();
    } on PlatformException catch (_) {
      return [];
    }
  }

  @override
  Future<bool> startScan() async {
    try {
      final bool? result = await _channel.invokeMethod('startScan');
      return result ?? false;
    } on PlatformException catch (_) {
      return false;
    }
  }

  @override
  Future<bool> stopScan() async {
    try {
      final bool? result = await _channel.invokeMethod('stopScan');
      return result ?? false;
    } on PlatformException catch (_) {
      return false;
    }
  }

  @override
  Stream<Map<Object?, Object?>> scanEvents() {
    return _scanEvents.receiveBroadcastStream().map((event) {
      return (event as Map<Object?, Object?>);
    });
  }

  @override
  Future<Uint8List?> getThumbnail(String path) async {
    try {
      final Uint8List? result =
          await _channel.invokeMethod('getThumbnail', {'path': path});
      return result;
    } on PlatformException catch (_) {
      return null;
    }
  }

  @override
  Future<bool> deleteFiles(List<String> paths) async {
    try {
      final bool? result =
          await _channel.invokeMethod('deleteFiles', {'paths': paths});
      return result ?? false;
    } on PlatformException catch (_) {
      return false;
    }
  }

  @override
  Future<bool> copyFiles(List<String> sourcePaths, String destinationPath) async {
    try {
      final bool? result = await _channel.invokeMethod('copyFiles', {
        'sourcePaths': sourcePaths,
        'destinationPath': destinationPath,
      });
      return result ?? false;
    } on PlatformException catch (_) {
      return false;
    }
  }

  @override
  Future<bool> moveFiles(List<String> sourcePaths, String destinationPath) async {
    try {
      final bool? result = await _channel.invokeMethod('moveFiles', {
        'sourcePaths': sourcePaths,
        'destinationPath': destinationPath,
      });
      return result ?? false;
    } on PlatformException catch (_) {
      return false;
    }
  }

  @override
  Future<bool> renameFile(String path, String newName) async {
    try {
      final bool? result = await _channel
          .invokeMethod('renameFile', {'path': path, 'newName': newName});
      return result ?? false;
    } on PlatformException catch (_) {
      return false;
    }
  }

  @override
  Future<Uint8List?> getFileBytes(String path) async {
    try {
      final Uint8List? result =
          await _channel.invokeMethod('getFileBytes', {'path': path});
      return result;
    } on PlatformException catch (_) {
      return null;
    }
  }

  @override
  Future<bool> saveScanData(List<FileItem> files) async {
    try {
      final bool? result = await _channel.invokeMethod('saveScanData', {
        'files': files.map((f) => {
              'path': f.path,
              'name': f.name,
              'extension': f.extension,
              'mimeType': f.mimeType,
              'size': f.size,
              'modifiedDate': f.modifiedDate,
              'isDirectory': f.isDirectory,
              'fileType': f.fileType,
              'parentDirectory': f.parentDirectory,
            }).toList(),
      });
      return result ?? false;
    } on PlatformException catch (_) {
      return false;
    }
  }

  @override
  Future<List<FileItem>> loadScanData() async {
    try {
      final List<dynamic>? result =
          await _channel.invokeMethod('loadScanData');
      if (result == null) return [];
      return result
          .map((e) => FileItem.fromMap(e as Map<Object?, Object?>))
          .toList();
    } on PlatformException catch (_) {
      return [];
    }
  }

  @override
  Future<bool> clearScanData() async {
    try {
      final bool? result = await _channel.invokeMethod('clearScanData');
      return result ?? false;
    } on PlatformException catch (_) {
      return false;
    }
  }

  @override
  Future<Map<String, Object?>> copyFileVerified(
    String sourcePath,
    String destDirPath,
    bool overwrite,
  ) async {
    try {
      final raw = await _channel.invokeMethod<dynamic>('copyFileVerified', {
        'sourcePath': sourcePath,
        'destDirPath': destDirPath,
        'overwrite': overwrite,
      });
      if (raw is Map) {
        return {
          for (final entry in raw.entries)
            entry.key.toString(): entry.value,
        };
      }
    } on PlatformException catch (_) {
      // Fall through.
    }
    return const {'success': false};
  }

  @override
  Future<Map<String, Object?>> getFileMediaInfo(String path) async {
    try {
      final raw = await _channel.invokeMethod<dynamic>(
        'getFileMediaInfo',
        {'path': path},
      );
      if (raw is Map) {
        return {
          for (final entry in raw.entries)
            entry.key.toString(): entry.value,
        };
      }
    } on PlatformException catch (_) {
      // Fall through.
    }
    return const {};
  }

  @override
  Future<bool> indexMedia(List<String> paths) async {
    try {
      final bool? result =
          await _channel.invokeMethod('indexMedia', {'paths': paths});
      return result ?? false;
    } on PlatformException catch (_) {
      return false;
    }
  }

  @override
  Future<bool> createDirectory(String path) async {
    try {
      final bool? result =
          await _channel.invokeMethod('createDirectory', {'path': path});
      return result ?? false;
    } on PlatformException catch (_) {
      return false;
    }
  }

  @override
  Future<bool> shareFile(String path) async {
    try {
      final bool? result =
          await _channel.invokeMethod('shareFile', {'path': path});
      return result ?? false;
    } on PlatformException catch (_) {
      return false;
    }
  }

  @override
  Future<bool> openFileLocation(String path) async {
    try {
      final bool? result =
          await _channel.invokeMethod('openFileLocation', {'path': path});
      return result ?? false;
    } on PlatformException catch (_) {
      return false;
    }
  }

  @override
  Future<Map<Object?, Object?>> getRescueSettings() async {
    try {
      final raw = await _channel.invokeMethod<dynamic>('getRescueSettings');
      if (raw is Map) {
        return raw.cast<Object?, Object?>();
      }
    } on PlatformException catch (_) {
      // Fall through.
    }
    return const {};
  }

  @override
  Future<bool> saveRescueSettings(Map<String, Object?> settings) async {
    try {
      final bool? result =
          await _channel.invokeMethod('saveRescueSettings', settings);
      return result ?? false;
    } on PlatformException catch (_) {
      return false;
    }
  }

  @override
  Future<bool> getAppPrefBool(String key) async {
    try {
      final bool? result =
          await _channel.invokeMethod('getAppPrefBool', {'key': key});
      return result ?? false;
    } on PlatformException catch (_) {
      return false;
    }
  }

  @override
  Future<bool> setAppPrefBool(String key, bool value) async {
    try {
      final bool? result = await _channel
          .invokeMethod('setAppPrefBool', {'key': key, 'value': value});
      return result ?? false;
    } on PlatformException catch (_) {
      return false;
    }
  }
}
