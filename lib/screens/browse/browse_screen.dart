import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/browser_provider.dart';
import '../../providers/selection_provider.dart';
import '../../models/file_item.dart';
import '../../widgets/thumbnail_image.dart';
import '../../widgets/selection_bottom_bar.dart';

class BrowseScreen extends ConsumerStatefulWidget {
  const BrowseScreen({super.key});

  @override
  ConsumerState<BrowseScreen> createState() => _BrowseScreenState();
}

class _BrowseScreenState extends ConsumerState<BrowseScreen> {
  @override
  void dispose() {
    // Clear selection when leaving
    ref.read(selectionProvider.notifier).clear();
    super.dispose();
  }

  /// Handles the Android system back button.
  /// Priority: close selection mode → navigate to parent → default behavior.
  bool _handleBack() {
    final selection = ref.read(selectionProvider);
    final path = ref.read(currentPathProvider);

    // 1. Exit selection mode if active
    if (selection.isNotEmpty) {
      ref.read(selectionProvider.notifier).clear();
      return true;
    }

    // 2. Navigate to parent directory if not at root
    if (path.isNotEmpty) {
      ref.read(currentPathProvider.notifier).goBack();
      return true;
    }

    // 3. At root — allow default back behavior (previous screen / exit)
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final currentPath = ref.watch(currentPathProvider);
    final directoryAsync = ref.watch(currentDirectoryProvider);
    final isSelectionMode = ref.watch(isSelectionModeProvider);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        final handled = _handleBack();
        if (!handled) {
          // Allow the app to navigate back / exit
          if (context.canPop()) {
            context.pop();
          }
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: currentPath.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () {
                    ref.read(currentPathProvider.notifier).goBack();
                  },
                )
              : null,
          title: isSelectionMode
              ? const Text('Select Files')
              : const Text('Browse Files'),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(48),
            child: _buildBreadcrumbs(currentPath),
          ),
          actions: [
            if (!isSelectionMode)
              directoryAsync.when(
                data: (files) => IconButton(
                  icon: const Icon(Icons.checklist),
                  tooltip: 'Select',
                  onPressed: files.isNotEmpty
                      ? () => ref
                          .read(selectionProvider.notifier)
                          .toggle(files.first)
                      : null,
                ),
                loading: () => const SizedBox.shrink(),
                error: (err, stack) => const SizedBox.shrink(),
              ),
          ],
        ),
        body: directoryAsync.when(
          data: (files) => _buildFileList(files),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.folder_off, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text('$err', textAlign: TextAlign.center),
                ],
              ),
            ),
          ),
        ),
        bottomNavigationBar: isSelectionMode
            ? directoryAsync.maybeWhen(
                data: (files) => SelectionBottomBar(allFiles: files),
                orElse: () => null,
              )
            : null,
      ),
    );
  }

  Widget _buildBreadcrumbs(List<String> path) {
    return Container(
      height: 48,
      alignment: Alignment.centerLeft,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: path.length + 1,
        separatorBuilder: (context, index) =>
            const Icon(Icons.chevron_right, size: 16),
        itemBuilder: (context, index) {
          final isRoot = index == 0;
          final name = isRoot ? 'Internal Storage' : path[index - 1];
          final isLast = index == path.length;

          return TextButton(
            onPressed: isLast
                ? null
                : () {
                    if (isRoot) {
                      ref.read(currentPathProvider.notifier).goToRoot();
                    } else {
                      // Pop back to the selected index
                      final notifier = ref.read(currentPathProvider.notifier);
                      final popsNeeded = path.length - index;
                      for (int i = 0; i < popsNeeded; i++) {
                        notifier.goBack();
                      }
                    }
                  },
            child: Text(
              name,
              style: TextStyle(
                fontWeight: isLast ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFileList(List<FileItem> files) {
    if (files.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.folder_open, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('This folder is empty'),
          ],
        ),
      );
    }

    // Sort: folders first, then by name
    final sortedFiles = List<FileItem>.from(files)
      ..sort((a, b) {
        if (a.isDirectory && !b.isDirectory) return -1;
        if (!a.isDirectory && b.isDirectory) return 1;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });

    return ListView.builder(
      itemCount: sortedFiles.length,
      itemBuilder: (context, index) {
        final item = sortedFiles[index];
        return _FileListTile(item: item, allFiles: sortedFiles);
      },
    );
  }
}

class _FileListTile extends ConsumerWidget {
  final FileItem item;
  final List<FileItem> allFiles;

  const _FileListTile({required this.item, required this.allFiles});

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
      context.go('/browse/image', extra: item);
    } else if (item.isVideo) {
      context.go('/browse/video', extra: item);
    } else if (item.isAudio) {
      context.go('/browse/audio', extra: item);
    } else if (item.isPdf) {
      context.go('/browse/pdf', extra: item);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot preview this file type yet.')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSelectionMode = ref.watch(isSelectionModeProvider);
    final isSelected = ref.watch(
      selectionProvider.select((set) => set.contains(item.path)),
    );

    return ListTile(
      selected: isSelected,
      selectedTileColor:
          Theme.of(context).colorScheme.secondaryContainer.withValues(alpha: 0.5),
      leading: isSelectionMode
          ? Checkbox(
              value: isSelected,
              onChanged: (_) =>
                  ref.read(selectionProvider.notifier).toggle(item),
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
        item.isDirectory
            ? 'Folder'
            : '${item.mimeType ?? 'Unknown type'}  •  ${_formatSize(item.size)}',
      ),
      trailing: item.isDirectory ? const Icon(Icons.chevron_right) : null,
      onTap: () {
        if (isSelectionMode && !item.isDirectory) {
          ref.read(selectionProvider.notifier).toggle(item);
        } else if (item.isDirectory) {
          ref.read(selectionProvider.notifier).clear();
          ref.read(currentPathProvider.notifier).navigateTo(item.name);
        } else {
          _openFile(context, ref, item);
        }
      },
      onLongPress: () {
        if (!item.isDirectory) {
          ref.read(selectionProvider.notifier).toggle(item);
        }
      },
    );
  }
}