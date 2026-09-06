import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/file_item.dart';
import '../models/smart_filter.dart';
import '../services/advanced_scan_service.dart';
import 'filter_provider.dart';

/// High-level Shizuku availability / authorization state shown in the UI.
enum ShizukuStatus {
  unknown,
  unavailable,
  binderNotReceived,
  binderDisconnected,
  notRunning,
  waitingForPermission,
  permissionDenied,
  authorized,
  serviceConnected,
  error,
}

/// Lifecycle of the advanced scan itself.
enum AdvancedScanStatus {
  idle,
  starting,
  scanning,
  completed,
  cancelled,
  failed,
}

/// Immutable UI state for the optional Shizuku Advanced Scanning feature.
/// Fully independent from the normal scanner state (`ScanState`).
class AdvancedScanState {
  final ShizukuStatus shizukuStatus;
  final AdvancedScanStatus scanStatus;

  /// Accumulated read-only results — files and directories of the two
  /// approved roots only. Reuses the existing [FileItem] model.
  final List<FileItem> files;

  final String progressStage;
  final int filesFound;
  final int errorCount;

  /// Last user-facing outcome message (never stack traces).
  final String? message;

  /// rootIndex → 'ok' | 'missing' | 'inaccessible' | 'unknown'
  final Map<int, String> rootStatuses;

  const AdvancedScanState({
    this.shizukuStatus = ShizukuStatus.unknown,
    this.scanStatus = AdvancedScanStatus.idle,
    this.files = const [],
    this.progressStage = '',
    this.filesFound = 0,
    this.errorCount = 0,
    this.message,
    this.rootStatuses = const {},
  });

  AdvancedScanState copyWith({
    ShizukuStatus? shizukuStatus,
    AdvancedScanStatus? scanStatus,
    List<FileItem>? files,
    String? progressStage,
    int? filesFound,
    int? errorCount,
    String? message,
    bool clearMessage = false,
    Map<int, String>? rootStatuses,
  }) {
    return AdvancedScanState(
      shizukuStatus: shizukuStatus ?? this.shizukuStatus,
      scanStatus: scanStatus ?? this.scanStatus,
      files: files ?? this.files,
      progressStage: progressStage ?? this.progressStage,
      filesFound: filesFound ?? this.filesFound,
      errorCount: errorCount ?? this.errorCount,
      message: clearMessage ? null : (message ?? this.message),
      rootStatuses: rootStatuses ?? this.rootStatuses,
    );
  }
}

/// Controller for the Advanced Scanning feature. Talks only to
/// [AdvancedScanService]; all Shizuku specifics live on the native side.
class AdvancedScanController extends Notifier<AdvancedScanState> {
  static const previewCachePath =
      '/storage/emulated/0/Android/media/com.shaheer.mediarescue.mediarescue/advanced_preview_cache';

  /// Human labels for the two hard-coded scan roots. The indexes MUST match
  /// the native service (0 = Android/data, 1 = Android/obb).
  static const rootLabels = <int, String>{0: 'Android/data', 1: 'Android/obb'};

  final AdvancedScanService _service = AdvancedScanService.instance;
  StreamSubscription<Map<Object?, Object?>>? _events;

  /// Growable accumulator shared with the state (append-only during a scan —
  /// safe on Dart's single-threaded event loop and avoids O(n²) list copies).
  final List<FileItem> _files = <FileItem>[];

  @override
  AdvancedScanState build() {
    ref.onDispose(() {
      _events?.cancel();
      _events = null;
    });
    unawaited(loadCachedFiles());
    return const AdvancedScanState();
  }

  /// Restores files already copied to the app-owned preview cache. This does
  /// not require Shizuku and is separate from a fresh scan.
  Future<void> loadCachedFiles() async {
    try {
      final directory = Directory(previewCachePath);
      if (!await directory.exists() || state.files.isNotEmpty) return;
      final cached = <FileItem>[];
      await for (final entity in directory.list(followLinks: false)) {
        if (entity is! File) continue;
        final name = entity.uri.pathSegments.last;
        final stat = await entity.stat();
        cached.add(
          FileItem(
            path: entity.path,
            name: name,
            size: stat.size,
            modifiedDate: stat.modified.millisecondsSinceEpoch,
            isDirectory: false,
            extension: name.contains('.') ? name.split('.').last : '',
            fileType: _fileTypeFor(name),
            parentDirectory: directory.path,
          ),
        );
      }
      if (cached.isEmpty || state.files.isNotEmpty) return;
      state = state.copyWith(
        scanStatus: AdvancedScanStatus.completed,
        files: cached,
        filesFound: cached.length,
        message: 'Loaded ${cached.length} cached preview files.',
      );
    } catch (_) {
      // Cache restoration is best effort; a fresh scan remains available.
    }
  }

