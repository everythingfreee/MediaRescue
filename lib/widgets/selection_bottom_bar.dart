import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/browser_provider.dart';
import '../../providers/selection_provider.dart';
import '../../providers/storage_provider.dart';
import '../../models/file_item.dart';

class SelectionBottomBar extends ConsumerWidget {
  final List<FileItem> allFiles;

  const SelectionBottomBar({super.key, required this.allFiles});

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
    final totalSize = allFiles
        .where((f) => selected.contains(f.path))
        .fold<int>(0, (sum, f) => sum + f.size);

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
      ref.read(selectionProvider.notifier).clear();
      ref.invalidate(currentDirectoryProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(success
              ? 'Files deleted.'
              : 'Some files could not be deleted.'),
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectionProvider);
    final theme = Theme.of(context);

    final totalSize = allFiles
        .where((f) => selected.contains(f.path))
        .fold<int>(0, (sum, f) => sum + f.size);

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
                ref.read(selectionProvider.notifier).selectAll(allFiles),
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
            onPressed: () => ref.read(selectionProvider.notifier).clear(),
          ),
        ],
      ),
    );
  }
}