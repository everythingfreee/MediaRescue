import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';

import '../app/app.dart' show rootNavigatorKey;
import '../models/file_item.dart';
import '../models/hidden_media.dart';
import 'notification_service.dart';
import 'storage_service.dart';

/// One cached Memory — the metadata MediaRescue needs to build a future
/// Memory notification and to reopen the media from it.
///
/// Everything here is derived from the user's own device. Nothing is uploaded
/// and no account / cloud storage is involved.
@immutable
class MemoryEntry {
  /// Stable identifier for this media file (never regenerated per launch).
  final String id;

  /// Absolute file path — used to reopen the media.
  final String path;

  final String name;

  /// `image`, `video` or `audio` (only media qualifies for Memories).
  final String mediaType;

  /// Creation date (media metadata when available, file date otherwise).
  final int creationDate;

  /// When this entry was first cached.
  final int cachedAt;

  /// True once [creationDate] was resolved from media metadata.
  final bool dateResolved;

  /// Small base64 JPEG thumbnail used as the notification artwork.
  final String? thumbnail;

  /// `yyyy-MM-dd` of the last Memory notification shown for this entry.
  final String? lastNotified;

  const MemoryEntry({
    required this.id,
    required this.path,
    required this.name,
    required this.mediaType,
    required this.creationDate,
    required this.cachedAt,
    this.dateResolved = false,
    this.thumbnail,
    this.lastNotified,
  });

  MemoryEntry copyWith({
    String? name,
    String? mediaType,
    int? creationDate,
    bool? dateResolved,
    String? thumbnail,
    String? lastNotified,
  }) {
    return MemoryEntry(
      id: id,
      path: path,
      name: name ?? this.name,
      mediaType: mediaType ?? this.mediaType,
      creationDate: creationDate ?? this.creationDate,
      cachedAt: cachedAt,
      dateResolved: dateResolved ?? this.dateResolved,
      thumbnail: thumbnail ?? this.thumbnail,
      lastNotified: lastNotified ?? this.lastNotified,
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'path': path,
    'name': name,
    'mediaType': mediaType,
    'creationDate': creationDate,
    'cachedAt': cachedAt,
    'dateResolved': dateResolved,
    if (thumbnail != null) 'thumbnail': thumbnail,
    if (lastNotified != null) 'lastNotified': lastNotified,
  };

  factory MemoryEntry.fromJson(Map<String, dynamic> json) {
    return MemoryEntry(
      id: json['id'] as String? ?? '',
      path: json['path'] as String? ?? '',
      name: json['name'] as String? ?? '',
      mediaType: json['mediaType'] as String? ?? 'image',
      creationDate: (json['creationDate'] as num?)?.toInt() ?? 0,
      cachedAt: (json['cachedAt'] as num?)?.toInt() ?? 0,
      dateResolved: json['dateResolved'] == true,
      thumbnail: json['thumbnail'] as String?,
      lastNotified: json['lastNotified'] as String?,
    );
  }
}


/// Reminder ("Memory") support for Hidden Media.
///
/// MediaRescue caches the metadata required to build a Memory notification
/// locally (see [MemoryEntry]) and, when the creation-date anniversary of a
/// cached media file arrives, shows a notification on a dedicated channel with
/// the MediaRescue custom sound. Tapping it opens the media in the appropriate
/// player — fully offline, with no account and no upload.
///
/// Every operation is best effort: a missing file, an unavailable thumbnail, a
/// denied notification permission or a broken cache never throws into the UI.
class MemoryService {
  MemoryService._();

  /// Dedicated notification channel for Memories.
  static const String channelId = 'mediarescue_memories';
  static const String channelName = 'Memories';
  static const String channelDescription =
      'Reminders about your hidden media from a year ago';

  /// Small local cache bounds (keeps the cache file tiny and predictable).
  static const int _maxEntries = 300;
  static const int _maxThumbnails = 40;
  static const int _maxThumbnailBytes = 150 * 1024;
  static const int _maxThumbnailFetchesPerSync = 12;
  static const int _maxDateResolutionsPerSync = 15;
  static const int _maxNotificationsPerCheck = 3;
  static const int _thumbnailWindowDays = 30;

  /// How long [handleNotificationLaunchPayload] waits for the root navigator to
  /// come alive. A notification tap is handled before the first frame of a cold
  /// start exists, so the media has to wait for the UI instead of being dropped.
  static const int _navigatorWaitMs = 8000;
  static const int _navigatorPollMs = 100;

