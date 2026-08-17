import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/file_item.dart';
import '../services/storage_service.dart';
import 'storage_provider.dart';

// ── Enums ─────────────────────────────────────────────────────────────────────

/// Filter for which file types to show in the gallery.
enum GalleryFilter {
  all,
  images,
  videos,
  audio,
  documents,
  text,
  other,
}

/// View layout mode for the gallery.
enum GalleryViewMode {
  list,
  grid,
}

/// Sort order for the gallery.
enum GallerySort {
  nameAsc,
  nameDesc,
  sizeAsc,
  sizeDesc,
  dateAsc,
  dateDesc,
  typeAsc,
  typeDesc,
}

// ── State ─────────────────────────────────────────────────────────────────────

class GalleryState {
  final String? selectedFolderPath;
  final String? selectedFolderName;
  final List<FileItem> files;
  final bool isLoading;
  final String? error;
  final GalleryFilter filter;
  final GalleryViewMode viewMode;
  final GallerySort sort;
  final Set<String> selectedPaths;

  const GalleryState({
    this.selectedFolderPath,
    this.selectedFolderName,
    this.files = const [],
    this.isLoading = false,
    this.error,
    this.filter = GalleryFilter.all,
    this.viewMode = GalleryViewMode.grid,
    this.sort = GallerySort.nameAsc,
    this.selectedPaths = const {},
  });

  GalleryState copyWith({
    String? selectedFolderPath,
    String? selectedFolderName,
    List<FileItem>? files,
    bool? isLoading,
    String? error,
    GalleryFilter? filter,
    GalleryViewMode? viewMode,
    GallerySort? sort,
    Set<String>? selectedPaths,
  }) {
    return GalleryState(
      selectedFolderPath: selectedFolderPath ?? this.selectedFolderPath,
      selectedFolderName: selectedFolderName ?? this.selectedFolderName,
      files: files ?? this.files,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      filter: filter ?? this.filter,
      viewMode: viewMode ?? this.viewMode,
      sort: sort ?? this.sort,
      selectedPaths: selectedPaths ?? this.selectedPaths,
    );
  }

  /// Files filtered by the current [filter] and sorted by [sort].
  List<FileItem> get filteredFiles {
    List<FileItem> result;
    switch (filter) {
      case GalleryFilter.all:
        result = List.from(files);
        break;
      case GalleryFilter.images:
        result = files.where((f) => f.isImage).toList();
        break;
      case GalleryFilter.videos:
        result = files.where((f) => f.isVideo).toList();
        break;
      case GalleryFilter.audio:
        result = files.where((f) => f.isAudio).toList();
        break;
      case GalleryFilter.documents:
        result = files.where((f) => f.isPdf || f.isDocument).toList();
        break;
      case GalleryFilter.text:
        result = files.where((f) => f.isText).toList();
        break;
      case GalleryFilter.other:
        result = files
            .where((f) =>
                !f.isImage &&
                !f.isVideo &&
                !f.isAudio &&
                !f.isPdf &&
                !f.isDocument &&
                !f.isText)
            .toList();
        break;
    }

    // Apply sort
    switch (sort) {
      case GallerySort.nameAsc:
        result.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        break;
      case GallerySort.nameDesc:
        result.sort((a, b) => b.name.toLowerCase().compareTo(a.name.toLowerCase()));
        break;
      case GallerySort.sizeAsc:
        result.sort((a, b) => a.size.compareTo(b.size));
        break;
      case GallerySort.sizeDesc:
        result.sort((a, b) => b.size.compareTo(a.size));
        break;
      case GallerySort.dateAsc:
        result.sort((a, b) => a.modifiedDate.compareTo(b.modifiedDate));
        break;
      case GallerySort.dateDesc:
        result.sort((a, b) => b.modifiedDate.compareTo(a.modifiedDate));
        break;
      case GallerySort.typeAsc:
        result.sort((a, b) {
          final typeCompare = a.fileType.compareTo(b.fileType);
          if (typeCompare != 0) return typeCompare;
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        });
        break;
      case GallerySort.typeDesc:
        result.sort((a, b) {
          final typeCompare = b.fileType.compareTo(a.fileType);
          if (typeCompare != 0) return typeCompare;
          return b.name.toLowerCase().compareTo(a.name.toLowerCase());
        });
        break;
    }
    return result;
  }

  bool get isSelectionMode => selectedPaths.isNotEmpty;
}

// ── Notifier ──────────────────────────────────────────────────────────────────

class GalleryNotifier extends Notifier<GalleryState> {
  @override
  GalleryState build() {
    return const GalleryState();
  }

  /// Selects a folder and scans it recursively.
  Future<void> selectFolder(String path, String name) async {
    state = state.copyWith(
      selectedFolderPath: path,
      selectedFolderName: name,
      isLoading: true,
      error: null,
      selectedPaths: const {},
    );

    final storageService = ref.read(storageServiceProvider);
    final files = await storageService.scanDirectory(path);

    state = state.copyWith(
      files: files,
      isLoading: false,
    );
  }

  /// Clears the current folder selection.
  void clearFolder() {
    state = const GalleryState();
  }

  /// Sets the file type filter.
  void setFilter(GalleryFilter filter) {
    state = state.copyWith(filter: filter, selectedPaths: const {});
  }

  /// Sets the view mode (list or grid).
  void setViewMode(GalleryViewMode mode) {
    state = state.copyWith(viewMode: mode);
  }

  /// Sets the sort order.
  void setSort(GallerySort sort) {
    state = state.copyWith(sort: sort);
  }

  /// Toggles selection of a file.
  void toggleSelection(FileItem item) {
    final current = Set<String>.from(state.selectedPaths);
    if (current.contains(item.path)) {
      current.remove(item.path);
    } else {
      current.add(item.path);
    }
    state = state.copyWith(selectedPaths: current);
  }

  /// Selects all currently filtered files.
  void selectAll() {
    state = state.copyWith(
      selectedPaths: state.filteredFiles.map((f) => f.path).toSet(),
    );
  }

  /// Clears the selection.
  void clearSelection() {
    state = state.copyWith(selectedPaths: const {});
  }

  /// Removes deleted files from the list.
  void removeFiles(List<String> paths) {
    final pathSet = paths.toSet();
    state = state.copyWith(
      files: state.files.where((f) => !pathSet.contains(f.path)).toList(),
      selectedPaths: const {},
    );
  }

  /// Refreshes the current folder scan.
  Future<void> refresh() async {
    final path = state.selectedFolderPath;
    final name = state.selectedFolderName;
    if (path == null) return;
    await selectFolder(path, name ?? path);
  }
}

final galleryProvider =
    NotifierProvider<GalleryNotifier, GalleryState>(GalleryNotifier.new);

// ── Storage roots ─────────────────────────────────────────────────────────────

final storageRootsProvider = FutureProvider<List<StorageRoot>>((ref) async {
  final storageService = ref.watch(storageServiceProvider);
  return await storageService.getStorageRoots();
});