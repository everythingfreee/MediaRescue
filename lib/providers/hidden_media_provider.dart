import 'dart:io';
import 'dart:isolate';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/file_item.dart';
import '../models/hidden_media.dart';
import '../models/smart_filter.dart';
import 'filter_provider.dart';
import 'gallery_provider.dart';
import 'scanner_provider.dart';
import 'storage_provider.dart';

/// File types considered for Hidden Media detection. Only media and common
/// document types are evaluated — the feature is about hidden *media*, not
/// every stray dotfile.
bool _isMediaCandidate(FileItem f) =>
    f.isImage || f.isVideo || f.isAudio || f.isPdf || f.isDocument;

/// Isolate worker: returns the directories (from [directories]) that contain
/// a `.nomedia` file. Every directory is checked independently so one
/// inaccessible path never breaks the whole scan.
Set<String> _findNomediaDirectories(List<String> directories) {
  final result = <String>{};
  for (final dir in directories) {
    try {
      if (File('$dir/.nomedia').existsSync()) {
        result.add(dir);
      }
    } catch (_) {
      // Permission failures / deleted files — skip this directory.
    }
  }
  return result;
}

/// Computes Hidden Media items from the already-indexed scan data.
///
/// Performance notes:
///  - Classification itself is pure path/string work over the in-memory
///    index (no filesystem access inside `build()`).
///  - The `.nomedia` filesystem checks run in a background isolate, once per
///    index change, and are wrapped per-directory in try/catch.
///  - MediaStore presence is fetched once per computation through the native
///    channel; when that query fails the signal is skipped (never guessed).
final hiddenMediaItemsProvider =
    FutureProvider.autoDispose<List<HiddenMediaItem>>((ref) async {
      final allFiles = ref.watch(allFilesProvider);
      final scanStatus = ref.watch(
        scanControllerProvider.select((s) => s.status),
      );

      // While a scan is in flight the index changes on every batch — skip the
      // computation until the scan settles, then run it exactly once.
      if (allFiles.isEmpty || scanStatus == ScanStatus.scanning) {
        return const [];
      }

      final candidates = allFiles
          .where((f) => !f.isDirectory && _isMediaCandidate(f))
          .toList();
      if (candidates.isEmpty) return const [];

      // Collect every unique directory (parent + ancestors up to the storage
      // root) that needs a .nomedia check.
      final dirs = <String>{};
      for (final f in candidates) {
        var dir = f.parentDirectory;
        while (dir.isNotEmpty && dir != hiddenStorageRoot) {
          dirs.add(dir);
          final slash = dir.lastIndexOf('/');
          if (slash <= 0) break;
          dir = dir.substring(0, slash);
        }
      }

      Set<String> nomediaDirs;
      try {
        nomediaDirs = await Isolate.run(
          () => _findNomediaDirectories(dirs.toList(growable: false)),
        );
      } catch (_) {
        nomediaDirs = const <String>{};
      }

      // MediaStore presence — best effort. null → signal unavailable.
      Set<String>? mediaStorePaths;
      try {
        final paths = await ref
            .read(storageServiceProvider)
            .getMediaStorePaths();
        mediaStorePaths = paths;
      } catch (_) {
        mediaStorePaths = null;
      }

      final items = <HiddenMediaItem>[];
      for (final f in candidates) {
        final reason = classifyHiddenMedia(
          f,
          nomediaDirs: nomediaDirs,
          mediaStorePaths: mediaStorePaths,
        );
        if (reason.isHidden) {
          items.add(HiddenMediaItem(item: f, reasons: reason));
        }
      }

      // Largest first, mirroring the Large Files screen.
      items.sort((a, b) => b.item.size.compareTo(a.item.size));
      return items;
    });

// ── Hidden Media view options ────────────────────────────────────────────────
//
// List or Large Icons (grid) layout, mirroring the Gallery view modes.

final hiddenMediaViewProvider =
    NotifierProvider<HiddenMediaViewNotifier, GalleryViewMode>(
      HiddenMediaViewNotifier.new,
    );

class HiddenMediaViewNotifier extends Notifier<GalleryViewMode> {
  @override
  GalleryViewMode build() => GalleryViewMode.list;

  void set(GalleryViewMode mode) => state = mode;

  void toggle() => state = state == GalleryViewMode.grid
      ? GalleryViewMode.list
      : GalleryViewMode.grid;
}

// ── Hidden Media search + smart filters ─────────────────────────────────────
//
// A dedicated SmartFilterState instance — narrowing Hidden Media must not
// affect the filters configured on the Search screen. The filter engine
// itself (applySmartFilters) is shared, so behavior stays identical.

final hiddenMediaFilterProvider =
    NotifierProvider<SmartFilterController, SmartFilterState>(
      SmartFilterController.new,
    );

class HiddenMediaQueryNotifier extends Notifier<String> {
  @override
  String build() => '';
  void set(String q) => state = q;
}

final hiddenMediaQueryProvider =
    NotifierProvider<HiddenMediaQueryNotifier, String>(
      HiddenMediaQueryNotifier.new,
    );

/// The hidden items matching the current search query and Smart Filters.
/// Purely in-memory over the already-classified list — instant, no re-scan.
final filteredHiddenMediaProvider = Provider<List<HiddenMediaItem>>((ref) {
  final asyncItems = ref.watch(hiddenMediaItemsProvider);
  final items = asyncItems.value ?? const <HiddenMediaItem>[];

  final query = ref.watch(hiddenMediaQueryProvider).toLowerCase().trim();
  final filter = ref.watch(hiddenMediaFilterProvider);

  var result = items;
  if (query.isNotEmpty) {
    result = result
        .where((e) => e.item.name.toLowerCase().contains(query))
        .toList();
  }

  if (!filter.isActive) return result;

  // Reuse the shared Smart Filters engine on the underlying FileItems, then
  // keep the entries whose file survived the filter (reasons travel along).
  final allowedFiles = applySmartFilters(
    result.map((e) => e.item).toList(),
    filter,
  ).map((f) => f.path).toSet();
  return result.where((e) => allowedFiles.contains(e.item.path)).toList();
});
