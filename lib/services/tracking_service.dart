import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'storage_service.dart';

/// Anonymous activity and installation diagnostics tracking using Firebase Cloud Firestore.
///
/// Complies strictly with the MediaRescue privacy policy:
/// - Offline-first: cached locally, synchronizes with Firestore at most once every ~24 hours.
/// - Anonymous: random installation UUID, never collects personal info, accounts, media or file contents.
/// - Tracked fields:
///     installationId
///     fcmToken
///     lastAppOpen
///     appVersion
///     androidVersion
///     deviceModel
class TrackingService {
  TrackingService._();

  static const String _prefInstallationId = 'tracking_installation_id';
  static const String _prefLastSyncTime = 'tracking_last_sync_time';
  static const String _prefLastAppOpen = 'tracking_last_app_open';
  static const String _collectionName = 'installations';

  static final StorageService _storage = MethodChannelStorageService();
  static bool _syncing = false;

  /// Initializes tracking, records the app open locally, and synchronizes with
  /// Firestore if ~24 hours have elapsed since the last successful sync.
  ///
  /// Never blocks application startup and never throws into UI.
  static Future<void> initialize() async {
    try {
      final now = DateTime.now().toUtc();
      final installationId = await _getOrCreateInstallationId();

      // Record local open time.
      await _storage.setAppPrefString(
        _prefLastAppOpen,
        now.toIso8601String(),
      );

      // Check 24-hour sync window.
      final lastSyncStr = await _storage.getAppPrefString(_prefLastSyncTime);
      final lastSync = lastSyncStr != null ? DateTime.tryParse(lastSyncStr) : null;
      final shouldSync = lastSync == null ||
          now.difference(lastSync).inHours >= 24;

      if (shouldSync) {
        unawaited(syncWithFirestore(installationId: installationId, now: now));
      }
    } catch (e) {
      debugPrint('MediaRescue: TrackingService initialization error: $e');
    }
  }

  /// Synchronizes anonymous diagnostic telemetry to Firestore.
  /// Safe to call on reconnect or manual retry.
  static Future<void> syncWithFirestore({
    String? installationId,
    DateTime? now,
  }) async {
    if (_syncing) return;
    _syncing = true;
    try {
      if (Firebase.apps.isEmpty) return;

      final actualId = installationId ?? await _getOrCreateInstallationId();
      final syncTime = now ?? DateTime.now().toUtc();

      // Get FCM token if available (best effort).
      String? fcmToken;
      try {
        fcmToken = await FirebaseMessaging.instance.getToken();
      } catch (_) {
        fcmToken = null;
      }

      // App version.
      String appVersion = '1.0.9';
      try {
        final pkg = await PackageInfo.fromPlatform();
        appVersion = pkg.version;
      } catch (_) {}

      // Device info.
      String androidVersion = '';
      String deviceModel = '';
      try {
        final info = await _storage.getDeviceInfo();
        androidVersion = (info['androidVersion'] ?? '').toString();
        deviceModel = (info['deviceModel'] ?? '').toString();
      } catch (_) {}

      final lastOpenStr = await _storage.getAppPrefString(_prefLastAppOpen);
      final lastOpen = lastOpenStr != null
          ? (DateTime.tryParse(lastOpenStr) ?? syncTime)
          : syncTime;

      final payload = <String, dynamic>{
        'installationId': actualId,
        'fcmToken': fcmToken ?? '',
        'lastAppOpen': lastOpen.toIso8601String(),
        'appVersion': appVersion,
        'androidVersion': androidVersion,
        'deviceModel': deviceModel,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      final firestore = FirebaseFirestore.instance;
      // Use set with SetOptions(merge: true) so we update without duplicating documents.
      await firestore
          .collection(_collectionName)
          .doc(actualId)
          .set(payload, SetOptions(merge: true))
          .timeout(const Duration(seconds: 15));

      // Persist last sync timestamp.
      await _storage.setAppPrefString(
        _prefLastSyncTime,
        syncTime.toIso8601String(),
      );
    } catch (e) {
      debugPrint('MediaRescue: TrackingService sync failed (offline or unavailable): $e');
    } finally {
      _syncing = false;
    }
  }

  /// Retrieves the existing anonymous installation UUID from local storage or
  /// generates and stores a new one.
  static Future<String> _getOrCreateInstallationId() async {
    final existing = await _storage.getAppPrefString(_prefInstallationId);
    if (existing != null && existing.trim().isNotEmpty) {
      return existing.trim();
    }

    final newId = _generateUuidV4();
    await _storage.setAppPrefString(_prefInstallationId, newId);
    return newId;
  }

  /// Generates a RFC-4122 v4 UUID without requiring external dependencies.
  static String _generateUuidV4() {
    final rnd = Random.secure();
    final bytes = List<int>.generate(16, (_) => rnd.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40; // version 4
    bytes[8] = (bytes[8] & 0x3f) | 0x80; // variant RFC 4122

    String hex(int b) => b.toRadixString(16).padLeft(2, '0');
    final s = bytes.map(hex).join();
    return '${s.substring(0, 8)}-${s.substring(8, 12)}-${s.substring(12, 16)}-${s.substring(16, 20)}-${s.substring(20, 32)}';
  }
}
