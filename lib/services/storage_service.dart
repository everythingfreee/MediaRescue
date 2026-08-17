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
}