  /// Native preference holding the payload of the launch notification that has
  /// already been consumed, so a launch intent replayed by Android can never
  /// reopen the same media again.
  static const String _prefKeyConsumedLaunchPayload =
      'memory_consumed_launch_payload';

  /// Media types a cached Memory can have (everything else is not media).
  static const Set<String> _imageExtensions = {
    'jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp', 'heic', 'heif', 'svg', 'ico',
    'tiff', 'tif',
  };
  static const Set<String> _videoExtensions = {
    'mp4', 'mkv', 'avi', 'mov', 'wmv', 'flv', 'webm', 'm4v', '3gp', 'ts',
    'mts', 'm2ts',
  };
  static const Set<String> _audioExtensions = {
    'mp3', 'wav', 'aac', 'flac', 'ogg', 'm4a', 'wma', 'opus', 'amr', 'mid',
    'midi',
  };

  static final StorageService _storage = MethodChannelStorageService();
  static final Random _random = Random();

  /// Identifier of the entry picked by the last test notification, so pressing
  /// the button twice never reports the exact same media twice in a row.
  static String? _lastTestPickId;

  /// Payloads already consumed during this process run.
  static final Set<String> _consumedPayloads = <String>{};

  static Map<String, MemoryEntry> _entries = <String, MemoryEntry>{};
  static bool _loaded = false;
  static bool _syncing = false;

  /// Loads the persisted cache and shows any Memory due today. Called once at
  /// startup; safe to call repeatedly.
  static Future<void> initialize() async {
    try {
      await _ensureLoaded();
      await _ensureChannel();
      await checkAndNotify();
    } catch (_) {
      // Memories must never affect app startup.
    }
  }

  /// Caches the metadata of every hidden media item (images, videos and audio
  /// only). Unrelated file types are ignored.
  static Future<void> syncFromHiddenMedia(List<HiddenMediaItem> items) async {
    if (items.isEmpty || _syncing) return;
    _syncing = true;
    try {
      await _ensureLoaded();
      final now = DateTime.now();
      var changed = false;

      for (final hidden in items) {
        final file = hidden.item;
        if (!_isMediaFile(file)) continue;
        final id = _idFor(file.path);
        final existing = _entries[id];
        if (existing == null) {
          _entries[id] = MemoryEntry(
            id: id,
            path: file.path,
            name: file.name,
            mediaType: file.fileType,
            creationDate: file.modifiedDate,
            cachedAt: now.millisecondsSinceEpoch,
          );
          changed = true;
        } else if (existing.name != file.name ||
            existing.mediaType != file.fileType) {
          _entries[id] = existing.copyWith(
            name: file.name,
            mediaType: file.fileType,
          );
          changed = true;
        }
      }

      changed = await _resolveDates() || changed;
      changed = await _cacheThumbnails(now) || changed;
      if (_prune()) changed = true;

      if (changed) await _persist();
    } catch (_) {
      // Caching is best effort.
    } finally {
      _syncing = false;
    }
  }

  /// Shows the Memory notification for every cached media file whose creation
  /// date matches today's day/month (at least one year ago).
  static Future<void> checkAndNotify() async {
    await _ensureLoaded();
    if (_entries.isEmpty) return;

    final now = DateTime.now();
    final todayKey = _dayKey(now);
    final due = <MemoryEntry>[];
    for (final entry in _entries.values) {
      if (entry.lastNotified == todayKey) continue;
      if (entry.creationDate <= 0) continue;
      final created = DateTime.fromMillisecondsSinceEpoch(entry.creationDate);
      if (created.year <= 1) continue;
      if (now.year - created.year < 1) continue;
      if (created.month != now.month || created.day != now.day) continue;
      due.add(entry);
    }
    if (due.isEmpty) return;

    due.sort((a, b) => b.creationDate.compareTo(a.creationDate));
    var shown = 0;
    var changed = false;
    for (final entry in due) {
      if (shown >= _maxNotificationsPerCheck) break;
      final ok = await _notify(entry, now);
      changed = true; // lastNotified was updated either way
      if (ok) shown++;
    }
    if (changed) await _persist();
  }

