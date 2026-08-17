import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/scanner_provider.dart';
import '../../providers/selection_provider.dart';
import '../../providers/storage_provider.dart';
import '../../models/file_item.dart';
import '../../widgets/thumbnail_image.dart';

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
      BuildContext context, WidgetRef ref, List<FileItem> files) async {
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
              child: const Text('Cancel')),
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
      final paths = files.map((f) => f.path).toList();
      final success = await storageService.deleteFiles(paths);
      ref.read(scanControllerProvider.notifier).startScan();
      ref.read(selectionProvider.notifier).clear();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(success
                  ? 'Files deleted.'
                  : 'Some files could not be deleted.')),
        );
      }
    }
  }

  void _openFile(BuildContext context, FileItem item) {
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
        title: const Text('Large Files'),
        actions: [
          if (selected.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              tooltip: 'Delete selected',
              onPressed: () {
                final toDelete =
                    largeFiles.where((f) => selected.contains(f.path)).toList();
                _confirmDelete(context, ref, toDelete);
              },
            ),
          PopupMenuButton<int>(
            icon: const Icon(Icons.filter_list),
            tooltip: 'Size threshold',
            onSelected: (val) {
              ref.read(largeFilesThresholdProvider.notifier).set(val);
            },
            itemBuilder: (ctx) => thresholds.entries.map((e) {
              return PopupMenuItem<int>(
                value: e.value,
                child: Row(
                  children: [
                    if (threshold == e.value)
                      const Icon(Icons.check, size: 18)
                    else
                      const SizedBox(width: 18),
                    const SizedBox(width: 8),
                    Text('Larger than ${e.key}'),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
      body: isScanning
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Scanning for large files...'),
                ],
              ),
            )
          : _buildLargeFilesList(context, ref, largeFiles, selected),
    );
  }

  Widget _buildLargeFilesList(
      BuildContext context, WidgetRef ref, List<FileItem> largeFiles, Set<String> selected) {
    if (largeFiles.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_outline, size: 64, color: Colors.green),
            SizedBox(height: 16),
            Text('No large files found'),
          ],
        ),
      );
    }

    final totalSize = largeFiles.fold<int>(0, (s, f) => s + f.size);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Text('${largeFiles.length} files  •  ${_formatSize(totalSize)}',
                  style: Theme.of(context).textTheme.bodyMedium),
              const Spacer(),
              if (selected.isNotEmpty)
                TextButton(
                  onPressed: () => ref.read(selectionProvider.notifier).clear(),
                  child: const Text('Clear'),
                ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: largeFiles.length,
            itemBuilder: (context, index) {
              final item = largeFiles[index];
              final isSelected = selected.contains(item.path);

              return ListTile(
                selected: isSelected,
                selectedTileColor: Theme.of(context)
                    .colorScheme
                    .secondaryContainer
                    .withValues(alpha: 0.5),
                leading: selected.isNotEmpty
                    ? Checkbox(
                        value: isSelected,
                        onChanged: (_) =>
                            ref.read(selectionProvider.notifier).toggle(item),
                      )
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: ThumbnailImage(item: item, width: 44, height: 44),
                      ),
                title:
                    Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(item.mimeType ?? 'Unknown type'),
                trailing: Text(
                  _formatSize(item.size),
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.red),
                ),
                onTap: () {
                  if (selected.isNotEmpty) {
                    ref.read(selectionProvider.notifier).toggle(item);
                  } else {
                    _openFile(context, item);
                  }
                },
                onLongPress: () =>
                    ref.read(selectionProvider.notifier).toggle(item),
              );
            },
          ),
        ),
      ],
    );
  }
}