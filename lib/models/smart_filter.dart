import 'package:flutter/foundation.dart';

/// The file-type categories a user can combine in Smart Filters.
/// Mirrors the categories shown as chips in the filter UI.
enum SmartTypeFilter {
  images,
  videos,
  audio,
  documents,
  pdfs,
  archives,
  hidden,
}

/// Minimum file-size thresholds.
enum FileSizeFilter {
  any,
  above10mb,
  above100mb,
  above500mb,
  above1gb,
}

/// Recency limits based on a file's modified date.
enum ModifiedDateFilter {
  any,
  today,
  last7Days,
  last30Days,
  lastYear,
}

/// An immutable, combinable set of Smart Filters.
///
/// All filters are ANDed together when applied. Because every filter simply
/// operates on the already-indexed [FileItem]s, changing a filter never
/// triggers a filesystem re-scan.
@immutable
class SmartFilterState {
  /// Active file-type chips (empty = no type restriction).
  final Set<SmartTypeFilter> types;

  /// Minimum accepted file size. Any = no restriction.
  final FileSizeFilter sizeFilter;

  /// Recency of the modified date. Any = no restriction.
  final ModifiedDateFilter dateFilter;

  /// Include files stored on internal storage (/storage/emulated/0).
  final bool internalStorage;

  /// Include files stored on the SD card (/storage/XXXX-XXXX).
  final bool sdCard;

  const SmartFilterState({
    this.types = const {},
    this.sizeFilter = FileSizeFilter.any,
    this.dateFilter = ModifiedDateFilter.any,
    this.internalStorage = true,
    this.sdCard = true,
  });

  bool get hasTypeFilter => types.isNotEmpty;
  bool get hasSizeFilter => sizeFilter != FileSizeFilter.any;
  bool get hasDateFilter => dateFilter != ModifiedDateFilter.any;

  /// A location restriction is active only when the user has picked a single
  /// storage location (only internal OR only SD card).
  bool get hasLocationFilter => internalStorage != sdCard;

  /// Returns true when at least one filter should narrow the results.
  bool get isActive =>
      hasTypeFilter || hasSizeFilter || hasDateFilter || hasLocationFilter;

  /// Number of independent filter categories currently narrowing results.
  int get activeGroupCount =>
      (hasTypeFilter ? 1 : 0) +
      (hasSizeFilter ? 1 : 0) +
      (hasDateFilter ? 1 : 0) +
      (hasLocationFilter ? 1 : 0);

  SmartFilterState copyWith({
    Set<SmartTypeFilter>? types,
    FileSizeFilter? sizeFilter,
    ModifiedDateFilter? dateFilter,
    bool? internalStorage,
    bool? sdCard,
  }) {
    return SmartFilterState(
      types: types ?? this.types,
      sizeFilter: sizeFilter ?? this.sizeFilter,
      dateFilter: dateFilter ?? this.dateFilter,
      internalStorage: internalStorage ?? this.internalStorage,
      sdCard: sdCard ?? this.sdCard,
    );
  }
}