  /// Shows a test Memory notification for a media item picked from the local
  /// Memory cache.
  ///
  /// Used by the debug-only button in Settings to verify the whole pipeline on
  /// demand: channel, custom sound, artwork and tap handling. A media file still
  /// on disk is selected **at random** — images, videos and audio alike — so
  /// repeated presses walk through the whole cache instead of always reporting
  /// the same file (the previous pick is skipped while other candidates exist),
  /// and a thumbnail is fetched when the picked entry does not have one yet.
  ///
  /// Unlike [checkAndNotify] this ignores the anniversary rule and never marks
  /// the entry as notified, so running it can not swallow the real reminder for
  /// that day. Returns the entry that was notified, or `null` when nothing could
  /// be shown (no cached media, notification permission denied, …).
  ///
  /// Debug-only: in release builds it does nothing.
  static Future<MemoryEntry?> sendTestNotification() async {
    if (!kDebugMode) return null;
    await _ensureLoaded();
    if (_entries.isEmpty) return null;
    await _ensureChannel();

    final candidates = _entries.values
        .where((entry) => File(entry.path).existsSync())
        .toList();
    if (candidates.isEmpty) return null;

    var entry = _pickRandomCandidate(candidates);
    _lastTestPickId = entry.id;
    if (entry.thumbnail == null) {
      try {
        final bytes = await _storage.getThumbnail(entry.path);
        if (bytes != null &&
            bytes.isNotEmpty &&
            bytes.length <= _maxThumbnailBytes) {
          entry = entry.copyWith(thumbnail: base64Encode(bytes));
          _entries[entry.id] = entry;
          await _persist();
        }
      } catch (_) {
        // Artwork is optional — the notification is still shown without it.
      }
    }

    final now = DateTime.now();
    final display = entry.creationDate > 0
        ? entry
        : entry.copyWith(
            // Keep the test notification readable when the cache never resolved
            // a creation date (otherwise it would claim "1970").
            creationDate: DateTime(
              now.year - 1,
              now.month,
              now.day,
            ).millisecondsSinceEpoch,
            dateResolved: true,
          );

    final shown = await _notify(display, now, markNotified: false);
    return shown ? entry : null;
  }

  /// Read-only view of the cached Memory metadata, newest first.
  ///
  /// Powers the debug-only "Memory cache" screen so the metadata MediaRescue
  /// keeps locally (path, creation date, media type, thumbnail, notification
  /// bookkeeping) can be inspected without a device debugger. Loads the cache on
  /// first use, so it also works before Hidden Media was ever opened.
  static Future<List<MemoryEntry>> debugEntries() async {
    await _ensureLoaded();
    final entries = _entries.values.toList()
      ..sort((a, b) {
        final byCached = b.cachedAt.compareTo(a.cachedAt);
        return byCached != 0 ? byCached : a.name.compareTo(b.name);
      });
    return List<MemoryEntry>.unmodifiable(entries);
  }

  /// Size in bytes of the persisted Memory cache JSON (0 when unavailable).
  static Future<int> debugCacheBytes() async {
    try {
      return (await _storage.loadMemoryCache()).length;
    } catch (_) {
      return 0;
    }
  }

  /// Opens a cached entry's media exactly like a tapped Memory notification does.
  ///
  /// Used by the debug-only Memory cache screen to verify the whole notification
  /// pipeline (cached metadata → typed [FileItem] → immersive player) on demand.
  /// Returns `true` when a preview was opened.
  static Future<bool> openCachedEntry(MemoryEntry entry) => _openMemory({
    'type': 'memory',
    'id': entry.id,
    'path': entry.path,
    'mediaType': entry.mediaType,
    'name': entry.name,
  });

  /// Handles a tapped notification payload while the app is already running.
  ///
  /// Returns `true` when the payload was a Memory (and was consumed), `false`
  /// when it belongs to another MediaRescue notification type.
  static bool handleNotificationPayload(String? payload) {
    final target = _parsePayload(payload);
    if (target == null) return false;
    final marker = payload!;
    if (_consumedPayloads.contains(marker)) {
      // The very same tap was already reported for this launch — never open the
      // media twice from one tap.
      debugPrint('MediaRescue: duplicate Memory notification tap ignored.');
      return true;
    }
    unawaited(_openMemory(target));
    // Remember the payload natively as well: Android re-delivers the intent that
    // started the activity when the task is revived, and that replay must not
    // reopen the media by itself.
    unawaited(_rememberConsumedPayload(marker));
    return true;
  }

