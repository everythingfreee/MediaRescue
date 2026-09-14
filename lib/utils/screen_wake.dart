import 'package:wakelock_plus/wakelock_plus.dart';

class ScreenWake {
  /// Enables the screen wake lock to prevent the device from sleeping.
  static Future<void> enable() async {
    await WakelockPlus.enable();
  }

  /// Disables the screen wake lock, allowing the screen to turn off based on system settings.
  static Future<void> disable() async {
    await WakelockPlus.disable();
  }
}
