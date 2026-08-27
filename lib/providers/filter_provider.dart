import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/file_item.dart';
import '../models/smart_filter.dart';

// ── Smart Filters state ───────────────────────────────────────────────────────

/// Holds the current Smart Filters state.
class SmartFilterController extends Notifier<SmartFilterState> {
  @override
  SmartFilterState build() => const SmartFilterState();

  /// Toggles a single file-type chip on/off.
  void toggleType(SmartTypeFilter type) {
    final current = Set<SmartTypeFilter>.from(state.types);
    if (current.contains(type)) {
      current.remove(type);
    } else {
      current.add(type);
    }
    state = state.copyWith(types: current);
  }

  void setSizeFilter(FileSizeFilter filter) =>
      state = state.copyWith(sizeFilter: filter);

  void setDateFilter(ModifiedDateFilter filter) =>
      state = state.copyWith(dateFilter: filter);

  void setInternalStorage(bool value) =>
      state = state.copyWith(internalStorage: value);

  void setSdCard(bool value) => state = state.copyWith(sdCard: value);

  void clear() => state = const SmartFilterState();
}

final smartFilterProvider =
    NotifierProvider<SmartFilterController, SmartFilterState>(
  SmartFilterController.new,
);

// ── Filter engine ────────────────────────────────────────────────────────────
//
// The engine operates purely on the in-memory list of indexed FileItems.
// Changing a filter recomputes on the existing index — it never re-scans the
// filesystem. All active filters are combined with AND (e.g. video + >500 MB
// + modified < 1 year + hidden).

/// Applies [filter] to [files]. Returns the same list unchanged when no
/// filter is active.
List<FileItem> applySmartFilters(List<FileItem> files, SmartFilterState filter) {
  if (!filter.isActive) return files;
  return files.where((file) => _matches(file, filter)).toList();
}

bool _matches(FileItem file, SmartFilterState f) {
  if (!_matchesType(file, f.types)) return false;
  if (!_matchesSize(file.size, f.sizeFilter)) return false;
  if (!_matchesDate(file.modifiedDate, f.dateFilter)) return false;
  if (!_matchesLocation(file.path, f)) return false;
  return true;
}

bool _matchesType(FileItem file, Set<SmartTypeFilter> types) {
  if (types.isEmpty) return true;
  for (final type in types) {
    switch (type) {
      case SmartTypeFilter.images:
        if (file.isImage) return true;
        break;
      case SmartTypeFilter.videos:
        if (file.isVideo) return true;
        break;
      case SmartTypeFilter.audio:
        if (file.isAudio) return true;
        break;
      case SmartTypeFilter.documents:
        if (file.isDocument) return true;
        break;
      case SmartTypeFilter.pdfs:
        if (file.isPdf) return true;
        break;
      case SmartTypeFilter.archives:
        if (file.isArchive) return true;
        break;
      case SmartTypeFilter.hidden:
        if (_isHidden(file)) return true;
        break;
    }
  }
  return false;
}

/// A file is hidden when its name (or any path segment) starts with a dot.
bool _isHidden(FileItem file) {
  if (file.name.startsWith('.')) return true;
  return file.path.split('/').any((segment) => segment.startsWith('.'));
}

bool _matchesSize(int size, FileSizeFilter filter) {
  switch (filter) {
    case FileSizeFilter.any:
      return true;
    case FileSizeFilter.above10mb:
      return size >= 10 * _mb;
    case FileSizeFilter.above100mb:
      return size >= 100 * _mb;
    case FileSizeFilter.above500mb:
      return size >= 500 * _mb;
    case FileSizeFilter.above1gb:
      return size >= 1 * _gb;
  }
}

bool _matchesDate(int modifiedDate, ModifiedDateFilter filter) {
  if (filter == ModifiedDateFilter.any) return true;
  final now = DateTime.now();
  final modified = _toDateTime(modifiedDate);
  switch (filter) {
    case ModifiedDateFilter.any:
      return true;
    case ModifiedDateFilter.today:
      final today = DateTime(now.year, now.month, now.day);
      return !modified.isBefore(today);
    case ModifiedDateFilter.last7Days:
      return modified.isAfter(now.subtract(const Duration(days: 7)));
    case ModifiedDateFilter.last30Days:
      return modified.isAfter(now.subtract(const Duration(days: 30)));
    case ModifiedDateFilter.lastYear:
      return modified.isAfter(now.subtract(const Duration(days: 365)));
  }
}

/// Converts a timestamp (milliseconds on Android, but guards against legacy
/// second-based values) into a [DateTime].
DateTime _toDateTime(int timestamp) {
  // Values < 100 billion are treated as seconds (10-digit epoch).
  return timestamp < 100000000000
      ? DateTime.fromMillisecondsSinceEpoch(timestamp * 1000)
      : DateTime.fromMillisecondsSinceEpoch(timestamp);
}

bool _matchesLocation(String path, SmartFilterState f) {
  // No location restriction: both storage areas are considered.
  if (!f.internalStorage && !f.sdCard) return true;
  final isOnInternal = path.startsWith('/storage/emulated/0');
  final isOnSdCard = path.startsWith('/storage/') && !isOnInternal;
  if (f.internalStorage && isOnInternal) return true;
  if (f.sdCard && isOnSdCard) return true;
  return false;
}

const int _mb = 1024 * 1024;
const int _gb = 1024 * _mb;