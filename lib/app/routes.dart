import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'app.dart';
import '../models/file_item.dart';
import '../screens/scaffold_with_nav_bar.dart';
import '../screens/home/home_screen.dart';
import '../screens/browse/browse_screen.dart';
import '../screens/search/search_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../screens/settings/about_screen.dart';
import '../screens/settings/contact_screen.dart';
import '../screens/settings/privacy_policy_screen.dart';
import '../screens/onboarding/permission_screen.dart';
import '../screens/preview/immersive_media_viewer_screen.dart';
import '../screens/preview/audio_player_screen.dart';
import '../screens/preview/pdf_viewer_screen.dart';
import '../screens/large_files/large_files_screen.dart';
import '../screens/hidden_media/hidden_media_screen.dart';
import '../screens/advanced_scan/advanced_scan_screen.dart';
import '../screens/advanced_scan/shizuku_guide_screen.dart';
import '../screens/gallery/gallery_screen.dart';
import '../providers/storage_provider.dart';
import '../providers/scanner_provider.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final storageService = ref.watch(storageServiceProvider);

  return GoRouter(
    initialLocation: '/home',
    navigatorKey: rootNavigatorKey,
    observers: [routeObserver],
    redirect: (context, state) async {
      final hasAccess = await storageService.hasAccess();
      final isGoingToOnboarding = state.matchedLocation == '/onboarding';

      if (!hasAccess && !isGoingToOnboarding) {
        return '/onboarding';
      }
      if (hasAccess && isGoingToOnboarding) {
        // Start the full-storage scan when access is granted.
        ref.read(scanControllerProvider.notifier).startScan();
        return '/home';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const PermissionScreen(),
      ),
      // Large files lives outside the shell so it gets a full-screen treatment
      // It is always opened with context.push(...) so the shell (and the
      // screen the user came from) stays alive underneath — Back then simply
      // pops back to the originating screen. See LargeFilesScreen._goBack.
      GoRoute(
        path: '/large-files',
        builder: (context, state) => const LargeFilesScreen(),
      ),
      // Hidden Media — same full-screen, pushed-on-top treatment as Large
      // Files so Back returns to the screen the user came from.
      GoRoute(
        path: '/hidden-media',
        builder: (context, state) => const HiddenMediaScreen(),
      ),
      // Advanced Scanning (optional Shizuku feature) — pushed on top like the
      // other full-screen routes so Back returns to the originating screen.
      GoRoute(
        path: '/advanced-scan',
        builder: (context, state) => const AdvancedScanScreen(),
      ),
      GoRoute(
        path: '/shizuku-guide',
        builder: (context, state) => const ShizukuGuideScreen(),
      ),
      // About / Contact / Privacy policy live outside the shell so they are
      // presented as normal full-screen pages with working back navigation.
      GoRoute(
        path: '/about',
        builder: (context, state) => const AboutScreen(),
      ),
      GoRoute(
        path: '/contact',
        builder: (context, state) => const ContactScreen(),
      ),
      GoRoute(
        path: '/privacy',
        builder: (context, state) => const PrivacyPolicyScreen(),
      ),
      // Preview screens live outside the shell so they get full-screen
      // treatment (no bottom navigation bar) and stop playback when
      // navigating away.
      //
      // All image + video previews reuse the same immersive viewer so the
      // browsing/rescue experience stays consistent everywhere.
      GoRoute(
        path: '/preview/media',
        builder: (context, state) => _immersiveViewer(state.extra),
      ),
      GoRoute(
        path: '/preview/image',
        builder: (context, state) {
          final item = state.extra as dynamic;
          if (item is FileItem) {
            return ImmersiveMediaViewerScreen(items: [item], initialIndex: 0);
          }
          return _immersiveViewer(item);
        },
      ),
      GoRoute(
        path: '/preview/video',
        builder: (context, state) {
          final extra = state.extra;
          if (extra is Map<String, dynamic>) {
            final item = extra['item'] as dynamic;
            final allFiles = (extra['allFiles'] as List? ?? []);
            return _immersiveViewer({
              'item': item,
              'allFiles': allFiles,
            });
          }
          return _immersiveViewer(extra);
        },
      ),
      GoRoute(
        path: '/preview/audio',
        builder: (context, state) {
          final extra = state.extra;
          if (extra is Map<String, dynamic>) {
            return AudioPlayerScreen(
              item: extra['item'] as dynamic,
              allFiles: (extra['allFiles'] as List? ?? []),
            );
          }
          return AudioPlayerScreen(item: extra as dynamic);
        },
      ),
      GoRoute(
        path: '/preview/pdf',
        builder: (context, state) =>
            PdfViewerScreen(item: state.extra as dynamic),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return ScaffoldWithNavBar(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/browse',
                builder: (context, state) => const BrowseScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/gallery',
                builder: (context, state) => const GalleryScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/search',
                builder: (context, state) => const SearchScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/settings',
                builder: (context, state) => const SettingsScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
/// Builds the [ImmersiveMediaViewerScreen] from the route `extra` payload.
/// Accepts either a single [FileItem] (e.g. the legacy image route) or a map
/// with {item, allFiles} where allFiles may contain any mix of images/videos.
Widget _immersiveViewer(dynamic extra) {
  if (extra is Map<String, dynamic>) {
    final item = extra['item'] as dynamic;
    final allFiles = (extra['allFiles'] as List? ?? const []);
    final media = allFiles
        .where((f) => f is FileItem && (f.isImage || f.isVideo))
        .cast<FileItem>()
        .toList();
    final list = media.isEmpty && item is FileItem
        ? <FileItem>[item]
        : (media.isEmpty ? <FileItem>[] : media);
    final itemFile = item is FileItem ? item : null;
    final initial = itemFile != null
        ? list.indexWhere((f) => f.path == itemFile.path)
        : -1;
    if (list.isEmpty) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Text(
            'Unable to preview this file.',
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    }
    return ImmersiveMediaViewerScreen(
      items: list,
      initialIndex: initial < 0 ? 0 : initial,
    );
  }
  if (extra is FileItem) {
    return ImmersiveMediaViewerScreen(items: [extra], initialIndex: 0);
  }
  return const Scaffold(
    backgroundColor: Colors.black,
    body: Center(
      child: Text(
        'Unable to preview this file.',
        style: TextStyle(color: Colors.white),
      ),
    ),
  );
}