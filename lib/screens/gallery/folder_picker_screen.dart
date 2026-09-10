import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../app/theme/app_radius.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_typography.dart';
import '../../models/file_item.dart';
import '../../providers/gallery_provider.dart';
import '../../providers/storage_provider.dart';

class FolderPickerScreen extends ConsumerStatefulWidget {
  const FolderPickerScreen({super.key});

  @override
  ConsumerState<FolderPickerScreen> createState() => _FolderPickerScreenState();
}

class _FolderPickerScreenState extends ConsumerState<FolderPickerScreen> {
  String? _currentPath;
  bool _isLoading = false;
  List<FileItem> _items = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _currentPath = null;
    _loadDirectory();
  }

  Future<void> _loadDirectory() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    final storageService = ref.read(storageServiceProvider);
    final items = await storageService.listDirectory(_currentPath);
    if (!mounted) return;
    setState(() {
      _items = items;
      _isLoading = false;
    });
  }

  void _navigateInto(FileItem folder) {
    setState(() {
      _currentPath = folder.path;
    });
    _loadDirectory();
  }

  void _selectFolder() {
    final path = _currentPath;
    if (path == null) return;
    final name = path.split('/').last;
    ref.read(galleryProvider.notifier).selectFolder(path, name);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Folder'),
        actions: [
          if (_currentPath != null)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: FilledButton.icon(
                onPressed: _selectFolder,
                icon: const HugeIcon(
                  icon: HugeIcons.strokeRoundedCheckmarkBadge01,
                  color: Colors.white,
                  size: 18,
                ),
                label: const Text('Select'),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            color: theme.colorScheme.surfaceContainerLow,
            child: Row(
              children: [
                HugeIcon(
                  icon: HugeIcons.strokeRoundedFolder01,
                  color: theme.colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    _currentPath ?? '/storage/emulated/0',
                    style: AppTypography.codeMono.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? Center(child: Text(_error!))
                : _items.isEmpty
                ? const Center(child: Text('This folder is empty'))
                : _buildFolderList(),
          ),
        ],
      ),
    );
  }

  Widget _buildFolderList() {
    final folders = _items.where((f) => f.isDirectory).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: folders.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.xs),
      itemBuilder: (context, index) {
        final folder = folders[index];
        return ListTile(
          shape: RoundedRectangleBorder(borderRadius: AppRadius.borderMd),
          leading: const HugeIcon(
            icon: HugeIcons.strokeRoundedFolder01,
            color: Colors.amber,
          ),
          title: Text(
            folder.name,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            folder.path,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: const HugeIcon(
            icon: HugeIcons.strokeRoundedArrowRight01,
            size: 18,
          ),
          onTap: () => _navigateInto(folder),
        );
      },
    );
  }
}
