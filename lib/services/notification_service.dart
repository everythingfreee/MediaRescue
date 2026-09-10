import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'link_service.dart';
import 'storage_service.dart';

/// Client-side Firebase Cloud Messaging integration used to announce new
/// MediaRescue releases.
///
/// The v1.0.4 flow is intentionally simple:
///  * installations subscribe to the `mediarescue-updates` topic whenever
///    notification permission is granted (no accounts, no backend);
///  * messages reach the device and, when the user taps one, the Google Play
///    Store page for MediaRescue opens.
///
/// MediaRescue never depends on FCM: every failure here is swallowed so the
/// core scanning / managing features keep working offline.
class NotificationService {
  NotificationService._();

  /// Topic used for MediaRescue update announcements (managed manually in the
  /// Firebase Console).
  static const String updateTopic = 'mediarescue-updates';

  static final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  static final StorageService _storage = MethodChannelStorageService();

  static const int _updateNotificationId = 1404;

  /// SharedPreferences key for the user's notification preference.
  static const String _prefKeyNotificationsEnabled = 'notifications_enabled';

  static bool _initialized = false;
  static bool _subscribed = false;

  /// True when the app was opened (or focused) by tapping an update
  /// notification. Used to avoid showing the update dialog at the same time.
  static bool launchedFromUpdateNotification = false;

  /// Channel ID for update notifications — referenced both when creating the
  /// channel (with custom sound) and when showing individual notifications.
  static const String _channelId = 'mediarescue_updates';

  /// Must be called once, after `Firebase.initializeApp`. Never throws.
  static Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    // Local notifications are only used to display FCM messages while the
    // app is in the foreground (the system shows them automatically in the
    // background). Setting this up must never block or break startup.
    try {
      const AndroidInitializationSettings androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const InitializationSettings initSettings =
          InitializationSettings(android: androidSettings);
      await _localNotifications.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: (response) {
          // Tapping a foreground update notification opens the Play Store.
          launchedFromUpdateNotification = true;
          LinkService.openPlayStore();
        },
      );

