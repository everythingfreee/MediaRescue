import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_radius.dart';
import '../../app/theme/app_spacing.dart';
import '../../models/file_item.dart';
import '../../providers/gallery_provider.dart';
import '../../providers/storage_provider.dart';
import '../../widgets/app_card.dart';
import '../../widgets/thumbnail_image.dart';
import 'file_info_screen.dart';
import 'folder_picker_screen.dart';

class GalleryScreen extends ConsumerStatefulWidget {
  const GalleryScreen({super.key});

  @override
  ConsumerState<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends ConsumerState<GalleryScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gallery = ref.watch(galleryProvider);
    final theme = Theme.of(context);

    if (gallery.searchQuery.isEmpty && _searchController.text.isNotEmpty) {
      _searchController.clear();
    }

    return Scaffold(
      appBar: gallery.selectedFolderPath == null
          ? AppBar(title: const Text('Gallery'))
          : AppBar(
              title: TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  hintText: 'Search gallery files...',
                  border: InputBorder.none,
                  prefixIcon: HugeIcon(
                    icon: HugeIcons.strokeRoundedSearch01,
                    size: 20,
                  ),
                ),
                onChanged: (value) =>
                    ref.read(galleryProvider.notifier).setSearchQuery(value),
              ),
              actions: [
                IconButton(
                  icon: const HugeIcon(
                    icon: HugeIcons.strokeRoundedRefresh,
                    color: AppColors.primary,
                  ),
                  tooltip: 'Rescan folder',
                  onPressed: () => ref.read(galleryProvider.notifier).refresh(),
                ),
                IconButton(
                  icon: const HugeIcon(
                    icon: HugeIcons.strokeRoundedFolder01,
                    color: AppColors.primary,
                  ),
                  tooltip: 'Change folder',
                  onPressed: () => _openFolderPicker(context),
                ),
              ],
            ),
      body: gallery.selectedFolderPath == null
          ? _buildFolderSelection(theme)
          : _buildGalleryContent(gallery, theme),
      bottomNavigationBar: gallery.isSelectionMode
          ? _GallerySelectionBar(gallery: gallery)
          : null,
    );
  }

  Widget _buildFolderSelection(ThemeData theme) {
    const suggestions = [
      ('Android', '/storage/emulated/0/Android'),
      ('DCIM', '/storage/emulated/0/DCIM'),
      ('Pictures', '/storage/emulated/0/Pictures'),
      ('Download', '/storage/emulated/0/Download'),
      ('Movies', '/storage/emulated/0/Movies'),
      ('Music', '/storage/emulated/0/Music'),
      ('Documents', '/storage/emulated/0/Documents'),
      ('WhatsApp', '/storage/emulated/0/WhatsApp'),
    ];

    return ListView(
      padding: AppSpacing.pagePadding,
      children: [
        const SizedBox(height: AppSpacing.md),
        Center(
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: HugeIcon(
              icon: HugeIcons.strokeRoundedImage01,
              size: 56,
              color: theme.colorScheme.primary,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          'Media Gallery',
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Select a directory to index and explore all media files, including sub-folders.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: theme.colorScheme.onPrimary,
            minimumSize: const Size(double.infinity, 48),
            shape: RoundedRectangleBorder(borderRadius: AppRadius.borderMd),
          ),
          onPressed: () => _openFolderPicker(context),
          icon: const HugeIcon(
            icon: HugeIcons.strokeRoundedFolderOpen,
            color: Colors.white,
          ),
          label: const Text('Choose Directory'),
        ),
        const SizedBox(height: AppSpacing.xl),
        Text(
          'Suggested Folders',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        ...suggestions.map((s) {
          final (name, path) = s;
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: AppCard(
              onTap: () {
                ref.read(galleryProvider.notifier).selectFolder(path, name);
              },
              child: Row(
                children: [
                  const HugeIcon(
                    icon: HugeIcons.strokeRoundedFolder01,
                    color: Colors.amber,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          path,
                          style: theme.textTheme.bodySmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const HugeIcon(
                    icon: HugeIcons.strokeRoundedArrowRight01,
                    size: 18,
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  void _openFolderPicker(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const FolderPickerScreen()));
  }

  Widget _buildGalleryContent(GalleryState gallery, ThemeData theme) {
    if (gallery.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (gallery.error != null) {
      return Center(
        child: Padding(
          padding: AppSpacing.pagePadding,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const HugeIcon(
                icon: HugeIcons.strokeRoundedAlertCircle,
                size: 64,
                color: AppColors.error,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(gallery.error!, textAlign: TextAlign.center),
              const SizedBox(height: AppSpacing.md),
              ElevatedButton(
                onPressed: () => ref.read(galleryProvider.notifier).refresh(),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final files = gallery.filteredFiles;

    return Column(
      children: [
        _buildFilterBar(gallery, files, theme),
        const Divider(height: 1),
        Expanded(
          child: files.isEmpty
              ? _buildEmptyState(theme)
              : Scrollbar(
                  controller: _scrollController,
                  thumbVisibility: true,
                  child: gallery.viewMode == GalleryViewMode.grid
                      ? _buildGridView(gallery, files)
                      : _buildListView(gallery, files),
                ),
        ),
      ],
    );
  }

  Widget _buildFilterBar(
    GalleryState gallery,
    List<FileItem> files,
    ThemeData theme,
  ) {
    final filters = [
      (GalleryFilter.all, HugeIcons.strokeRoundedGrid, 'All'),
      (GalleryFilter.images, HugeIcons.strokeRoundedImage01, 'Images'),
      (GalleryFilter.videos, HugeIcons.strokeRoundedVideo01, 'Videos'),
      (GalleryFilter.audio, HugeIcons.strokeRoundedMusicNote01, 'Audio'),
      (GalleryFilter.documents, HugeIcons.strokeRoundedPdf01, 'Docs'),
      (GalleryFilter.text, HugeIcons.strokeRoundedFile01, 'Text'),
      (GalleryFilter.other, HugeIcons.strokeRoundedFolder01, 'Other'),
    ];

    return Container(
      color: theme.colorScheme.surfaceContainerLow,
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Column(
        children: [
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              itemCount: filters.length,
              separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.xs),
              itemBuilder: (context, index) {
                final (filter, icon, label) = filters[index];
                final isSelected = gallery.filter == filter;
                return ChoiceChip(
                  selected: isSelected,
                  onSelected: (_) =>
                      ref.read(galleryProvider.notifier).setFilter(filter),
                  avatar: HugeIcon(
                    icon: icon,
                    size: 14,
                    color: isSelected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurface,
                  ),
                  label: Text(label),
                  showCheckmark: false,
                );
              },
            ),
          ),
          Row(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Text(
                  '${files.length} file${files.length == 1 ? '' : 's'}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Spacer(),
              PopupMenuButton<GallerySort>(
                icon: const HugeIcon(icon: HugeIcons.strokeRoundedSorting01),
                tooltip: 'Sort',
                onSelected: (sort) =>
                    ref.read(galleryProvider.notifier).setSort(sort),
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: GallerySort.nameAsc,
                    child: Text('Name (A-Z)'),
                  ),
                  const PopupMenuItem(
                    value: GallerySort.nameDesc,
                    child: Text('Name (Z-A)'),
                  ),
                  const PopupMenuItem(
                    value: GallerySort.sizeAsc,
                    child: Text('Size (Smallest first)'),
                  ),
                  const PopupMenuItem(
                    value: GallerySort.sizeDesc,
                    child: Text('Size (Largest first)'),
                  ),
                  const PopupMenuItem(
                    value: GallerySort.dateAsc,
                    child: Text('Date (Oldest first)'),
                  ),
                  const PopupMenuItem(
                    value: GallerySort.dateDesc,
                    child: Text('Date (Newest first)'),
                  ),
                ],
              ),
              IconButton(
                icon: HugeIcon(
                  icon: gallery.viewMode == GalleryViewMode.grid
                      ? HugeIcons.strokeRoundedMenu01
                      : HugeIcons.strokeRoundedGrid,
                ),
                tooltip: gallery.viewMode == GalleryViewMode.grid
                    ? 'List View'
                    : 'Grid View',
                onPressed: () {
                  ref
                      .read(galleryProvider.notifier)
                      .setViewMode(
                        gallery.viewMode == GalleryViewMode.grid
                            ? GalleryViewMode.list
                            : GalleryViewMode.grid,
                      );
                },
              ),
              IconButton(
                icon: const HugeIcon(icon: HugeIcons.strokeRoundedCheckList),
                tooltip: 'Select files',
                onPressed: files.isEmpty
                    ? null
                    : () => ref
                          .read(galleryProvider.notifier)
                          .toggleSelection(files.first),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          HugeIcon(
            icon: HugeIcons.strokeRoundedFolderOpen,
            size: 64,
            color: theme.colorScheme.outline,
          ),
          const SizedBox(height: AppSpacing.md),
          Text('No files found', style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Try selecting another filter or directory.',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _buildGridView(GalleryState gallery, List<FileItem> files) {
    return GridView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(AppSpacing.sm),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 160,
        mainAxisSpacing: AppSpacing.sm,
        crossAxisSpacing: AppSpacing.sm,
        childAspectRatio: 0.85,
      ),
      itemCount: files.length,
      itemBuilder: (context, index) {
        final item = files[index];
        return _GalleryGridTile(
          item: item,
          allFiles: files,
          isSelected: gallery.selectedPaths.contains(item.path),
          isSelectionMode: gallery.isSelectionMode,
        );
      },
    );
  }

  Widget _buildListView(GalleryState gallery, List<FileItem> files) {
    return ListView.builder(
      controller: _scrollController,
      itemCount: files.length,
      itemBuilder: (context, index) {
        final item = files[index];
        return _GalleryListTile(
          item: item,
          allFiles: files,
          isSelected: gallery.selectedPaths.contains(item.path),
          isSelectionMode: gallery.isSelectionMode,
        );
      },
    );
  }
}

class _GalleryGridTile extends ConsumerWidget {
  final FileItem item;
  final List<FileItem> allFiles;
  final bool isSelected;
  final bool isSelectionMode;

  const _GalleryGridTile({
    required this.item,
    required this.allFiles,
    required this.isSelected,
    required this.isSelectionMode,
  });

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  void _openFile(BuildContext context, WidgetRef ref, FileItem item) {
    if (item.isImage || item.isVideo) {
      final media = allFiles.where((f) => f.isImage || f.isVideo).toList();
      context.push('/preview/media', extra: {'item': item, 'allFiles': media});
    } else if (item.isAudio) {
      context.push(
        '/preview/audio',
        extra: {'item': item, 'allFiles': allFiles},
      );
    } else if (item.isPdf) {
      context.push('/preview/pdf', extra: item);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot preview this file type.')),
      );
    }
  }

  void _showFileMenu(BuildContext context, WidgetRef ref, FileItem item) {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const HugeIcon(
                icon: HugeIcons.strokeRoundedCheckmarkCircle02,
                color: AppColors.primary,
              ),
              title: const Text('Select'),
              onTap: () {
                Navigator.of(ctx).pop();
                ref.read(galleryProvider.notifier).toggleSelection(item);
              },
            ),
            ListTile(
              leading: const HugeIcon(
                icon: HugeIcons.strokeRoundedInformationCircle,
                color: Colors.purple,
              ),
              title: const Text('File Info'),
              onTap: () {
                Navigator.of(ctx).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => FileInfoScreen(item: item)),
                );
              },
            ),
            ListTile(
              leading: const HugeIcon(
                icon: HugeIcons.strokeRoundedDelete02,
                color: AppColors.error,
              ),
              title: const Text(
                'Delete',
                style: TextStyle(color: AppColors.error),
              ),
              onTap: () {
                Navigator.of(ctx).pop();
                _confirmSingleDelete(context, ref, item);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmSingleDelete(
    BuildContext context,
    WidgetRef ref,
    FileItem item,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete file?'),
        content: Text('Delete "${item.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final storageService = ref.read(storageServiceProvider);
      final success = await storageService.deleteFiles([item.path]);
      ref.read(galleryProvider.notifier).removeFiles([item.path]);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(success ? 'File deleted.' : 'Delete failed.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: () {
        if (isSelectionMode) {
          ref.read(galleryProvider.notifier).toggleSelection(item);
        } else {
          _openFile(context, ref, item);
        }
      },
      onLongPress: () {
        if (isSelectionMode) {
          ref.read(galleryProvider.notifier).toggleSelection(item);
        } else {
          _showFileMenu(context, ref, item);
        }
      },
      borderRadius: AppRadius.borderMd,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: AppRadius.borderMd,
          border: isSelected
              ? Border.all(color: theme.colorScheme.primary, width: 2)
              : Border.all(color: theme.colorScheme.outline, width: 1),
          color: isSelected
              ? theme.colorScheme.primary.withValues(alpha: 0.12)
              : theme.cardTheme.color,
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ThumbnailImage(
                    item: item,
                    width: double.infinity,
                    height: double.infinity,
                    borderRadius: 0,
                  ),
                  if (isSelected)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check,
                          size: 14,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.xs + 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    _formatSize(item.size),
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GalleryListTile extends ConsumerWidget {
  final FileItem item;
  final List<FileItem> allFiles;
  final bool isSelected;
  final bool isSelectionMode;

  const _GalleryListTile({
    required this.item,
    required this.allFiles,
    required this.isSelected,
    required this.isSelectionMode,
  });

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  void _openFile(BuildContext context, WidgetRef ref, FileItem item) {
    if (item.isImage || item.isVideo) {
      final media = allFiles.where((f) => f.isImage || f.isVideo).toList();
      context.push('/preview/media', extra: {'item': item, 'allFiles': media});
    } else if (item.isAudio) {
      context.push(
        '/preview/audio',
        extra: {'item': item, 'allFiles': allFiles},
      );
    } else if (item.isPdf) {
      context.push('/preview/pdf', extra: item);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot preview this file type.')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      selected: isSelected,
      leading: isSelectionMode
          ? Checkbox(
              value: isSelected,
              onChanged: (_) =>
                  ref.read(galleryProvider.notifier).toggleSelection(item),
            )
          : ThumbnailImage(
              item: item,
              width: 44,
              height: 44,
              borderRadius: AppRadius.sm,
            ),
      title: Text(
        item.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        '${item.mimeType ?? 'Unknown'}  •  ${_formatSize(item.size)}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      onTap: () {
        if (isSelectionMode) {
          ref.read(galleryProvider.notifier).toggleSelection(item);
        } else {
          _openFile(context, ref, item);
        }
      },
    );
  }
}

class _GallerySelectionBar extends ConsumerWidget {
  final GalleryState gallery;

  const _GallerySelectionBar({required this.gallery});

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    Set<String> selected,
  ) async {
    final selectedFiles = gallery.files
        .where((f) => selected.contains(f.path))
        .toList();
    final totalSize = selectedFiles.fold<int>(0, (sum, f) => sum + f.size);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete files?'),
        content: Text(
          'Delete ${selected.length} file${selected.length == 1 ? '' : 's'}?\n\n'
          '${_formatSize(totalSize)} will be permanently removed from this device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final storageService = ref.read(storageServiceProvider);
      final success = await storageService.deleteFiles(selected.toList());
      ref.read(galleryProvider.notifier).removeFiles(selected.toList());
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success ? 'Files deleted.' : 'Some files could not be deleted.',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = gallery.selectedPaths;
    final theme = Theme.of(context);

    final selectedFiles = gallery.files
        .where((f) => selected.contains(f.path))
        .toList();
    final totalSize = selectedFiles.fold<int>(0, (sum, f) => sum + f.size);

    return Container(
      margin: const EdgeInsets.all(AppSpacing.lg),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: AppRadius.borderPill,
        border: Border.all(color: theme.colorScheme.outline, width: 1),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${selected.length} selected',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(_formatSize(totalSize), style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          IconButton(
            icon: const HugeIcon(
              icon: HugeIcons.strokeRoundedCheckList,
              color: AppColors.primary,
            ),
            tooltip: 'Select all',
            onPressed: () => ref.read(galleryProvider.notifier).selectAll(),
          ),
          IconButton(
            icon: const HugeIcon(
              icon: HugeIcons.strokeRoundedDelete02,
              color: AppColors.error,
            ),
            tooltip: 'Delete',
            onPressed: selected.isEmpty
                ? null
                : () => _confirmDelete(context, ref, selected),
          ),
          IconButton(
            icon: HugeIcon(
              icon: HugeIcons.strokeRoundedCancel01,
              color: theme.colorScheme.onSurface,
            ),
            tooltip: 'Cancel selection',
            onPressed: () =>
                ref.read(galleryProvider.notifier).clearSelection(),
          ),
        ],
      ),
    );
  }
}
