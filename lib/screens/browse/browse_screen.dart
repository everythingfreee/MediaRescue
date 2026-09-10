import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_radius.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_typography.dart';
import '../../models/file_item.dart';
import '../../providers/browser_provider.dart';
import '../../providers/selection_provider.dart';
import '../../widgets/selection_bottom_bar.dart';
import '../../widgets/thumbnail_image.dart';

class BrowseScreen extends ConsumerStatefulWidget {
  const BrowseScreen({super.key});

  @override
  ConsumerState<BrowseScreen> createState() => _BrowseScreenState();
}

class _BrowseScreenState extends ConsumerState<BrowseScreen> {
  @override
  void dispose() {
    ref.read(selectionProvider.notifier).clear();
    super.dispose();
  }

  bool _handleBack() {
    final selection = ref.read(selectionProvider);
    final path = ref.read(currentPathProvider);

    if (selection.isNotEmpty) {
      ref.read(selectionProvider.notifier).clear();
      return true;
    }

    if (path.isNotEmpty) {
      ref.read(currentPathProvider.notifier).goBack();
      return true;
    }

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
          if (context.canPop()) {
            context.pop();
          }
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: currentPath.isNotEmpty
              ? IconButton(
                  icon: const HugeIcon(icon: HugeIcons.strokeRoundedArrowLeft01),
                  onPressed: () {
                    ref.read(currentPathProvider.notifier).goBack();
                  },
                )
              : null,
          title: Text(isSelectionMode ? 'Select Files' : 'Browse Storage'),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(48),
            child: _buildBreadcrumbs(currentPath),
          ),
          actions: [
            if (!isSelectionMode)
              directoryAsync.when(
                data: (files) => IconButton(
                  icon: const HugeIcon(icon: HugeIcons.strokeRoundedCheckList, color: AppColors.primary),
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
              padding: AppSpacing.pagePadding,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const HugeIcon(icon: HugeIcons.strokeRoundedFolderOff, size: 64, color: AppColors.error),
                  const SizedBox(height: AppSpacing.md),
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
    final theme = Theme.of(context);
    return Container(
      height: 48,
      alignment: Alignment.centerLeft,
      color: theme.colorScheme.surfaceContainerLow,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        itemCount: path.length + 1,
        separatorBuilder: (context, index) =>
            const HugeIcon(icon: HugeIcons.strokeRoundedArrowRight01, size: 14),
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
                color: isLast ? theme.colorScheme.primary : theme.colorScheme.onSurface,
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
            HugeIcon(icon: HugeIcons.strokeRoundedFolderOpen, size: 64, color: AppColors.other),
            SizedBox(height: AppSpacing.md),
            Text('This directory is empty'),
          ],
        ),
      );
    }

    final sortedFiles = List<FileItem>.from(files)
      ..sort((a, b) {
        if (a.isDirectory && !b.isDirectory) return -1;
        if (!a.isDirectory && b.isDirectory) return 1;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      itemCount: sortedFiles.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
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
    if (item.isDirectory) {
      ref.read(currentPathProvider.notifier).navigateTo(item.name);
    } else if (item.isImage || item.isVideo) {
      final media = allFiles.where((f) => f.isImage || f.isVideo).toList();
      context.push('/preview/media', extra: {'item': item, 'allFiles': media});
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selection = ref.watch(selectionProvider);
    final isSelected = selection.contains(item.path);
    final isSelectionMode = ref.watch(isSelectionModeProvider);

    return ListTile(
      selected: isSelected,
      leading: isSelectionMode && !item.isDirectory
          ? Checkbox(
              value: isSelected,
              onChanged: (_) => ref.read(selectionProvider.notifier).toggle(item),
            )
          : ThumbnailImage(item: item, width: 44, height: 44, borderRadius: AppRadius.sm),
      title: Text(
        item.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: item.isDirectory
          ? const Text('Directory')
          : Text(_formatSize(item.size), style: AppTypography.codeMono),
      trailing: item.isDirectory
          ? const HugeIcon(icon: HugeIcons.strokeRoundedArrowRight01, size: 18)
          : null,
      onTap: () {
        if (isSelectionMode && !item.isDirectory) {
          ref.read(selectionProvider.notifier).toggle(item);
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