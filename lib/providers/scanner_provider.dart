import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/file_item.dart';
import 'filter_provider.dart';
import 'storage_provider.dart';

// ── Scan State ─────────────────────────────────────────────────────────────────

enum ScanStatus { idle, scanning, complete, error }

class ScanState {
  final ScanStatus status;
  final int filesDiscovered;
  final String currentPath;
  final int dirsScanned;
  final List<FileItem> files;
  final String? error;

  const ScanState({
    this.status = ScanStatus.idle,
    this.filesDiscovered = 0,
    this.currentPath = '',
    this.dirsScanned = 0,
    this.files = const [],
    this.error,
  });

  ScanState copyWith({
    ScanStatus? status,
    int? filesDiscovered,
    String? currentPath,
    int? dirsScanned,
    List<FileItem>? files,
    String? error,
  }) {
    return ScanState(
      status: status ?? this.status,
      filesDiscovered: filesDiscovered ?? this.filesDiscovered,
      currentPath: currentPath ?? this.currentPath,
      dirsScanned: dirsScanned ?? this.dirsScanned,
      files: files ?? this.files,
      error: error ?? this.error,
    );
  }
}

/// Manages the full-storage scan lifecycle.
/// Listens to the native EventChannel and accumulates discovered files.
/// Loads previously saved scan data on startup instead of re-scanning.
class ScanController extends Notifier<ScanState> {
  StreamSubscription<Map<Object?, Object?>>? _subscription;
  bool _loadedFromCache = false;

  @override
  ScanState build() {
    ref.onDispose(() {
      _subscription?.cancel();
    });

    // Load saved scan data on first build (app startup)
    if (!_loadedFromCache) {
      _loadedFromCache = true;
      _loadCachedData();
    }

    return const ScanState();
  }

  Future<void> _loadCachedData() async {
    final storageService = ref.read(storageServiceProvider);
    final cached = await storageService.loadScanData();
    if (cached.isNotEmpty) {
      state = ScanState(
        status: ScanStatus.complete,
        filesDiscovered: cached.length,
        files: cached,
      );
    }
  }

  /// Starts (or restarts) a full scan of /storage/emulated/0.
  Future<void> startScan() async {
    // Cancel any previous subscription
    await _subscription?.cancel();

    state = const ScanState(status: ScanStatus.scanning);

    final storageService = ref.read(storageServiceProvider);

    // Listen to native scan events BEFORE starting the scan
    _subscription = storageService.scanEvents().listen(
      (event) {
        final type = event['type'] as String?;
        switch (type) {
          case 'progress':
            state = state.copyWith(
              status: ScanStatus.scanning,
              filesDiscovered:
                  (event['filesDiscovered'] as num?)?.toInt() ??
                      state.filesDiscovered,
              currentPath: event['currentPath'] as String? ?? state.currentPath,
              dirsScanned: (event['dirsScanned'] as num?)?.toInt() ??
                  state.dirsScanned,
            );
            break;
          case 'batch':
            final batch = (event['files'] as List<dynamic>? ?? [])
                .map((e) => FileItem.fromMap(e as Map<Object?, Object?>))
                .toList();
            state = state.copyWith(
              status: ScanStatus.scanning,
              files: [...state.files, ...batch],
              filesDiscovered: state.filesDiscovered + batch.length,
            );
            break;
          case 'complete':
            final totalFiles =
                (event['totalFiles'] as num?)?.toInt() ?? state.filesDiscovered;
            state = state.copyWith(
              status: ScanStatus.complete,
              filesDiscovered: totalFiles,
            );
            // Save the scan results for next app launch
            _saveScanData();
            break;
          case 'error':
            state = state.copyWith(
              status: ScanStatus.error,
              error: event['message'] as String? ?? 'Scan failed',
            );
            break;
        }
      },
      onError: (Object error) {
        state = state.copyWith(
          status: ScanStatus.error,
          error: error.toString(),
        );
      },
      onDone: () {
        if (state.status == ScanStatus.scanning) {
          state = state.copyWith(status: ScanStatus.complete);
          _saveScanData();
        }
      },
    );

    // Kick off the native scan
    await storageService.startScan();
  }

  Future<void> _saveScanData() async {
    final storageService = ref.read(storageServiceProvider);
    await storageService.saveScanData(state.files);
  }

  /// Stops an in-progress scan.
  Future<void> stopScan() async {
    await ref.read(storageServiceProvider).stopScan();
  }

  /// Clears all scanned data.
  void reset() {
    state = const ScanState();
  }
}

final scanControllerProvider =
    NotifierProvider<ScanController, ScanState>(ScanController.new);

/// All discovered files (from the scan index).
final allFilesProvider = Provider<List<FileItem>>((ref) {
  return ref.watch(scanControllerProvider).files;
});

/// True while a scan is in progress.
final isScanningProvider = Provider<bool>((ref) {
  return ref.watch(scanControllerProvider).status == ScanStatus.scanning;
});

// ── Search ────────────────────────────────────────────────────────────────────

class SearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';
  void set(String q) => state = q;
}

final searchQueryProvider =
    NotifierProvider<SearchQueryNotifier, String>(SearchQueryNotifier.new);

final searchResultsProvider = Provider<List<FileItem>>((ref) {
  final query = ref.watch(searchQueryProvider).toLowerCase().trim();
  final allFiles = ref.watch(allFilesProvider);
  final filter = ref.watch(smartFilterProvider);

  var results = allFiles;
  if (query.isNotEmpty) {
    results = results.where((f) => f.name.toLowerCase().contains(query)).toList();
  }
  // Apply smart filters on the already-indexed list (no re-scan).
  return applySmartFilters(results, filter);
});

// ── Large Files ───────────────────────────────────────────────────────────────

class LargeFilesThresholdNotifier extends Notifier<int> {
  @override
  int build() => 50 * 1024 * 1024; // default 50 MB
  void set(int bytes) => state = bytes;
}

final largeFilesThresholdProvider =
    NotifierProvider<LargeFilesThresholdNotifier, int>(
        LargeFilesThresholdNotifier.new);

final largeFilesProvider = Provider<List<FileItem>>((ref) {
  final threshold = ref.watch(largeFilesThresholdProvider);
  final allFiles = ref.watch(allFilesProvider);
  final large = allFiles.where((f) => f.size >= threshold).toList()
    ..sort((a, b) => b.size.compareTo(a.size));
  return large;
});

// ── Storage Stats ─────────────────────────────────────────────────────────────

final storageStatsProvider = Provider<Map<String, int>>((ref) {
  final allFiles = ref.watch(allFilesProvider);
  var images = 0, videos = 0, audio = 0, docs = 0, other = 0;
  for (final f in allFiles) {
    if (f.isImage) {
      images += f.size;
    } else if (f.isVideo) {
      videos += f.size;
    } else if (f.isAudio) {
      audio += f.size;
    } else if (f.isPdf || f.isDocument) {
      docs += f.size;
    } else {
      other += f.size;
    }
  }
  return {
    'Images': images,
    'Videos': videos,
    'Audio': audio,
    'Documents': docs,
    'Other': other,
    'Total': images + videos + audio + docs + other,
    'Count': allFiles.length,
  };
});