  static String _fileTypeFor(String name) {
    final extension = name.contains('.')
        ? name.split('.').last.toLowerCase()
        : '';
    if (const {
      'jpg',
      'jpeg',
      'png',
      'gif',
      'bmp',
      'webp',
      'heic',
      'heif',
      'svg',
      'ico',
      'tiff',
      'tif',
    }.contains(extension)) {
      return 'image';
    }
    if (const {
      'mp4',
      'mkv',
      'avi',
      'mov',
      'wmv',
      'flv',
      'webm',
      'm4v',
      '3gp',
      'ts',
      'mts',
      'm2ts',
    }.contains(extension)) {
      return 'video';
    }
    if (const {
      'mp3',
      'wav',
      'aac',
      'flac',
      'ogg',
      'm4a',
      'wma',
      'opus',
      'amr',
      'mid',
      'midi',
    }.contains(extension)) {
      return 'audio';
    }
    if (extension == 'pdf') return 'pdf';
    return 'other';
  }

  bool get _scanActive =>
      state.scanStatus == AdvancedScanStatus.scanning ||
      state.scanStatus == AdvancedScanStatus.starting;

  // ── Shizuku status ────────────────────────────────────────────────────────

  /// Re-reads the Shizuku / user-service status from the native side.
  Future<void> refreshStatus() async {
    try {
      final raw = await _service.getShizukuState();
      final stateStr = raw['state'] as String? ?? '';
      final status = switch (stateStr) {
        'unavailable' => ShizukuStatus.unavailable,
        'binder_not_received' => ShizukuStatus.binderNotReceived,
        'binder_disconnected' => ShizukuStatus.binderDisconnected,
        'not_running' => ShizukuStatus.notRunning,
        'waiting_for_permission' => ShizukuStatus.waitingForPermission,
        'permission_denied' => ShizukuStatus.permissionDenied,
        'authorized' => ShizukuStatus.authorized,
        'service_connected' => ShizukuStatus.serviceConnected,
        _ => ShizukuStatus.error,
      };
      state = state.copyWith(shizukuStatus: status);
    } catch (_) {
      state = state.copyWith(shizukuStatus: ShizukuStatus.error);
    }
  }

  /// Opens the Shizuku authorization dialog. Returns true when granted.
  Future<bool> requestAuthorization() async {
    try {
      final raw = await _service.requestShizukuPermission();
      switch (raw['status'] as String? ?? 'error') {
        case 'granted':
          await refreshStatus();
          return true;
        case 'denied':
          state = state.copyWith(
            shizukuStatus: ShizukuStatus.permissionDenied,
            message:
                'Shizuku authorization was denied. You can try again at any time.',
          );
        case 'not_running':
          state = state.copyWith(
            shizukuStatus: ShizukuStatus.notRunning,
            message: 'Shizuku is not running. Start Shizuku and try again.',
          );
        default:
          state = state.copyWith(
            message:
                (raw['message'] as String?) ??
                'Could not request Shizuku authorization.',
          );
      }
      return false;
    } catch (_) {
      state = state.copyWith(
        message: 'Could not request Shizuku authorization.',
      );
      return false;
    }
  }

  // ── Scan control ──────────────────────────────────────────────────────────

  /// Starts a read-only advanced scan of Android/data and Android/obb.
  Future<void> startScan() async {
    if (_scanActive) return;

    _files.clear();
    state = state.copyWith(
      scanStatus: AdvancedScanStatus.starting,
      files: _files,
      rootStatuses: const {},
      filesFound: 0,
      errorCount: 0,
      progressStage: 'Starting…',
      clearMessage: true,
    );

    // Subscribe BEFORE starting so early events are not lost.
    await _events?.cancel();
    _events = _service.events().listen(
      _onEvent,
      onError: (Object e) {
        if (_scanActive) {
          state = state.copyWith(
            scanStatus: AdvancedScanStatus.failed,
            message: 'Advanced Scanning failed unexpectedly.',
          );
        }
      },
    );

    final ok = await _service.startAdvancedScan();
    if (!ok) {
      unawaited(_events?.cancel());
      _events = null;
      state = state.copyWith(
        scanStatus: AdvancedScanStatus.failed,
        message:
            'Could not start Advanced Scanning. Make sure Shizuku is running and authorized.',
      );
    }
  }

  /// Cancels the active scan. The outcome arrives as a completion event.
  Future<void> stopScan() async {
    await _service.stopAdvancedScan();
  }

