import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/file_item.dart';
import '../../providers/gallery_provider.dart';
import '../../providers/storage_provider.dart';
import '../../services/storage_service.dart';
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

    // Clear the search text field when the folder changes
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
                  hintText: 'Search files...',
                  border: InputBorder.none,
                  suffixIcon: Icon(Icons.search),
                ),
                onChanged: (value) =>
                    ref.read(galleryProvider.notifier).setSearchQuery(value),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Rescan folder',
                  onPressed: () =>
                      ref.read(galleryProvider.notifier).refresh(),
                ),
                IconButton(
                  icon: const Icon(Icons.folder_open),
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
    // Common media folders users often want to scan.
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
      padding: const EdgeInsets.all(16),
      children: [
        Icon(
          Icons.photo_library_outlined,
          size: 80,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(height: 16),
        Text(
          'Gallery',
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'Select a folder to scan and view all files inside it, '
          'including sub-folders.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: () => _openFolderPicker(context),
          icon: const Icon(Icons.folder_open),
          label: const Text('Choose Folder'),
        ),
        const SizedBox(height: 24),
        Text(
          'Suggested folders',
          style: theme.textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        ...suggestions.map((s) {
          final (name, path) = s;
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: const Icon(Icons.folder, color: Colors.amber),
              title: Text(name),
              subtitle: Text(path, maxLines: 1, overflow: TextOverflow.ellipsis),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                ref.read(galleryProvider.notifier).selectFolder(path, name);
              },
            ),
          );
        }),
      ],
    );
  }

  void _openFolderPicker(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const FolderPickerScreen()),
    );
  }

  Widget _buildGalleryContent(GalleryState gallery, ThemeData theme) {
    if (gallery.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (gallery.error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(gallery.error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () =>
                    ref.read(galleryProvider.notifier).refresh(),
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
      GalleryState gallery, List<FileItem> files, ThemeData theme) {
    final filters = [
      (GalleryFilter.all, Icons.all_inclusive, 'All'),
      (GalleryFilter.images, Icons.image, 'Images'),
      (GalleryFilter.videos, Icons.video_file, 'Videos'),
      (GalleryFilter.audio, Icons.audiotrack, 'Audio'),
      (GalleryFilter.documents, Icons.picture_as_pdf, 'Docs'),
      (GalleryFilter.text, Icons.description, 'Text'),
      (GalleryFilter.other, Icons.help_outline, 'Other'),
    ];

    return Container(
      color: theme.colorScheme.surfaceContainerLow,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        children: [
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: filters.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final (filter, icon, label) = filters[index];
                final isSelected = gallery.filter == filter;
                return ChoiceChip(
                  selected: isSelected,
                  onSelected: (_) =>
                      ref.read(galleryProvider.notifier).setFilter(filter),
                  avatar: Icon(icon, size: 16),
                  label: Text(label),
                  showCheckmark: false,
                );
              },
            ),
          ),
          Row(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  '${files.length} file${files.length == 1 ? '' : 's'}',
                  style: theme.textTheme.bodySmall,
                ),
              ),
              const Spacer(),
              // Sort button
              PopupMenuButton<GallerySort>(
                icon: const Icon(Icons.sort),
                tooltip: 'Sort',
                onSelected: (sort) =>
                    ref.read(galleryProvider.notifier).setSort(sort),
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: GallerySort.nameAsc,
                    child: ListTile(
                      leading: Icon(Icons.sort_by_alpha),
                      title: Text('Name (A-Z)'),
                      dense: true,
                    ),
                  ),
                  const PopupMenuItem(
                    value: GallerySort.nameDesc,
                    child: ListTile(
                      leading: Icon(Icons.sort_by_alpha),
                      title: Text('Name (Z-A)'),
                      dense: true,
                    ),
                  ),
                  const PopupMenuItem(
                    value: GallerySort.sizeAsc,
                    child: ListTile(
                      leading: Icon(Icons.data_usage),
                      title: Text('Size (Small first)'),
                      dense: true,
                    ),
                  ),
                  const PopupMenuItem(
                    value: GallerySort.sizeDesc,
                    child: ListTile(
                      leading: Icon(Icons.data_usage),
                      title: Text('Size (Large first)'),
                      dense: true,
                    ),
                  ),
                  const PopupMenuItem(
                    value: GallerySort.dateAsc,
                    child: ListTile(
                      leading: Icon(Icons.date_range),
                      title: Text('Date (Oldest first)'),
                      dense: true,
                    ),
                  ),
                  const PopupMenuItem(
                    value: GallerySort.dateDesc,
                    child: ListTile(
                      leading: Icon(Icons.date_range),
                      title: Text('Date (Newest first)'),
                      dense: true,
                    ),
                  ),
                  const PopupMenuItem(
                    value: GallerySort.typeAsc,
                    child: ListTile(
                      leading: Icon(Icons.category),
                      title: Text('Type (A-Z)'),
                      dense: true,
                    ),
                  ),
                  const PopupMenuItem(
                    value: GallerySort.typeDesc,
                    child: ListTile(
                      leading: Icon(Icons.category),
                      title: Text('Type (Z-A)'),
                      dense: true,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: Icon(
                  gallery.viewMode == GalleryViewMode.grid
                      ? Icons.view_list
                      : Icons.grid_view,
                ),
                tooltip: gallery.viewMode == GalleryViewMode.grid
                    ? 'Switch to list view'
                    : 'Switch to grid view',
                onPressed: () {
                  final notifier = ref.read(galleryProvider.notifier);
                  notifier.setViewMode(
                    gallery.viewMode == GalleryViewMode.grid
                        ? GalleryViewMode.list
                        : GalleryViewMode.grid,
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.checklist),
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
          Icon(
            Icons.folder_open,
            size: 64,
            color: theme.colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            'No files found',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            'Try a different filter or folder.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGridView(GalleryState gallery, List<FileItem> files) {
    return GridView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 160,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
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

// ── Grid Tile ─────────────────────────────────────────────────────────────────

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
    if (item.isImage) {
      context.push('/preview/image', extra: item);
    } else if (item.isVideo) {
      context.push('/preview/video', extra: {'item': item, 'allFiles': allFiles});
    } else if (item.isAudio) {
      context.push('/preview/audio', extra: {'item': item, 'allFiles': allFiles});
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
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.check_circle_outline),
              title: const Text('Select'),
              onTap: () {
                Navigator.of(ctx).pop();
                ref.read(galleryProvider.notifier).toggleSelection(item);
              },
            ),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('File Info'),
              onTap: () {
                Navigator.of(ctx).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => FileInfoScreen(item: item),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.drive_file_rename_outline),
              title: const Text('Rename'),
              onTap: () {
                Navigator.of(ctx).pop();
                _showRenameDialog(context, ref, item);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Delete', style: TextStyle(color: Colors.red)),
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

  Future<void> _showRenameDialog(
      BuildContext context, WidgetRef ref, FileItem item) async {
    final controller = TextEditingController(text: item.name);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename file'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'New name',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('Rename'),
          ),
        ],
      ),
    );

    if (newName != null && newName.isNotEmpty && context.mounted) {
      final storageService = ref.read(storageServiceProvider);
      final success = await storageService.renameFile(item.path, newName);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(success ? 'File renamed.' : 'Rename failed.'),
        ));
        if (success) {
          ref.read(galleryProvider.notifier).refresh();
        }
      }
    }
  }

  Future<void> _confirmSingleDelete(
      BuildContext context, WidgetRef ref, FileItem item) async {
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
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(success ? 'File deleted.' : 'Delete failed.'),
        ));
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
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: isSelected
              ? Border.all(color: theme.colorScheme.primary, width: 2)
              : null,
          color: isSelected
              ? theme.colorScheme.primaryContainer.withValues(alpha: 0.3)
              : theme.colorScheme.surfaceContainerHighest,
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
                      item: item, width: double.infinity, height: double.infinity),
                  if (isSelected)
                    Positioned(
                      top: 4,
                      right: 4,
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
              padding: const EdgeInsets.all(6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    _formatSize(item.size),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
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

// ── List Tile ─────────────────────────────────────────────────────────────────

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
    if (item.isImage) {
      context.push('/preview/image', extra: item);
    } else if (item.isVideo) {
      context.push('/preview/video', extra: {'item': item, 'allFiles': allFiles});
    } else if (item.isAudio) {
      context.push('/preview/audio', extra: {'item': item, 'allFiles': allFiles});
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
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.check_circle_outline),
              title: const Text('Select'),
              onTap: () {
                Navigator.of(ctx).pop();
                ref.read(galleryProvider.notifier).toggleSelection(item);
              },
            ),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('File Info'),
              onTap: () {
                Navigator.of(ctx).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => FileInfoScreen(item: item),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.drive_file_rename_outline),
              title: const Text('Rename'),
              onTap: () {
                Navigator.of(ctx).pop();
                _showRenameDialog(context, ref, item);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Delete', style: TextStyle(color: Colors.red)),
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

  Future<void> _showRenameDialog(
      BuildContext context, WidgetRef ref, FileItem item) async {
    final controller = TextEditingController(text: item.name);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename file'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'New name',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('Rename'),
          ),
        ],
      ),
    );

    if (newName != null && newName.isNotEmpty && context.mounted) {
      final storageService = ref.read(storageServiceProvider);
      final success = await storageService.renameFile(item.path, newName);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(success ? 'File renamed.' : 'Rename failed.'),
        ));
        if (success) {
          ref.read(galleryProvider.notifier).refresh();
        }
      }
    }
  }

  Future<void> _confirmSingleDelete(
      BuildContext context, WidgetRef ref, FileItem item) async {
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
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(success ? 'File deleted.' : 'Delete failed.'),
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return ListTile(
      selected: isSelected,
      selectedTileColor:
          theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
      leading: isSelectionMode
          ? Checkbox(
              value: isSelected,
              onChanged: (_) =>
                  ref.read(galleryProvider.notifier).toggleSelection(item),
            )
          : ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: ThumbnailImage(item: item, width: 44, height: 44),
            ),
      title: Text(
        item.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
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
      onLongPress: () {
        if (isSelectionMode) {
          ref.read(galleryProvider.notifier).toggleSelection(item);
        } else {
          _showFileMenu(context, ref, item);
        }
      },
    );
  }
}

