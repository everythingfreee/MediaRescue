import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import '../app/theme/app_colors.dart';
import '../app/theme/app_radius.dart';
import '../app/theme/app_spacing.dart';
import '../models/file_item.dart';
import '../providers/browser_provider.dart';
import '../providers/selection_provider.dart';
import '../providers/storage_provider.dart';

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
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
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

    return Container(
      margin: const EdgeInsets.all(AppSpacing.lg),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: AppRadius.borderPill,
        border: Border.all(color: theme.colorScheme.outline, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.xs + 2),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha:0.15),
              shape: BoxShape.circle,
            ),
            child: Text(
              '${selected.length}',
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${selected.length} items selected',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
                Text(
                  _formatSize(totalSize),
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const HugeIcon(icon: HugeIcons.strokeRoundedCheckList, color: AppColors.primary),
            tooltip: 'Select all',
            onPressed: () =>
                ref.read(selectionProvider.notifier).selectAll(allFiles),
          ),
          IconButton(
            icon: const HugeIcon(icon: HugeIcons.strokeRoundedDelete02, color: AppColors.error),
            tooltip: 'Delete',
            onPressed: selected.isEmpty
                ? null
                : () => _confirmDelete(context, ref, selected),
          ),
          IconButton(
            icon: HugeIcon(icon: HugeIcons.strokeRoundedCancel01, color: theme.colorScheme.onSurface),
            tooltip: 'Cancel selection',
            onPressed: () => ref.read(selectionProvider.notifier).clear(),
          ),
        ],
      ),
    );
  }
}