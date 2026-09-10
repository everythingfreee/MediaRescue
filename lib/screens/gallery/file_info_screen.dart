import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_radius.dart';
import '../../app/theme/app_spacing.dart';
import '../../models/file_item.dart';
import '../../providers/gallery_provider.dart';
import '../../providers/storage_provider.dart';
import '../../widgets/app_card.dart';
import '../../widgets/thumbnail_image.dart';

class FileInfoScreen extends ConsumerStatefulWidget {
  final FileItem item;

  const FileInfoScreen({super.key, required this.item});

  @override
  ConsumerState<FileInfoScreen> createState() => _FileInfoScreenState();
}

class _FileInfoScreenState extends ConsumerState<FileInfoScreen> {
  late FileItem _item;

  @override
  void initState() {
    super.initState();
    _item = widget.item;
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  String _formatDate(int milliseconds) {
    if (milliseconds <= 0) return 'Unknown';
    final date = DateTime.fromMillisecondsSinceEpoch(milliseconds);
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')} '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }

  String _getFileTypeLabel(FileItem item) {
    if (item.isImage) return 'Image';
    if (item.isVideo) return 'Video';
    if (item.isAudio) return 'Audio';
    if (item.isPdf) return 'PDF';
    if (item.isDocument) return 'Document';
    if (item.isText) return 'Text';
    if (item.isArchive) return 'Archive';
    if (item.isApk) return 'APK';
    return 'Other';
  }

  Future<void> _renameFile() async {
    final controller = TextEditingController(text: _item.name);
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

    if (newName != null && newName.isNotEmpty && mounted) {
      final storageService = ref.read(storageServiceProvider);
      final success = await storageService.renameFile(_item.path, newName);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(success ? 'File renamed.' : 'Rename failed.'),
        ));
        if (success) {
          ref.read(galleryProvider.notifier).refresh();
          Navigator.of(context).pop();
        }
      }
    }
  }

  Future<void> _deleteFile() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete file?'),
        content: Text(
          'Delete "${_item.name}"?\n\n'
          '${_formatSize(_item.size)} will be permanently removed.',
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

    if (confirmed == true && mounted) {
      final storageService = ref.read(storageServiceProvider);
      final success = await storageService.deleteFiles([_item.path]);
      ref.read(galleryProvider.notifier).removeFiles([_item.path]);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(success ? 'File deleted.' : 'Delete failed.'),
        ));
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('File Info'),
        actions: [
          IconButton(
            icon: const HugeIcon(icon: HugeIcons.strokeRoundedEdit02, color: AppColors.primary),
            tooltip: 'Rename',
            onPressed: _renameFile,
          ),
          IconButton(
            icon: const HugeIcon(icon: HugeIcons.strokeRoundedDelete02, color: AppColors.error),
            tooltip: 'Delete',
            onPressed: _deleteFile,
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
      body: ListView(
        padding: AppSpacing.pagePadding,
        children: [
          Center(
            child: ThumbnailImage(
              item: _item,
              width: 120,
              height: 120,
              borderRadius: AppRadius.lg,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Center(
            child: Text(
              _item.name,
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          AppCard(
            child: Column(
              children: [
                _InfoRow(label: 'Type', value: _getFileTypeLabel(_item)),
                const Divider(),
                _InfoRow(label: 'Size', value: _formatSize(_item.size)),
                const Divider(),
                _InfoRow(label: 'Extension', value: _item.extension.isEmpty ? '—' : '.${_item.extension}'),
                const Divider(),
                _InfoRow(label: 'MIME Type', value: _item.mimeType ?? 'Unknown'),
                const Divider(),
                _InfoRow(label: 'Modified', value: _formatDate(_item.modifiedDate)),
                const Divider(),
                _InfoRow(label: 'Path', value: _item.path),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}