      // On Android 8.0+ the notification sound is controlled by the channel,
      // not by individual notifications. We must create the channel with the
      // custom sound explicitly. Deleting any pre-existing channel first
      // ensures the new sound takes effect even after an app update.
      final androidPlugin = _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        try {
          await androidPlugin.deleteNotificationChannel(channelId: _channelId);
        } catch (_) {
          // Channel may not exist yet — ignore.
        }
        await androidPlugin.createNotificationChannel(
          const AndroidNotificationChannel(
            _channelId,
            'Update notifications',
            description: 'Announcements about new MediaRescue releases',
            importance: Importance.high,
            sound: RawResourceAndroidNotificationSound('notification'),
            playSound: true,
          ),
        );
      }
    } catch (e) {
      debugPrint('MediaRescue: local notifications unavailable ($e)');
    }

    try {
      // App launched by tapping a notification while terminated.
      final initialMessage = await _fcm.getInitialMessage();
      if (initialMessage != null) {
        launchedFromUpdateNotification = true;
        LinkService.openPlayStore();
      }

      // App brought to the foreground by tapping a notification.
      FirebaseMessaging.onMessageOpenedApp.listen((message) {
        launchedFromUpdateNotification = true;
        LinkService.openPlayStore();
      });

      // Foreground messages are not shown by the system on Android.
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // Check the user's persisted notification preference.
      // - null: key not set (first launch) → default to ON, auto-subscribe
      // - true: user explicitly enabled → auto-subscribe
      // - false: user explicitly disabled → unsubscribe to guarantee no
      //   notifications are received, even if a prior version left a stale
      //   FCM topic subscription active.
      final userPref = await _storage.getAppPrefBool(_prefKeyNotificationsEnabled);
      if (userPref != false) {
        await _subscribeWhenPermitted();
      } else {
        // User has explicitly disabled notifications — ensure unsubscribed.
        await _fcm.unsubscribeFromTopic(updateTopic);
        _subscribed = false;
      }
    } catch (e) {
      debugPrint('MediaRescue: Firebase Cloud Messaging unavailable ($e)');
    }
}

  /// Asks for notification permission at an appropriate moment (after the user
  /// finishes onboarding) and subscribes to the update topic when allowed.
  ///
  /// The system permission dialog is only shown while the OS still reports the
  /// status as not-determined, so users are never spammed on every launch and
  /// a denial is remembered by Android.
  static Future<void> requestPermissionIfNeeded() async {
    try {
      final settings = await _fcm.getNotificationSettings();
      if (settings.authorizationStatus != AuthorizationStatus.notDetermined) {
        // Already answered: subscribe when it was granted.
        await _subscribeWhenPermitted();
        return;
      }
      final requested = await _fcm.requestPermission(
        alert: true,
        badge: false,
        sound: true,
      );
      final status = requested.authorizationStatus;
      if (status == AuthorizationStatus.authorized ||
          status == AuthorizationStatus.provisional) {
        await _subscribe();
      }
    } catch (e) {
      debugPrint('MediaRescue: notification permission request failed ($e)');
    }
  }

  /// Whether push notifications are currently permitted by the user.
  static Future<bool> areNotificationsEnabled() async {
    try {
      final settings = await _fcm.getNotificationSettings();
      final status = settings.authorizationStatus;
      return status == AuthorizationStatus.authorized ||
          status == AuthorizationStatus.provisional;
    } catch (_) {
      return false;
    }
  }

  /// Whether this installation is currently subscribed to the update topic.
  /// This is the authoritative source for the toggle state in settings.
  static bool get isSubscribed => _subscribed;

  /// Subscribes this installation to [updateTopic] if permission allows it.
  /// Persists the user's preference so it survives app restarts.
  static Future<void> subscribe() async {
    await _subscribeWhenPermitted();
    // Persist the user's choice to re-enable notifications
    await _storage.setAppPrefBool(_prefKeyNotificationsEnabled, true);
  }

  /// Unsubscribes this installation from the update topic.
  /// Persists the user's preference so it survives app restarts.
  static Future<void> unsubscribe() async {
    if (!_subscribed) return;
    try {
      await _fcm.unsubscribeFromTopic(updateTopic);
      _subscribed = false;
    } catch (e) {
      debugPrint('MediaRescue: unsubscribe failed ($e)');
    }
    // Persist the user's choice to disable notifications
    await _storage.setAppPrefBool(_prefKeyNotificationsEnabled, false);
  }

  static Future<void> _subscribeWhenPermitted() async {
    if (await areNotificationsEnabled()) {
      await _subscribe();
    }
  }

  static Future<void> _subscribe() async {
    if (_subscribed) return;
    try {
      await _fcm.subscribeToTopic(updateTopic);
      _subscribed = true;
    } catch (e) {
      debugPrint('MediaRescue: topic subscription failed ($e)');
    }
  }

  static Future<void> _handleForegroundMessage(RemoteMessage message) async {
    if (WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
      // Background messages are shown by the Android system itself, so we
      // never re-post them here (avoids duplicate notifications).
      return;
    }
    final notification = message.notification;
    if (notification == null) return;

    try {
      await _localNotifications.show(
        id: _updateNotificationId,
        title: notification.title ?? 'MediaRescue update available',
        body: notification.body ??
            'A new version of MediaRescue is available on Google Play.',
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            'Update notifications',
            channelDescription:
                'Announcements about new MediaRescue releases',
            importance: Importance.high,
            priority: Priority.high,
            // Sound is set on the channel (created in initialize()) — do not
            // set it here or it will be ignored / cause a duplicate channel.
          ),
        ),
      );
    } catch (e) {
      debugPrint('MediaRescue: foreground notification failed ($e)');
    }
  }
}