  /// Clears results and returns to the idle state (Shizuku status is kept).
  void clearResults() {
    if (_scanActive) return;
    _files.clear();
    state = state.copyWith(
      scanStatus: AdvancedScanStatus.idle,
      files: _files,
      filesFound: 0,
      errorCount: 0,
      progressStage: '',
      rootStatuses: const {},
      clearMessage: true,
    );
  }

  // ── Native event handling ─────────────────────────────────────────────────

  void _onEvent(Map<Object?, Object?> event) {
    switch (event['type']) {
      case 'progress':
        state = state.copyWith(
          scanStatus: AdvancedScanStatus.scanning,
          filesFound:
              (event['filesFound'] as num?)?.toInt() ?? state.filesFound,
          errorCount: (event['errors'] as num?)?.toInt() ?? state.errorCount,
          progressStage: event['currentPath'] as String? ?? state.progressStage,
        );

      case 'batch':
        final entries = event['entries'];
        if (entries is List) {
          for (final raw in entries) {
            try {
              final decoded = jsonDecode(raw as String);
              if (decoded is Map) {
                // Entries use the same keys as FileItem.fromMap — the existing
                // model is reused for advanced scan results.
                _files.add(
                  FileItem.fromMap(Map<Object?, Object?>.from(decoded)),
                );
              }
            } catch (_) {
              // A malformed entry is skipped; the scan is never broken by one.
            }
          }
          state = state.copyWith(files: _files);
        }

      case 'rootStatus':
        final index = (event['rootIndex'] as num?)?.toInt();
        if (index != null) {
          final status = (event['status'] as num?)?.toInt() ?? -1;
          final message = event['message'] as String? ?? '';
          final rootLabel = switch (status) {
            0 => 'ok',
            1 => 'missing',
            2 => 'inaccessible',
            3 => 'inaccessible',
            _ => 'unknown',
          };
          state = state.copyWith(
            rootStatuses: {...state.rootStatuses, index: rootLabel},
            message: status == 0 ? null : message,
            clearMessage: status == 0,
          );
        }

      case 'rootComplete':
        final message = event['message'] as String? ?? '';
        if (message.isNotEmpty) {
          state = state.copyWith(message: message);
        }

      case 'completed':
        unawaited(_events?.cancel());
        _events = null;
        final cancelled = event['cancelled'] == true;
        final failed = event['failed'] == true;
        final reason = event['reason'] as String?;
        final total =
            (event['totalFiles'] as num?)?.toInt() ?? state.filesFound;
        final errs = (event['errorCount'] as num?)?.toInt() ?? state.errorCount;
        if (failed || reason == 'shizuku_lost') {
          // Failure / lost-connection outcomes keep the already-collected
          // results visible but are NEVER shown as a successful completion.
          state = state.copyWith(
            scanStatus: AdvancedScanStatus.failed,
            filesFound: total,
            errorCount: errs,
            message: state.message ?? 'The scan stopped before completing.',
          );
        } else if (cancelled) {
          state = state.copyWith(
            scanStatus: AdvancedScanStatus.cancelled,
            filesFound: total,
            errorCount: errs,
            message:
                'Scan cancelled — $total entries were collected before stopping.',
          );
        } else {
          state = state.copyWith(
            scanStatus: AdvancedScanStatus.completed,
            filesFound: total,
            errorCount: errs,
            message: errs > 0
                ? 'Scan completed — $total entries found, $errs could not be accessed.'
                : 'Scan completed — $total entries found.',
          );
        }

      case 'error':
        final message =
            event['message'] as String? ??
            'Advanced Scanning reported a problem.';
        final errorType = event['errorType'] as String? ?? '';
        final scanLevel =
            errorType == 'SHIZUKU_DISCONNECTED' ||
            errorType == 'IPC_ERROR' ||
            errorType == 'SCAN_START_FAILED' ||
            errorType == 'SHIZUKU_NOT_READY' ||
            errorType == 'SERVICE_START_FAILED' ||
            errorType == 'SCAN_ERROR';
        state = state.copyWith(
          message: message,
          scanStatus: scanLevel && _scanActive
              ? AdvancedScanStatus.failed
              : state.scanStatus,
        );

      case 'state':
        unawaited(refreshStatus());
    }
  }
}

final advancedScanProvider =
    NotifierProvider<AdvancedScanController, AdvancedScanState>(
      AdvancedScanController.new,
    );

/// Smart Filters scoped to Advanced Scanning. Search keeps its own filters.
final advancedSmartFilterProvider =
    NotifierProvider<SmartFilterController, SmartFilterState>(
      SmartFilterController.new,
    );
