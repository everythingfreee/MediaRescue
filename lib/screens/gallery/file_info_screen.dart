import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/file_item.dart';
import '../../providers/gallery_provider.dart';
import '../../providers/storage_provider.dart';

/// Shows detailed information about a file and allows rename/delete.
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
          // Refresh the gallery to reflect the rename
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
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
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
            icon: const Icon(Icons.drive_file_rename_outline),
            tooltip: 'Rename',
            onPressed: _renameFile,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Delete',
            color: Colors.red,
            onPressed: _deleteFile,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // File icon / preview
          Center(
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(16),
              ),
              clipBehavior: Clip.antiAlias,
              child: _item.isImage || _item.isVideo
                  ? Image.network(
                      'file://${_item.path}',
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Icon(
                        _item.isVideo ? Icons.video_file : Icons.image,
                        size: 48,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    )
                  : Icon(
                      _getFileIcon(),
                      size: 48,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              _item.name,
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 24),
          _InfoRow(label: 'Type', value: _getFileTypeLabel(_item)),
          _InfoRow(label: 'Size', value: _formatSize(_item.size)),
          _InfoRow(label: 'Extension', value: _item.extension.isEmpty ? '—' : '.${_item.extension}'),
          _InfoRow(label: 'MIME Type', value: _item.mimeType ?? 'Unknown'),
          _InfoRow(label: 'Modified', value: _formatDate(_item.modifiedDate)),
          _InfoRow(label: 'Path', value: _item.path),
        ],
      ),
    );
  }

  IconData _getFileIcon() {
    if (_item.isImage) return Icons.image;
    if (_item.isVideo) return Icons.video_file;
    if (_item.isAudio) return Icons.audiotrack;
    if (_item.isPdf) return Icons.picture_as_pdf;
    if (_item.isDocument) return Icons.description;
    if (_item.isText) return Icons.article;
    if (_item.isArchive) return Icons.folder_zip;
    return Icons.insert_drive_file;
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
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}