import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediarescue/app/theme/app_theme.dart';
import 'package:mediarescue/app/theme/haptic_splash_factory.dart';
import 'package:mediarescue/services/background_media_service.dart';
import 'package:mediarescue/services/haptics_service.dart';

/// Regression tests for the two v1.0.9 fixes that can be verified without a
/// device:
///
/// * app-wide haptic feedback (theme-level splash factory), and
/// * the bounded playlist handed to the Android background playback service,
///   which is what made `startBackgroundPlayback` fail with
///   `TransactionTooLargeException` on very large feeds.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const storageChannel = MethodChannel('com.shaheer.mediarescue/storage');
  const playbackChannel = MethodChannel(
    'com.shaheer.mediarescue/media_playback',
  );

  late List<MethodCall> platformCalls;

  setUp(() {
    platformCalls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          platformCalls.add(call);
          return null;
        });
    // Preferences are written by HapticsService when settings change.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(storageChannel, (call) async => null);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(storageChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(playbackChannel, null);
  });

  int hapticTicks() => platformCalls
      .where((call) => call.method == 'HapticFeedback.vibrate')
      .length;


  group('haptic feedback', () {
    test('both app themes route taps through the haptic splash factory', () {
      expect(AppTheme.lightTheme.splashFactory, isA<HapticSplashFactory>());
      expect(AppTheme.darkTheme.splashFactory, isA<HapticSplashFactory>());
    });

    testWidgets('buttons, icon buttons and list tiles vibrate once per press', (
      tester,
    ) async {
      HapticsService.setEnabled(true);
      var taps = 0;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: Column(
              children: [
                FilledButton(onPressed: () => taps++, child: const Text('Tap')),
                IconButton(
                  onPressed: () => taps++,
                  icon: const Icon(Icons.add),
                ),
                ListTile(title: const Text('Row'), onTap: () => taps++),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      platformCalls.clear();
      await tester.tap(find.text('Tap'));
      await tester.pumpAndSettle();
      expect(taps, 1);
      expect(hapticTicks(), 1);

      platformCalls.clear();
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();
      expect(taps, 2);
      expect(hapticTicks(), 1);

      platformCalls.clear();
      await tester.tap(find.text('Row'));
      await tester.pumpAndSettle();
      expect(taps, 3);
      expect(hapticTicks(), 1);
    });

    testWidgets('a disabled button never vibrates', (tester) async {
      HapticsService.setEnabled(true);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(
            body: FilledButton(onPressed: null, child: Text('Disabled')),
          ),
        ),
      );
      await tester.pumpAndSettle();

      platformCalls.clear();
      await tester.tap(find.text('Disabled'));
      await tester.pumpAndSettle();
      expect(hapticTicks(), 0);
    });

    testWidgets('haptics switched off in Settings silence every tap', (
      tester,
    ) async {
      await HapticsService.setEnabled(false);
      addTearDown(() => HapticsService.setEnabled(true));

      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: FilledButton(
              onPressed: () => taps++,
              child: const Text('Tap'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      platformCalls.clear();
      await tester.tap(find.text('Tap'));
      await tester.pumpAndSettle();
      expect(taps, 1);
      expect(hapticTicks(), 0);
    });
  });

  group('background playback payload', () {
    test('a huge playlist is trimmed to a Binder-safe window', () async {
      MethodCall? startCall;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(playbackChannel, (call) async {
            startCall = call;
            return true;
          });

      final paths = [
        for (var i = 0; i < 5000; i++)
          '/storage/emulated/0/Android/data/hidden.file_$i.mp4',
      ];
      final titles = [for (var i = 0; i < 5000; i++) 'hidden.file_$i.mp4'];
      const current = 4200;

      final started = await BackgroundMediaService.start(
        path: paths[current],
        title: titles[current],
        position: const Duration(seconds: 12),
        playing: true,
        paths: paths,
        titles: titles,
        index: current,
      );

      expect(started, isTrue);
      expect(startCall, isNotNull);
      expect(startCall!.method, 'startBackgroundPlayback');

      final args = Map<Object?, Object?>.from(startCall!.arguments as Map);
      final sentPaths = (args['paths'] as List).cast<String>();
      final sentTitles = (args['titles'] as List).cast<String>();
      final sentIndex = args['index'] as int;

      expect(sentPaths.length, BackgroundMediaService.maxQueueEntries);
      expect(sentTitles.length, BackgroundMediaService.maxQueueEntries);
      // The item being played stays the current one inside the window.
      expect(sentPaths[sentIndex], paths[current]);
      expect(sentTitles[sentIndex], titles[current]);
      // The payload stays far below the Binder transaction limit (~1 MB).
      final bytes = sentPaths.fold<int>(0, (sum, path) => sum + path.length);
      expect(bytes, lessThan(64 * 1024));
      expect(args['path'], paths[current]);
    });

    test('a small playlist is handed over unchanged', () async {
      MethodCall? startCall;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(playbackChannel, (call) async {
            startCall = call;
            return true;
          });

      const paths = ['/a.mp4', '/b.mp4', '/c.mp4'];
      const titles = ['a', 'b', 'c'];

      final started = await BackgroundMediaService.start(
        path: paths[2],
        title: titles[2],
        position: Duration.zero,
        playing: true,
        paths: paths,
        titles: titles,
        index: 2,
      );

      expect(started, isTrue);
      final args = Map<Object?, Object?>.from(startCall!.arguments as Map);
      expect(args['paths'], paths);
      expect(args['titles'], titles);
      expect(args['index'], 2);
    });

    test('a refused service start is reported instead of thrown', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(playbackChannel, (call) async {
            throw PlatformException(
              code: 'PLAYBACK_START_FAILED',
              message: 'TransactionTooLargeException',
            );
          });

      final started = await BackgroundMediaService.start(
        path: '/a.mp4',
        title: 'a',
        position: Duration.zero,
        playing: true,
      );

      expect(started, isFalse);
    });
  });

    }