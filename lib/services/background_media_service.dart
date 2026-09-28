import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class BackgroundMediaState {
  final bool active;
  final bool playing;
  final int positionMs;

  const BackgroundMediaState({
    required this.active,
    required this.playing,
    required this.positionMs,
  });
}

class BackgroundMediaService {
  BackgroundMediaService._();

  static const MethodChannel _channel =
      MethodChannel('com.shaheer.mediarescue/media_playback');

  /// Upper bound for the playlist handed over to the Android playback service.
  ///
  /// The playlist travels inside the `Intent` that starts the foreground
  /// service, and Android refuses to start a service whose `Intent` payload
  /// crosses the Binder limit (~1 MB) — that failure
  /// (`TransactionTooLargeException`) is what broke background playback for
  /// very large feeds. Only a window around the current item is sent, which
  /// keeps the payload tiny while previous/next keep working from the
  /// notification, the lock screen and the headset controls.
  static const int maxQueueEntries = 120;

  static Future<bool> start({
    required String path,
    required String title,
    required Duration position,
    required bool playing,
    List<String> paths = const [],
    List<String> titles = const [],
    int index = 0,
    bool notificationEnabled = true,
  }) async {
    final queue = _boundedQueue(paths: paths, titles: titles, index: index);
    try {
      final started = await _channel.invokeMethod<bool>(
        'startBackgroundPlayback',
        {
          'path': path,
          'title': title,
          'positionMs': position.inMilliseconds,
          'playing': playing,
          'paths': queue.paths,
          'titles': queue.titles,
          'index': queue.index,
          'notificationEnabled': notificationEnabled,
        },
      );
      return started ?? true;
    } catch (e) {
      // A refused service start must never surface as an unhandled error.
      debugPrint('MediaRescue: background playback could not start ($e)');
      return false;
    }
  }

  /// Trims the playlist to [maxQueueEntries] items centred on the current one
  /// and remaps [index] into the trimmed window.
  ///
  /// The window is a plain move inside both lists, so no reference to the
  /// original playlist is kept and the payload size stays predictable no matter
  /// how large the feed is.
  static _PlaybackQueueWindow _boundedQueue({
    required List<String> paths,
    required List<String> titles,
    required int index,
  }) {
    final cleanPaths = <String>[
      for (final path in paths)
        if (path.isNotEmpty) path,
    ];
    final cleanTitles = <String>[
      for (final title in titles)
        if (title.isNotEmpty) title,
    ];
    if (cleanPaths.isEmpty) return const _PlaybackQueueWindow([], [], 0);

    var safeIndex = index;
    if (safeIndex < 0) safeIndex = 0;
    if (safeIndex > cleanPaths.length - 1) safeIndex = cleanPaths.length - 1;

    if (cleanPaths.length <= maxQueueEntries) {
      return _PlaybackQueueWindow(cleanPaths, cleanTitles, safeIndex);
    }

    var start = safeIndex - maxQueueEntries ~/ 2;
    if (start < 0) start = 0;
    final lastStart = cleanPaths.length - maxQueueEntries;
    if (start > lastStart) start = lastStart;
    final end = start + maxQueueEntries;
    final windowTitles = cleanTitles.length == cleanPaths.length
        ? cleanTitles.sublist(start, end)
        : cleanTitles;
    return _PlaybackQueueWindow(
      cleanPaths.sublist(start, end),
      windowTitles,
      safeIndex - start,
    );
  }

  static Future<BackgroundMediaState?> state() async {
    try {
      final raw = await _channel.invokeMethod<dynamic>('getPlaybackState');
      if (raw is! Map) return null;
      return BackgroundMediaState(
        active: raw['active'] == true,
        playing: raw['playing'] == true,
        positionMs: (raw['positionMs'] as num?)?.toInt() ?? 0,
      );
    } catch (e) {
      debugPrint('MediaRescue: background playback state unavailable ($e)');
      return null;
    }
  }

  static Future<void> stop() async {
    try {
      await _channel.invokeMethod<void>('stopBackgroundPlayback');
    } catch (e) {
      debugPrint('MediaRescue: background playback could not stop ($e)');
    }
  }

  static Future<bool> setting(String key, {bool fallback = true}) async {
    try {
      final value = await _channel.invokeMethod<bool>('getMediaSetting', {
        'key': key,
      });
      return value ?? fallback;
    } catch (_) {
      return fallback;
    }
  }

  static Future<void> setSetting(String key, bool value) async {
    try {
      await _channel.invokeMethod<void>('setMediaSetting', {
        'key': key,
        'value': value,
      });
    } catch (_) {
      // The in-app setting is applied regardless of persistence.
    }
  }

  static Future<bool> isIgnoringBatteryOptimizations() async {
    try {
      return await _channel.invokeMethod<bool>('isIgnoringBatteryOptimizations') ??
          true;
    } catch (_) {
      return true;
    }
  }

  static Future<void> requestBatteryOptimizationExemption() async {
    try {
      await _channel.invokeMethod<void>('requestBatteryOptimizationExemption');
    } catch (_) {
      // The system dialog is optional; playback still works without it.
    }
  }
}

/// A bounded window of the playlist plus the index of the current item inside
/// that window (see [BackgroundMediaService.maxQueueEntries]).
@immutable
class _PlaybackQueueWindow {
  final List<String> paths;
  final List<String> titles;
  final int index;

  const _PlaybackQueueWindow(this.paths, this.titles, this.index);
}
