import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/storage_service.dart';

final storageServiceProvider = Provider<StorageService>((ref) {
  return MethodChannelStorageService();
});

/// SharedPreferences key used to persist the user's theme choice natively.
const themeModePrefKey = 'theme_mode';

ThemeMode _decodeThemeMode(String? value) {
  return switch (value) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => ThemeMode.system,
  };
}

String _encodeThemeMode(ThemeMode mode) {
  return switch (mode) {
    ThemeMode.light => 'light',
    ThemeMode.dark => 'dark',
    ThemeMode.system => 'system',
  };
}

/// Global theme mode — persists the user's choice with [StorageService] and
/// restores it on app restart. The initial state is `ThemeMode.system` until
/// the saved value is read.
class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    final storage = ref.watch(storageServiceProvider);
    var disposed = false;
    ref.onDispose(() => disposed = true);
    storage.getAppPrefString(themeModePrefKey).then((saved) {
      if (disposed) return;
      final mode = _decodeThemeMode(saved);
      if (mode != state) state = mode;
    });
    return ThemeMode.system;
  }

  Future<void> set(ThemeMode mode) async {
    state = mode;
    try {
      await ref
          .read(storageServiceProvider)
          .setAppPrefString(themeModePrefKey, _encodeThemeMode(mode));
    } catch (_) {
      // Theme switching must never fail because persistence is unavailable.
    }
  }
}

final themeModeProvider =
    NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);
