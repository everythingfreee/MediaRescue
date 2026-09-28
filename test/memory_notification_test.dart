import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediarescue/models/file_item.dart';
import 'package:mediarescue/screens/preview/immersive_media_viewer_screen.dart';
import 'package:mediarescue/screens/settings/memory_cache_screen.dart';
import 'package:mediarescue/services/memory_service.dart';

/// Regression tests for the v1.0.9 Memory notification fixes:
///
/// * the debug test notification picks a **random** cached media file (it used
///   to always report the single "best" entry),
/// * the metadata cached for Memories is exposed for the developer screen,
/// * a tapped Memory notification opens a **typed** [FileItem] so the player can
///   actually play the media instead of showing an empty black page, and
/// * the launch payload is consumed exactly once, so a replayed launch intent can
///   never reopen the same media after the app was restarted.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const storageChannel = MethodChannel('com.shaheer.mediarescue/storage');
  const notificationsChannel = MethodChannel(
    'dexterous.com/flutter/local_notifications',
  );

  late Directory tempDir;
  late String cacheJson;
  late List<MethodCall> notificationCalls;
  late List<MethodCall> storageCalls;
  final prefs = <String, String>{};

  late String videoPath;
  late String photoPath;
  late String audioPath;
  late String missingPath;

  String payloadFor({
    required String id,
    required String path,
    required String name,
    String mediaType = 'video',
    String nonce = 'n1',
  }) => jsonEncode({
    'type': 'memory',
    'id': id,
    'path': path,
    'mediaType': mediaType,
    'name': name,
    'nonce': nonce,
  });

  int prefWrites() =>
      storageCalls.where((call) => call.method == 'setAppPrefString').length;

  setUpAll(() {
    // The generated `dart_plugin_registrant.dart` does this in the app; tests
    // have to register the Android local-notifications implementation manually.
    AndroidFlutterLocalNotificationsPlugin.registerWith();

    tempDir = Directory.systemTemp.createTempSync('mediarescue_memory_test');
    videoPath = '${tempDir.path}/hidden_clip.mp4';
    photoPath = '${tempDir.path}/hidden_photo.jpg';
    audioPath = '${tempDir.path}/hidden_song.mp3';
    missingPath = '${tempDir.path}/deleted_memory.mkv';
    File(videoPath).writeAsStringSync('video');
    File(photoPath).writeAsStringSync('photo');
    File(audioPath).writeAsStringSync('audio');

    cacheJson = jsonEncode([
      {
        'id': 'audio0001',
        'path': audioPath,
        'name': 'hidden_song.mp3',
        'mediaType': 'audio',
        'creationDate': 0,
        'cachedAt': 1000,
        'dateResolved': true,
      },
      {
        'id': 'video0001',
        'path': videoPath,
        'name': 'hidden_clip.mp4',
        'mediaType': 'video',
        'creationDate': DateTime(2020, 5, 4).millisecondsSinceEpoch,
        'cachedAt': 5000,
        'dateResolved': true,
        'lastNotified': '2024-05-04',
        'thumbnail': 'not-base64!!',
      },
      {
        'id': 'photo0001',
        'path': photoPath,
        'name': 'hidden_photo.jpg',
        'mediaType': 'image',
        'creationDate': DateTime(2019, 2, 2).millisecondsSinceEpoch,
        'cachedAt': 3000,
        'dateResolved': false,
      },
      {
        'id': 'gone00001',
        'path': missingPath,
        'name': 'deleted_memory.mkv',
        'mediaType': 'video',
        'creationDate': DateTime(2018, 1, 1).millisecondsSinceEpoch,
        'cachedAt': 9000,
        'dateResolved': true,
      },
    ]);

    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

    messenger.setMockMethodCallHandler(storageChannel, (call) async {
      storageCalls.add(call);
      final args = call.arguments is Map
          ? Map<Object?, Object?>.from(call.arguments as Map)
          : const <Object?, Object?>{};
      switch (call.method) {
        case 'loadMemoryCache':
          return cacheJson;
        case 'saveMemoryCache':
          return true;
        case 'getThumbnail':
          return null;
        case 'getAppPrefString':
          return prefs[args['key'] as String?];
        case 'setAppPrefString':
          prefs[args['key'] as String] = args['value'] as String;
          return true;
        case 'getAppPrefBool':
          return null;
        case 'setAppPrefBool':
          return true;
        default:
          return null;
      }
    });

    messenger.setMockMethodCallHandler(notificationsChannel, (call) async {
      notificationCalls.add(call);
      return true;
    });
  });

  tearDownAll(() async {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(storageChannel, null);
    messenger.setMockMethodCallHandler(notificationsChannel, null);
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  setUp(() {
    storageCalls = <MethodCall>[];
    notificationCalls = <MethodCall>[];
    prefs.clear();
  });

  group('test Memory notification', () {
    test('picks a random cached media file that is still on disk', () async {
      final picks = <String>[];
      for (var i = 0; i < 40; i++) {
        final entry = await MemoryService.sendTestNotification();
        expect(entry, isNotNull);
        picks.add(entry!.id);

        // A notification really is posted for every pick.
        expect(notificationCalls, isNotEmpty);
        expect(notificationCalls.last.method, 'show');
        final args = Map<Object?, Object?>.from(
          notificationCalls.last.arguments as Map,
        );
        expect(args['payload'], contains('"type":"memory"'));
        expect(args['payload'], contains('"nonce"'));
      }

      // The cached entry whose file was deleted is never reported.
      expect(picks, isNot(contains('gone00001')));
      // Two presses in a row never report the very same media …
      for (var i = 1; i < picks.length; i++) {
        expect(picks[i], isNot(picks[i - 1]));
      }
      // … and repeated presses walk through the cache.
      expect(picks.toSet().length, greaterThanOrEqualTo(3));
    });
  });

  group('developer cache inspector', () {
    test('exposes the cached metadata, newest first', () async {
      final entries = await MemoryService.debugEntries();

      expect(entries.map((entry) => entry.id).toList(), [
        'gone00001',
        'video0001',
        'photo0001',
        'audio0001',
      ]);

      final video = entries[1];
      expect(video.path, videoPath);
      expect(video.name, 'hidden_clip.mp4');
      expect(video.mediaType, 'video');
      expect(video.creationDate, DateTime(2020, 5, 4).millisecondsSinceEpoch);
      expect(video.dateResolved, isTrue);
      expect(video.lastNotified, '2024-05-04');
      expect(video.thumbnail, 'not-base64!!');

      expect(await MemoryService.debugCacheBytes(), cacheJson.length);
    });
  });

  group('notification payload handling', () {
    test('a replayed launch payload is consumed exactly once', () async {
      final payload = payloadFor(
        id: 'gone00001',
        path: missingPath,
        name: 'deleted_memory.mkv',
        nonce: 'launch-a',
      );

      // Cold start from a fresh tap.
      await MemoryService.handleNotificationLaunchPayload(payload);
      expect(prefWrites(), 1);
      expect(prefs['memory_consumed_launch_payload'], payload);

      // Android replays the very same launch intent after a restart: the media
      // must not reopen by itself.
      await MemoryService.handleNotificationLaunchPayload(payload);
      expect(prefWrites(), 1);

      // A new notification (fresh nonce) is handled again.
      final fresh = payloadFor(
        id: 'gone00001',
        path: missingPath,
        name: 'deleted_memory.mkv',
        nonce: 'launch-b',
      );
      await MemoryService.handleNotificationLaunchPayload(fresh);
      expect(prefWrites(), 2);
      expect(prefs['memory_consumed_launch_payload'], fresh);
    });

    test('a tapped payload is remembered so a later launch is not repeated', () async {
      final payload = payloadFor(
        id: 'tap00001',
        path: missingPath,
        name: 'deleted_memory.mkv',
        nonce: 'tap-a',
      );

      expect(MemoryService.handleNotificationPayload(payload), isTrue);
      // The same tap reported twice never opens the media twice.
      expect(MemoryService.handleNotificationPayload(payload), isTrue);
      expect(prefWrites(), 1);
      expect(prefs['memory_consumed_launch_payload'], payload);

      // Coming back through the launch intent is a replay, not a new tap.
      await MemoryService.handleNotificationLaunchPayload(payload);
      expect(prefWrites(), 1);
    });

    test('payloads that are not Memories are ignored', () async {
      expect(await MemoryService.handleNotificationLaunchPayload(null), isFalse);
      expect(await MemoryService.handleNotificationLaunchPayload(''), isFalse);
      expect(
        await MemoryService.handleNotificationLaunchPayload('{"type":"update"}'),
        isFalse,
      );
      expect(
        await MemoryService.handleNotificationLaunchPayload('not json'),
        isFalse,
      );
      expect(MemoryService.handleNotificationPayload('not json'), isFalse);
      expect(prefWrites(), 0);
    });

    test('opening a cached entry whose file is gone reports gracefully', () async {
      final entries = await MemoryService.debugEntries();
      final gone = entries.firstWhere((entry) => entry.id == 'gone00001');
      expect(await MemoryService.openCachedEntry(gone), isFalse);
    });
  });

  group('player fallback', () {
    testWidgets(
      'an item without a media type explains itself instead of a black page',
      (tester) async {
        // This is the FileItem a tapped Memory notification used to build.
        const untyped = FileItem(
          path: '/tmp/hidden_clip.mp4',
          name: 'hidden_clip.mp4',
          size: 1024,
          modifiedDate: 0,
          isDirectory: false,
        );
        expect(untyped.isVideo, isFalse);

        await tester.pumpWidget(
          const MaterialApp(
            home: ImmersiveMediaViewerScreen(items: [untyped], initialIndex: 0),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Unable to preview this file.'), findsOneWidget);
      },
    );
  });

  group('Memory cache screen', () {
    testWidgets('lists the cached metadata and the cache summary', (
      tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: MemoryCacheScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Memory cache'), findsOneWidget);
      expect(find.text('Developer tool'), findsOneWidget);
      expect(find.text('CACHED MEMORIES (4)'), findsOneWidget);
      expect(find.text('Send test Memory notification'), findsOneWidget);

      // Every cached entry is listed, newest first, with its metadata badges.
      await tester.scrollUntilVisible(find.text('deleted_memory.mkv'), 150);
      expect(find.text('missing'), findsOneWidget);

      await tester.scrollUntilVisible(find.text('hidden_clip.mp4'), 150);
      expect(find.text('video'), findsWidgets);

      await tester.scrollUntilVisible(find.text('hidden_song.mp3'), 150);
      expect(find.text('audio'), findsWidgets);

      // The full metadata of an entry is one tap away.
      await tester.scrollUntilVisible(find.text('hidden_photo.jpg'), 150);
      await tester.tap(find.text('hidden_photo.jpg'));
      await tester.pumpAndSettle();

      expect(find.text('Media type'), findsOneWidget);
      expect(find.text('Open media'), findsOneWidget);
      expect(find.text(photoPath), findsWidgets);
    });
  });
}