  /// Handles the payload of the notification that cold-started the app.
  ///
  /// A tap on a notification that launched a terminated app is only reported
  /// through `getNotificationAppLaunchDetails`, and Android keeps reporting that
  /// same payload every time the task is brought back to the foreground without
  /// a fresh tap (for example when MediaRescue is reopened from the launcher).
  /// Every payload is therefore consumed exactly once — in memory and natively —
  /// so the media can never open itself again and again after a restart.
  ///
  /// Returns `true` when a media preview was opened for [payload].
  static Future<bool> handleNotificationLaunchPayload(String? payload) async {
    final target = _parsePayload(payload);
    if (target == null) return false;
    final marker = payload!;
    if (_consumedPayloads.contains(marker)) return false;
    if (await _storage.getAppPrefString(_prefKeyConsumedLaunchPayload) ==
        marker) {
      // Replayed launch intent: nothing new was tapped.
      debugPrint('MediaRescue: replayed Memory launch payload ignored.');
      return false;
    }
    _consumedPayloads.add(marker);
    final opened = await _openMemory(target);
    await _rememberConsumedPayload(marker);
    return opened;
  }
  // ═══════════════════════════════════════════════════════════════════════════
  //  INTERNAL HELPERS
  // ═══════════════════════════════════════════════════════════════════════════

  static bool _isMediaFile(FileItem file) =>
      file.isImage || file.isVideo || file.isAudio;

  /// Nonce identifying one shown notification.
  static String _newNonce(DateTime now) =>
      '${now.microsecondsSinceEpoch.toRadixString(36)}-'
      '${_random.nextInt(1 << 32).toRadixString(36)}';

  /// Picks a random entry out of [candidates].
  ///
  /// Purely random so repeated test notifications walk through the whole Memory
  /// cache; the previous pick is skipped while other candidates exist, so two
  /// presses in a row never report the very same media.
  static MemoryEntry _pickRandomCandidate(List<MemoryEntry> candidates) {
    if (candidates.length == 1) return candidates.first;
    final previous = _lastTestPickId;
    final pool = previous == null
        ? candidates
        : candidates.where((entry) => entry.id != previous).toList();
    final choices = pool.isEmpty ? candidates : pool;
    return choices[_random.nextInt(choices.length)];
  }

  static String _idFor(String path) {
    var hash = 0x811c9dc5;
    for (var i = 0; i < path.length; i++) {
      hash ^= path.codeUnitAt(i);
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }

  static String _dayKey(DateTime dt) =>
      '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  static Future<void> _ensureLoaded() async {
    if (_loaded) return;
    try {
      final jsonStr = await _storage.loadMemoryCache();
      if (jsonStr.isNotEmpty) {
        final decoded = jsonDecode(jsonStr);
        if (decoded is List) {
          final map = <String, MemoryEntry>{};
          for (final item in decoded) {
            if (item is Map<String, dynamic>) {
              final entry = MemoryEntry.fromJson(item);
              if (entry.id.isNotEmpty && entry.path.isNotEmpty) {
                map[entry.id] = entry;
              }
            }
          }
          _entries = map;
        }
      }
    } catch (e) {
      debugPrint('MediaRescue: Memory cache load failed: $e');
      _entries = <String, MemoryEntry>{};
    } finally {
      _loaded = true;
    }
  }

  static Future<void> _persist() async {
    try {
      final list = _entries.values.map((e) => e.toJson()).toList(growable: false);
      final jsonStr = jsonEncode(list);
      await _storage.saveMemoryCache(jsonStr);
    } catch (e) {
      debugPrint('MediaRescue: Memory cache persist failed: $e');
    }
  }

  /// Waits briefly for the local-notifications plugin to finish initializing.
  ///
  /// [MemoryService.initialize] and `NotificationService.initialize` run at the
  /// same time during app startup, so a Memory reminder that is due right then
  /// would be shown before the plugin exists and would be dropped silently.
  static Future<void> _awaitNotificationsReady() async {
    if (!NotificationService.isInitializing) return;
    try {
      await NotificationService.ready.timeout(const Duration(seconds: 4));
    } catch (_) {
      // Startup took too long — try to show the notification anyway.
    }
  }

  static Future<void> _ensureChannel() async {
    await _awaitNotificationsReady();
    try {
      final plugin = NotificationService.localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      if (plugin != null) {
        await plugin.createNotificationChannel(
          const AndroidNotificationChannel(
            channelId,
            channelName,
            description: channelDescription,
            importance: Importance.high,
            sound: RawResourceAndroidNotificationSound('notification'),
            playSound: true,
          ),
        );
      }
    } catch (e) {
      debugPrint('MediaRescue: Memory notification channel creation failed: $e');
    }
  }