// ── Selection Bottom Bar ──────────────────────────────────────────────────────

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
      BuildContext context, WidgetRef ref, Set<String> selected) async {
    final selectedFiles =
        gallery.files.where((f) => selected.contains(f.path)).toList();
    final totalSize =
        selectedFiles.fold<int>(0, (sum, f) => sum + f.size);

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
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(success
              ? 'Files deleted.'
              : 'Some files could not be deleted.'),
        ));
      }
    }
  }

  Future<void> _moveFiles(
      BuildContext context, WidgetRef ref, Set<String> selected) async {
    final storageService = ref.read(storageServiceProvider);
    final currentFolder = gallery.selectedFolderPath;

    // Show a dialog to pick a destination folder
    final destination = await showDialog<String>(
      context: context,
      builder: (ctx) => _MoveDialog(
        initialPath: currentFolder,
        storageService: storageService,
      ),
    );

    if (destination != null && context.mounted) {
      final success =
          await storageService.moveFiles(selected.toList(), destination);
      ref.read(galleryProvider.notifier).removeFiles(selected.toList());
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(success
              ? 'Files moved.'
              : 'Some files could not be moved.'),
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = gallery.selectedPaths;
    final theme = Theme.of(context);

    final selectedFiles =
        gallery.files.where((f) => selected.contains(f.path)).toList();
    final totalSize = selectedFiles.fold<int>(0, (sum, f) => sum + f.size);

    return BottomAppBar(
      color: theme.colorScheme.secondaryContainer,
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${selected.length} selected',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                Text(
                  _formatSize(totalSize),
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.select_all),
            tooltip: 'Select all',
            onPressed: () =>
                ref.read(galleryProvider.notifier).selectAll(),
          ),
          IconButton(
            icon: const Icon(Icons.drive_file_move_outline),
            tooltip: 'Move',
            onPressed: selected.isEmpty
                ? null
                : () => _moveFiles(context, ref, selected),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Delete',
            color: Colors.red,
            onPressed: selected.isEmpty
                ? null
                : () => _confirmDelete(context, ref, selected),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: 'Cancel selection',
            onPressed: () =>
                ref.read(galleryProvider.notifier).clearSelection(),
          ),
        ],
      ),
    );
  }
}

