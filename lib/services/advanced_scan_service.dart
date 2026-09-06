import 'dart:async';

import 'package:flutter/services.dart';

/// Control + event bridge for the OPTIONAL Shizuku-based Advanced Scanner.
///
/// This mirrors the existing platform-communication architecture used by
/// [StorageService] (MethodChannel) and the normal scan (EventChannel), but
/// on dedicated channel names so the two scanning systems stay fully
/// independent: the normal scanner never touches these channels, and nothing
/// in MediaRescue requires this service.
///
/// All Shizuku specifics (binders, authorization, the user service) live on
/// the native side inside `ShizukuManager` — this class exposes only simple
/// request/response and event-stream APIs to the Dart layer.
class AdvancedScanService {
  AdvancedScanService._();

  static final AdvancedScanService instance = AdvancedScanService._();

  static const MethodChannel _channel =
      MethodChannel('com.shaheer.mediarescue/advanced_scan');
  static const EventChannel _eventChannel =
      EventChannel('com.shaheer.mediarescue/advanced_scan_events');

  /// Shizuku + user-service status snapshot.
  ///
  /// Returns a map with: `installed`, `running`, `authorized`,
  /// `serviceConnected` (bools) and `state` (one of: unavailable,
  /// not_running, waiting_for_permission, permission_denied, authorized,
  /// service_connected). Never throws — failures produce an empty map.
  Future<Map<Object?, Object?>> getShizukuState() async {
    try {
      final raw = await _channel.invokeMethod<dynamic>('getShizukuState');
      if (raw is Map) {
        return Map<Object?, Object?>.from(raw);
      }
    } on PlatformException catch (_) {
      // Fall through — callers treat an empty map as "unknown".
    }
    return const {};
  }

  /// Opens the Shizuku authorization dialog for MediaRescue.
  ///
  /// Returns a map with `status` (granted / denied / not_running / error)
  /// and an optional user-friendly `message`.
  Future<Map<Object?, Object?>> requestShizukuPermission() async {
    try {
      final raw = await _channel.invokeMethod<dynamic>('requestShizukuPermission');
      if (raw is Map) {
        return Map<Object?, Object?>.from(raw);
      }
    } on PlatformException catch (_) {
      // Fall through.
    }
    return const {
      'status': 'error',
      'message': 'Could not request Shizuku authorization.',
    };
  }

  /// Starts the advanced scan of Android/data and Android/obb.
  /// Progress, results and completion arrive over [events].
  /// Returns `false` when the request could not be delivered.
  Future<bool> startAdvancedScan() async {
    try {
      return await _channel.invokeMethod<bool>('startAdvancedScan') ?? false;
    } on PlatformException catch (_) {
      return false;
    }
  }

  /// Cancels the active advanced scan (safe no-op when nothing is running).
  Future<bool> stopAdvancedScan() async {
    try {
      return await _channel.invokeMethod<bool>('stopAdvancedScan') ?? false;
    } on PlatformException catch (_) {
      return false;
    }
  }

  /// Copies a file that only Shizuku can read into shared storage.
  Future<bool> copyAdvancedFile(
    String sourcePath,
    String destinationPath, {
    bool overwrite = false,
  }) async {
    try {
      return await _channel.invokeMethod<bool>('copyAdvancedFile', {
            'sourcePath': sourcePath,
            'destinationPath': destinationPath,
            'overwrite': overwrite,
          }) ??
          false;
    } on MissingPluginException {
      // A native feature added after an APK was installed needs a full
      // Android rebuild; keep an older binary from crashing the Flutter UI.
      return false;
    } on PlatformException catch (_) {
      return false;
    }
  }

  /// Broadcast stream of advanced-scan events. Each event is a map with a
  /// `type` field: progress, batch, rootStatus, rootComplete, completed,
  /// error, scan or state — matching the native ShizukuManager emissions.
  Stream<Map<Object?, Object?>> events() =>
      _eventChannel.receiveBroadcastStream().map(
            (dynamic event) => Map<Object?, Object?>.from(event as Map),
          );
}