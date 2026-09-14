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

  static Future<void> start({
    required String path,
    required String title,
    required Duration position,
    required bool playing,
    List<String> paths = const [],
    List<String> titles = const [],
    int index = 0,
    bool notificationEnabled = true,
  }) async {
    await _channel.invokeMethod<void>('startBackgroundPlayback', {
      'path': path,
      'title': title,
      'positionMs': position.inMilliseconds,
      'playing': playing,
      'paths': paths,
      'titles': titles,
      'index': index,
      'notificationEnabled': notificationEnabled,
    });
  }

  static Future<BackgroundMediaState?> state() async {
    final raw = await _channel.invokeMethod<dynamic>('getPlaybackState');
    if (raw is! Map) return null;
    return BackgroundMediaState(
      active: raw['active'] == true,
      playing: raw['playing'] == true,
      positionMs: (raw['positionMs'] as num?)?.toInt() ?? 0,
    );
  }

  static Future<void> stop() async {
    await _channel.invokeMethod<void>('stopBackgroundPlayback');
  }

  static Future<bool> setting(String key, {bool fallback = true}) async {
    final value = await _channel.invokeMethod<bool>('getMediaSetting', {'key': key});
    return value ?? fallback;
  }

  static Future<void> setSetting(String key, bool value) async {
    await _channel.invokeMethod<void>('setMediaSetting', {'key': key, 'value': value});
  }

  static Future<bool> isIgnoringBatteryOptimizations() async {
    return await _channel.invokeMethod<bool>('isIgnoringBatteryOptimizations') ?? true;
  }

  static Future<void> requestBatteryOptimizationExemption() async {
    await _channel.invokeMethod<void>('requestBatteryOptimizationExemption');
  }
}
