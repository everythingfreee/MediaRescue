import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'storage_service.dart';

/// Haptic strength chosen by the user in Settings.
enum HapticIntensity { light, medium, strong }

/// Immutable snapshot of the user's haptic preferences, exposed through
/// [HapticsService.state] so Settings can rebuild reactively.
@immutable
class HapticsState {
  final bool enabled;
  final HapticIntensity intensity;

  const HapticsState({
    this.enabled = true,
    this.intensity = HapticsService.defaultIntensity,
  });

  HapticsState copyWith({bool? enabled, HapticIntensity? intensity}) {
    return HapticsState(
      enabled: enabled ?? this.enabled,
      intensity: intensity ?? this.intensity,
    );
  }
}

/// Central haptic-feedback service for MediaRescue.
///
/// Follows the same static-service pattern already used by
/// [NotificationService] and [BackgroundMediaService]: the user's preference is
/// persisted through the existing [StorageService] app preferences and cached
/// in memory, so gestures (like the player's playback-speed hold) can trigger
/// feedback synchronously without touching a platform channel.
///
/// Every call is best effort — a device without a vibrator, a restricted
/// platform or a disabled preference simply produces no feedback, and nothing
/// here can ever throw into the UI.
class HapticsService {
  HapticsService._();

  /// SharedPreferences keys read/written through the existing storage channel.
  static const String prefEnabledKey = 'haptics_enabled';
  static const String prefIntensityKey = 'haptics_intensity';

  /// Deliberately subtle default.
  static const HapticIntensity defaultIntensity = HapticIntensity.light;

  static final StorageService _storage = MethodChannelStorageService();

  static bool _enabled = true;
  static HapticIntensity _intensity = defaultIntensity;

  /// Reactive state for Settings (and any other UI that wants to reflect it).
  static final ValueNotifier<HapticsState> state =
      ValueNotifier<HapticsState>(const HapticsState());

  static bool get enabled => _enabled;
  static HapticIntensity get intensity => _intensity;

  /// Loads the persisted preference once at startup. Never throws.
  static Future<void> initialize() async {
    try {
      final savedEnabled = await _storage.getAppPrefBool(prefEnabledKey);
      final savedIntensity = await _storage.getAppPrefString(prefIntensityKey);
      _enabled = savedEnabled ?? true;
      _intensity = decodeIntensity(savedIntensity);
      state.value = HapticsState(enabled: _enabled, intensity: _intensity);
    } catch (_) {
      // Preferences unavailable — keep the defaults.
    }
  }

  /// Enables/disables all MediaRescue haptic feedback.
  static Future<void> setEnabled(bool value) async {
    _enabled = value;
    state.value = state.value.copyWith(enabled: value);
    try {
      await _storage.setAppPrefBool(prefEnabledKey, value);
    } catch (_) {
      // Persistence is best effort; the in-memory value still applies.
    }
  }

  /// Changes the haptic strength.
  static Future<void> setIntensity(HapticIntensity value) async {
    _intensity = value;
    state.value = state.value.copyWith(intensity: value);
    try {
      await _storage.setAppPrefString(prefIntensityKey, encodeIntensity(value));
    } catch (_) {
      // Persistence is best effort; the in-memory value still applies.
    }
  }

  /// Soft feedback used when the temporary playback-speed mode activates.
  static void playbackSpeed() => _fire(soft: true);

  /// Standard feedback for buttons and confirmations across the app.
  static void buttonPress() => _fire();

  /// Very light acknowledgement (used for toggles).
  static void selection() => _fire(soft: true);

  static String encodeIntensity(HapticIntensity value) {
    return switch (value) {
      HapticIntensity.light => 'light',
      HapticIntensity.medium => 'medium',
      HapticIntensity.strong => 'strong',
    };
  }

  static HapticIntensity decodeIntensity(String? value) {
    return switch (value) {
      'medium' => HapticIntensity.medium,
      'strong' => HapticIntensity.strong,
      _ => defaultIntensity,
    };
  }

  /// Fires one haptic tick. [soft] keeps the playback-speed cue gentle so it
  /// never feels harsh during a long press.
  static void _fire({bool soft = false}) {
    if (!_enabled) return;
    try {
      final Future<void> haptic;
      if (soft) {
        // Softest possible feedback at every intensity level.
        haptic = _intensity == HapticIntensity.strong
            ? HapticFeedback.lightImpact()
            : HapticFeedback.selectionClick();
      } else {
        haptic = switch (_intensity) {
          HapticIntensity.light => HapticFeedback.selectionClick(),
          HapticIntensity.medium => HapticFeedback.lightImpact(),
          HapticIntensity.strong => HapticFeedback.mediumImpact(),
        };
      }
      // A platform failure must never surface as an unhandled error.
      haptic.then<void>((_) {}, onError: (Object _) {});
    } catch (_) {
      // Unsupported platform — silently skip haptics.
    }
  }
}