  static Future<bool> _resolveDates() async {
    var changed = false;
    var resolvedCount = 0;
    for (final entry in _entries.values) {
      if (entry.dateResolved) continue;
      if (resolvedCount >= _maxDateResolutionsPerSync) break;

      try {
        final info = await _storage.getFileMediaInfo(entry.path);
        resolvedCount++;
        final created = (info['date'] as num?)?.toInt();
        if (created != null && created > 0) {
          _entries[entry.id] = entry.copyWith(
            creationDate: created,
            dateResolved: true,
          );
          changed = true;
        } else {
          _entries[entry.id] = entry.copyWith(dateResolved: true);
          changed = true;
        }
      } catch (_) {
        resolvedCount++;
      }
    }
    return changed;
  }

  static Future<bool> _cacheThumbnails(DateTime now) async {
    var changed = false;
    var fetchCount = 0;

    for (final entry in _entries.values) {
      if (entry.thumbnail != null) continue;
      if (fetchCount >= _maxThumbnailFetchesPerSync) break;
      if (entry.creationDate <= 0) continue;

      final created = DateTime.fromMillisecondsSinceEpoch(entry.creationDate);
      final daysDiff = (created.month * 30 + created.day - (now.month * 30 + now.day)).abs();
      if (daysDiff > _thumbnailWindowDays && daysDiff < (365 - _thumbnailWindowDays)) {
        continue;
      }

      try {
        final bytes = await _storage.getThumbnail(entry.path);
        fetchCount++;
        if (bytes != null && bytes.isNotEmpty && bytes.length <= _maxThumbnailBytes) {
          final b64 = base64Encode(bytes);
          _entries[entry.id] = entry.copyWith(thumbnail: b64);
          changed = true;
        }
      } catch (_) {
        fetchCount++;
      }
    }
    return changed;
  }

  static bool _prune() {
    if (_entries.length <= _maxEntries) return false;
    final sorted = _entries.values.toList()
      ..sort((a, b) => b.cachedAt.compareTo(a.cachedAt));
    final kept = sorted.take(_maxEntries).toList();
    _entries = {for (final e in kept) e.id: e};

    var thumbCount = 0;
    for (final e in _entries.values) {
      if (e.thumbnail != null) {
        thumbCount++;
        if (thumbCount > _maxThumbnails) {
          _entries[e.id] = e.copyWith(thumbnail: null);
        }
      }
    }
    return true;
  }

  static Future<bool> _notify(
    MemoryEntry entry,
    DateTime now, {
    /// When false the entry is left untouched, so a test notification never
    /// consumes the real reminder for the day.
    bool markNotified = true,
  }) async {
    await _awaitNotificationsReady();
    if (markNotified) {
      final todayKey = _dayKey(now);
      _entries[entry.id] = entry.copyWith(lastNotified: todayKey);
    }

    final file = File(entry.path);
    if (!file.existsSync()) {
      return false;
    }

    final created = DateTime.fromMillisecondsSinceEpoch(entry.creationDate);
    final yearsAgo = (now.year - created.year).clamp(1, 100);
    final yearsText = yearsAgo == 1 ? '1 year ago' : '$yearsAgo years ago';

    final mediaLabel = switch (entry.mediaType) {
      'video' => 'video',
      'audio' => 'audio track',
      _ => 'photo',
    };

    final title = 'Memory from $yearsText';
    final body = 'Rediscover a hidden $mediaLabel: "${entry.name}"';
    final payload = jsonEncode({
      'type': 'memory',
      'id': entry.id,
      'path': entry.path,
      'mediaType': entry.mediaType,
      'name': entry.name,
      // Unique per shown notification: it lets a later launch of the app tell a
      // freshly tapped notification apart from a launch intent Android is
      // replaying (see [handleNotificationLaunchPayload]).
      'nonce': _newNonce(now),
    });

    AndroidBitmap<Object>? largeIcon;
    if (entry.thumbnail != null && entry.thumbnail!.isNotEmpty) {
      try {
        largeIcon = ByteArrayAndroidBitmap.fromBase64String(entry.thumbnail!);
      } catch (_) {}
    }

    final notificationId = entry.id.hashCode & 0x7fffffff;
    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
      importance: Importance.high,
      priority: Priority.high,
      sound: const RawResourceAndroidNotificationSound('notification'),
      playSound: true,
      largeIcon: largeIcon,
      styleInformation: const DefaultStyleInformation(true, true),
    );