// ── Move Dialog ───────────────────────────────────────────────────────────────

class _MoveDialog extends StatefulWidget {
  final String? initialPath;
  final StorageService storageService;

  const _MoveDialog({
    required this.initialPath,
    required this.storageService,
  });

  @override
  State<_MoveDialog> createState() => _MoveDialogState();
}

class _MoveDialogState extends State<_MoveDialog> {
  String? _currentPath;
  List<FileItem> _folders = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _currentPath = widget.initialPath ?? '/storage/emulated/0';
    // Use post-frame callback to avoid setState during initState
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadFolders();
    });
  }

  Future<void> _loadFolders() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final items = await widget.storageService.listDirectory(_currentPath);
      if (!mounted) return;
      setState(() {
        _folders = items.where((f) => f.isDirectory).toList()
          ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load folders: $e';
        _isLoading = false;
      });
    }
  }

  void _navigateInto(FileItem folder) {
    _currentPath = folder.path;
    _loadFolders();
  }

  void _navigateBack() {
    if (_currentPath == null) return;
    final parent = _currentPath!.substring(0, _currentPath!.lastIndexOf('/'));
    _currentPath = parent.isEmpty ? '/storage/emulated/0' : parent;
    _loadFolders();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Move to folder'),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _currentPath ?? 'Internal Storage',
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.arrow_upward),
                  tooltip: 'Up',
                  onPressed: _currentPath == null ? null : _navigateBack,
                ),
              ],
            ),
            const Divider(height: 1),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.error_outline,
                                    color: Colors.red, size: 40),
                                const SizedBox(height: 8),
                                Text(_error!,
                                    textAlign: TextAlign.center),
                                const SizedBox(height: 8),
                                TextButton(
                                  onPressed: _loadFolders,
                                  child: const Text('Retry'),
                                ),
                              ],
                            ),
                          ),
                        )
                      : _folders.isEmpty
                          ? const Center(child: Text('No sub-folders'))
                          : ListView.builder(
                              itemCount: _folders.length,
                              itemBuilder: (context, index) {
                                final folder = _folders[index];
                                return ListTile(
                                  dense: true,
                                  leading: const Icon(Icons.folder,
                                      color: Colors.amber, size: 20),
                                  title: Text(folder.name),
                                  subtitle: Text(
                                    folder.path,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                  onTap: () => _navigateInto(folder),
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _currentPath == null
              ? null
              : () => Navigator.of(context).pop(_currentPath),
          child: const Text('Move Here'),
        ),
      ],
    );
  }
}