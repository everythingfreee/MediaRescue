import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app/app.dart';
import 'firebase_options.dart';
import 'services/notification_service.dart';
import 'services/update_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase is optional for MediaRescue: if it fails to initialize the app
  // still starts and everything except FCM update announcements keeps working.
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('MediaRescue: Firebase initialization failed ($e)');
  }

  runApp(
    const ProviderScope(
      child: MediaRescueApp(),
    ),
  );

  // Wire up FCM (listeners, topic subscription, foreground notifications)
  // once the plugin is available — never blocks the UI.
  NotificationService.initialize();

  // Check Google Play for updates after the first frame so the Home screen is
  // already usable; the check itself runs in the background.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    UpdateService.startUpdateCheck();
  });
}