    try {
      await NotificationService.localNotifications.show(
        id: notificationId,
        title: title,
        body: body,
        notificationDetails: NotificationDetails(android: androidDetails),
        payload: payload,
      );
      return true;
    } catch (e) {
      debugPrint('MediaRescue: Memory notification display failed: $e');
      return false;
    }
  }

  static Map<String, dynamic>? _parsePayload(String? payload) {
    if (payload == null || payload.isEmpty) return null;
    try {
      final decoded = jsonDecode(payload);
      if (decoded is Map<String, dynamic> && decoded['type'] == 'memory') {
        return decoded;
      }
    } catch (_) {}
    return null;
  }

  /// Opens the media of a Memory notification payload.
  ///
  /// Returns `true` when a preview was pushed. The [FileItem] handed to the
  /// viewer is built with a real media type: the cached Memory type is reused so
  /// the immersive viewer knows how to render the file, and files whose cached
  /// type is missing fall back to their extension. A [FileItem] without a media
  /// type renders an empty black page, which is exactly what a tapped Memory
  /// notification used to open.
  static Future<bool> _openMemory(Map<String, dynamic> memory) async {
    final path = memory['path'] as String? ?? '';
    final name = memory['name'] as String? ??
        (path.isNotEmpty ? path.split('/').last : 'Media');
    if (path.isEmpty) return false;

    final file = File(path);
    if (!file.existsSync()) {
      // The media was deleted or moved — say so instead of failing silently.
      final context = rootNavigatorKey.currentContext;
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Media file no longer exists: "$name"'),
            duration: const Duration(seconds: 4),
          ),
        );
      }
      return false;
    }

    // Stat first: the file is untouched by the wait for the UI below.
    final stat = await file.stat();

    // A notification tap is handled before the first frame of a cold start, so
    // wait for the navigator instead of dropping the tap.
    final context = await _waitForNavigator();
    if (context == null || !context.mounted) return false;

    final mediaType = _mediaTypeOf(file.path, memory['mediaType'] as String?);
    final fileItem = FileItem(
      path: file.path,
      name: name,
      extension: _extensionOf(file.path),
      size: stat.size,
      isDirectory: false,
      modifiedDate: stat.modified.millisecondsSinceEpoch,
      fileType: mediaType,
      parentDirectory: file.parent.path,
    );

    context.push('/preview/media', extra: {
      'item': fileItem,
      'allFiles': [fileItem],
    });
    return true;
  }

  /// Waits for the root navigator to exist (a notification can be handled before
  /// the first frame of a cold start is rendered) and returns its context.
  static Future<BuildContext?> _waitForNavigator() async {
    final deadline = DateTime.now().add(
      const Duration(milliseconds: _navigatorWaitMs),
    );
    while (true) {
      final context = rootNavigatorKey.currentContext;
      if (context != null && context.mounted) return context;
      if (!DateTime.now().isBefore(deadline)) return null;
      await Future<void>.delayed(
        const Duration(milliseconds: _navigatorPollMs),
      );
    }
  }

  /// Remembers [payload] as consumed, in memory and natively.
  static Future<void> _rememberConsumedPayload(String payload) async {
    _consumedPayloads.add(payload);
    try {
      await _storage.setAppPrefString(_prefKeyConsumedLaunchPayload, payload);
    } catch (_) {
      // Remembering the payload is best effort.
    }
  }

  static String _extensionOf(String path) {
    final dot = path.lastIndexOf('.');
    final slash = path.lastIndexOf('/');
    if (dot <= slash || dot == path.length - 1) return '';
    return path.substring(dot + 1).toLowerCase();
  }

  /// Media type used to reopen [path]: the cached Memory type when it is usable,
  /// otherwise the type derived from the file extension (the same extensions the
  /// native scanner classifies as media).
  static String _mediaTypeOf(String path, String? cachedType) {
    if (cachedType != null &&
        (cachedType == 'image' ||
            cachedType == 'video' ||
            cachedType == 'audio')) {
      return cachedType;
    }
    final ext = _extensionOf(path);
    if (_imageExtensions.contains(ext)) return 'image';
    if (_videoExtensions.contains(ext)) return 'video';
    if (_audioExtensions.contains(ext)) return 'audio';
    return 'other';
  }
}


