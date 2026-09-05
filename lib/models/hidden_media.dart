// Hidden / unusual media model.
//
// Classification is heuristic and based on combined evidence — no single
// signal alone proves a file is intentionally hidden.

import 'file_item.dart';

/// Directory depth (number of directories below the storage root) from which
/// a path is considered "unusually deep". Configurable in one place.
const int hiddenDeepPathThreshold = 6;

/// Root of shared internal storage used for relative-depth calculations.
const String hiddenStorageRoot = '/storage/emulated/0';

/// Directory segments that are considered an app-private / non-user-facing
/// location on their own (a strong signal).
const List<String> _appPrivateDirSegments = ['data', 'obb'];

/// Directory names that are unusual for user-facing media (weak signal).
const Set<String> _unusualDirSegments = {
  'cache',
  'tmp',
  'temp',
  'thumbnails',
  '.cache',
  '.thumbnails',
  'lost+found',
  'trash',
  '.trash',
  'backup',
  'backups',
  'logs',
};

/// The independent signals collected for one media file.
class HiddenMediaReason {
  final bool hiddenDirectory;
  final bool nomedia;
  final bool mediaStoreMissing;
  final bool unusualLocation;

  /// True when the unusual location is an app-private directory
  /// (`Android/data`, `Android/obb`) — treated as a strong signal.
  final bool appPrivateLocation;
  final bool deepPath;

  const HiddenMediaReason({
    this.hiddenDirectory = false,
    this.nomedia = false,
    this.mediaStoreMissing = false,
    this.unusualLocation = false,
    this.appPrivateLocation = false,
    this.deepPath = false,
  });

  int get weakSignalCount =>
      (unusualLocation && !appPrivateLocation ? 1 : 0) +
      (deepPath ? 1 : 0) +
      (mediaStoreMissing ? 1 : 0);

  /// Combined-evidence classification:
  ///  - hidden directory or .nomedia → hidden (strong on its own)
  ///  - app-private location (Android/data, Android/obb) → hidden
  ///  - otherwise at least two weak signals must agree.
  bool get isHidden =>
      hiddenDirectory || nomedia || appPrivateLocation || weakSignalCount >= 2;

  /// Human-readable reasons — only the signals that are actually true.
  List<String> get reasonLabels {
    final labels = <String>[];
    if (hiddenDirectory) labels.add('Inside a hidden directory');
    if (nomedia) labels.add('Located in a .nomedia directory');
    if (mediaStoreMissing) labels.add('Missing from MediaStore');
    if (appPrivateLocation) {
      labels.add('App-private location (Android/data or Android/obb)');
    } else if (unusualLocation) {
      labels.add('Unusual location');
    }
    if (deepPath) labels.add('Deep directory path');
    return labels;
  }
}

/// One hidden/unusual media entry: the file plus why it was classified.
class HiddenMediaItem {
  final FileItem item;
  final HiddenMediaReason reasons;

  const HiddenMediaItem({required this.item, required this.reasons});

  bool get isHidden => reasons.isHidden;
}

/// Pure classification over indexed metadata. Cheap path/string work only —
/// expensive filesystem checks (.nomedia) are performed separately and passed
/// in as [nomediaDirs] (a set of directories — direct or ancestor — that
/// contain a `.nomedia` file).
///
/// [mediaStorePaths] is the set of paths Android's MediaStore surfaces.
/// When it is `null` (the query failed / unavailable) the signal is skipped
/// so we never produce false positives.
HiddenMediaReason classifyHiddenMedia(
  FileItem file, {
  required Set<String> nomediaDirs,
  Set<String>? mediaStorePaths,
}) {
  if (file.isDirectory) {
    return const HiddenMediaReason();
  }

  // Relative path below the storage root.
  String rel = file.path;
  if (rel.startsWith('$hiddenStorageRoot/')) {
    rel = rel.substring(hiddenStorageRoot.length + 1);
  } else if (rel == hiddenStorageRoot) {
    rel = '';
  }
  final segments = rel
      .split('/')
      .where((s) => s.isNotEmpty)
      .toList(growable: false);

  // 4.1 hiddenDirectory — any path segment starts with a dot.
  final hiddenDirectory = segments.any((s) => s.startsWith('.'));

  // 4.2 .nomedia — the file sits under a directory containing a .nomedia
  //     file (checked for the parent and every ancestor directory).
  final nomedia = _anyAncestorIn(nomediaDirs, file.parentDirectory);

  // 4.5 deepPath — directories below the storage root (excluding the name).
  final deepPath = segments.length - 1 >= hiddenDeepPathThreshold;

  // 4.4 unusualLocation — app-private roots or known cache/temp dirs.
  var appPrivate = false;
  var unusual = false;
  for (var i = 0; i < segments.length; i++) {
    final s = segments[i];
    if (s == 'Android' &&
        i + 1 < segments.length &&
        _appPrivateDirSegments.contains(segments[i + 1])) {
      appPrivate = true;
      unusual = true;
      break;
    }
    if (_unusualDirSegments.contains(s.toLowerCase())) {
      unusual = true;
    }
  }

  // 4.3 mediaStoreMissing — exists on disk but not surfaced by MediaStore.
  final mediaStoreMissing =
      mediaStorePaths != null && !mediaStorePaths.contains(file.path);

  return HiddenMediaReason(
    hiddenDirectory: hiddenDirectory,
    nomedia: nomedia,
    mediaStoreMissing: mediaStoreMissing,
    unusualLocation: unusual,
    appPrivateLocation: appPrivate,
    deepPath: deepPath,
  );
}

/// Walks [directory] up to the storage root, returning true when it — or any
/// ancestor — is a directory marked in [dirs].
bool _anyAncestorIn(Set<String> dirs, String directory) {
  var current = directory;
  while (current.isNotEmpty && current != hiddenStorageRoot) {
    if (dirs.contains(current)) return true;
    final slash = current.lastIndexOf('/');
    if (slash <= 0) break;
    current = current.substring(0, slash);
  }
  return false;
}
