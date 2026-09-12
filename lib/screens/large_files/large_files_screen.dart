import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_typography.dart';
import '../../models/file_item.dart';
import '../../providers/scanner_provider.dart';
import '../../providers/selection_provider.dart';
import '../../providers/storage_provider.dart';
import '../../widgets/file_actions_sheet.dart';

class LargeFilesScreen extends ConsumerWidget {
  const LargeFilesScreen({super.key});

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
    List<FileItem> files,
  ) async {
    final totalSize = files.fold<int>(0, (sum, f) => sum + f.size);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete selected files?'),
        content: Text(
          'Delete ${files.length} file${files.length == 1 ? '' : 's'}?\n\n'
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
      final paths = files.map((f) => f.path).toList();
      final success = await storageService.deleteFiles(paths);
      ref.read(scanControllerProvider.notifier).startScan();
      ref.read(selectionProvider.notifier).clear();
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

  void _openFile(
    BuildContext context,
    FileItem item,
    List<FileItem> largeFiles,
  ) {
    if (item.isImage) {
      context.push('/preview/image', extra: item);
    } else if (item.isVideo) {
      final videos = largeFiles.where((f) => f.isVideo).toList();
      context.push('/preview/video', extra: {'item': item, 'allFiles': videos});
    } else if (item.isAudio) {
      final audios = largeFiles.where((f) => f.isAudio).toList();
      context.push('/preview/audio', extra: {'item': item, 'allFiles': audios});
    } else if (item.isPdf) {
      context.push('/preview/pdf', extra: item);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot preview this file type yet.')),
      );
    }
  }

  void _goBack(BuildContext context) {
    if (context.canPop()) {
      Navigator.of(context).maybePop();
    } else {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final largeFiles = ref.watch(largeFilesProvider);
    final threshold = ref.watch(largeFilesThresholdProvider);
    final scanState = ref.watch(scanControllerProvider);
    final selected = ref.watch(selectionProvider);
    final isScanning = scanState.status == ScanStatus.scanning;

    final thresholds = {
      '10 MB': 10 * 1024 * 1024,
      '50 MB': 50 * 1024 * 1024,
      '100 MB': 100 * 1024 * 1024,
      '500 MB': 500 * 1024 * 1024,
      '1 GB': 1024 * 1024 * 1024,
    };

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const HugeIcon(icon: HugeIcons.strokeRoundedArrowLeft01),
          tooltip: 'Back',
          onPressed: () => _goBack(context),
        ),
        title: const Text('Large Files'),
        actions: [
          if (selected.isNotEmpty)
            IconButton(
              icon: const HugeIcon(icon: HugeIcons.strokeRoundedDelete02, color: AppColors.error),
              tooltip: 'Delete selected',
              onPressed: () {
                final toDelete = largeFiles
                    .where((f) => selected.contains(f.path))
                    .toList();
                _confirmDelete(context, ref, toDelete);
              },
            ),
          PopupMenuButton<int>(
            icon: const HugeIcon(icon: HugeIcons.strokeRoundedFilter),
            tooltip: 'Size threshold',
            onSelected: (val) {
              ref.read(largeFilesThresholdProvider.notifier).set(val);
            },
            itemBuilder: (ctx) => thresholds.entries.map((e) {
              return PopupMenuItem<int>(
                value: e.value,
                child: Row(
                  children: [
                    Icon(
                      e.value == threshold
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                      size: 18,
                      color: e.value == threshold
                          ? Theme.of(context).colorScheme.primary
                          : null,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text('>= ${e.key}'),
                  ],
                ),
              );
            }).toList(),
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
      body: isScanning
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: AppSpacing.md),
                  Text('Scanning storage for large files...'),
                ],
              ),
            )
          : largeFiles.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      HugeIcon(icon: HugeIcons.strokeRoundedHardDrive, size: 64, color: AppColors.other),
                      SizedBox(height: AppSpacing.md),
                      Text('No large files found'),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                  itemCount: largeFiles.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = largeFiles[index];
                    final isSelected = selected.contains(item.path);

                    return ListTile(
                      selected: isSelected,
                      leading: Checkbox(
                        value: isSelected,
                        onChanged: (_) {
                          ref.read(selectionProvider.notifier).toggle(item);
                        },
                      ),
                      title: Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(
                        '${_formatSize(item.size)}  •  ${item.parentDirectory}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.codeMono,
                      ),
                      trailing: IconButton(
                        icon: const HugeIcon(icon: HugeIcons.strokeRoundedMoreVertical, size: 18),
                        onPressed: () => showFileActionsSheet(
                          context,
                          ref,
                          item,
                          onOpen: () => _openFile(context, item, largeFiles),
                        ),
                      ),
                      onTap: () => _openFile(context, item, largeFiles),
                    );
                  },
                ),
    );
  }
}
