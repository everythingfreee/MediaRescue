import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/gallery_provider.dart';
import '../../providers/storage_provider.dart';
import '../../models/file_item.dart';

/// Screen for selecting a folder to scan in the Gallery.
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
    _currentPath = null; // null = root
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
            TextButton(
              onPressed: _selectFolder,
              child: const Text('Select'),
            ),
        ],
      ),
      body: Column(
        children: [
          // Current path breadcrumb
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: theme.colorScheme.surfaceContainerHighest,
            child: Row(
              children: [
                const Icon(Icons.folder, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _currentPath ?? 'Internal Storage',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontFamily: 'monospace',
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
    // Only show folders for selection
    final folders = _items.where((f) => f.isDirectory).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    return ListView.builder(
      itemCount: folders.length,
      itemBuilder: (context, index) {
        final folder = folders[index];
        return ListTile(
          leading: const Icon(Icons.folder, color: Colors.amber),
          title: Text(folder.name),
          subtitle: Text(folder.path),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _navigateInto(folder),
        );
      },
    );
  }
}