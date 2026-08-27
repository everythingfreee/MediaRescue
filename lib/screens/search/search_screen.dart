import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/file_item.dart';
import '../../models/smart_filter.dart';
import '../../providers/filter_provider.dart';
import '../../providers/scanner_provider.dart';
import '../../widgets/thumbnail_image.dart';
import '../../widgets/smart_filter_sheet.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _controller.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      ref.read(searchQueryProvider.notifier).set(value);
    });
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  void _openFile(BuildContext context, dynamic item, List<dynamic> results) {
    if (item.isImage) {
      context.push('/preview/image', extra: item);
    } else if (item.isVideo) {
      // Pass the video files so next/previous works in the player.
      final videos = results.where((f) => f.isVideo).toList();
      context.push('/preview/video', extra: {'item': item, 'allFiles': videos});
    } else if (item.isAudio) {
      // Pass the audio files so next/previous works in the player.
      final audios = results.where((f) => f.isAudio).toList();
      context.push('/preview/audio', extra: {'item': item, 'allFiles': audios});
    } else if (item.isPdf) {
      context.push('/preview/pdf', extra: item);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot preview this file type yet.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final results = ref.watch(searchResultsProvider);
    final scanState = ref.watch(scanControllerProvider);
    final query = ref.watch(searchQueryProvider);
    final filter = ref.watch(smartFilterProvider);
    final isScanning = scanState.status == ScanStatus.scanning;

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          onChanged: _onQueryChanged,
          autofocus: false,
          decoration: const InputDecoration(
            hintText: 'Search files...',
            border: InputBorder.none,
            prefixIcon: Icon(Icons.search),
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Smart Filters',
            icon: Badge(
              isLabelVisible: filter.isActive,
              label: Text('${filter.activeGroupCount}'),
              child: Icon(filter.isActive
                  ? Icons.filter_alt
                  : Icons.filter_alt_outlined),
            ),
            onPressed: () => showSmartFilterSheet(context),
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
                  Text('Scanning storage...'),
                ],
              ),
            )
          : Column(
              children: [
                if (filter.isActive) _ActiveFilterBar(filter: filter),
                Expanded(child: _buildResults(results, query, filter)),
              ],
            ),
    );
  }

  Widget _buildResults(
      List<FileItem> results, String query, SmartFilterState filter) {
    final hasQuery = query.isNotEmpty;
    if (!hasQuery && !filter.isActive) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('Search for files by name'),
          ],
        ),
      );
    }
    if (results.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No files found'),
          ],
        ),
      );
    }
    return ListView.builder(
      itemCount: results.length,
      itemBuilder: (context, index) {
        final item = results[index];
        return ListTile(
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: ThumbnailImage(item: item, width: 44, height: 44),
          ),
          title: Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(
            '${_formatSize(item.size)}  •  ${item.mimeType ?? 'Unknown'}',
          ),
          onTap: () => _openFile(context, item, results),
        );
      },
    );
  }
}

/// Displays the currently active filters as removable chips above the results.
class _ActiveFilterBar extends ConsumerWidget {
  const _ActiveFilterBar({required this.filter});

  final SmartFilterState filter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(smartFilterProvider.notifier);
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        border: Border(
          bottom:
              BorderSide(color: theme.colorScheme.outlineVariant, width: 0.5),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            if (filter.types.isNotEmpty)
              ...filter.types.map(
                (type) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: InputChip(
                    label: Text(_typeChipLabel(type)),
                    onDeleted: () => notifier.toggleType(type),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ),
            if (filter.hasSizeFilter)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: InputChip(
                  label: Text(_sizeChipLabel(filter.sizeFilter)),
                  onDeleted: () =>
                      notifier.setSizeFilter(FileSizeFilter.any),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            if (filter.hasDateFilter)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: InputChip(
                  label: Text(_dateChipLabel(filter.dateFilter)),
                  onDeleted: () =>
                      notifier.setDateFilter(ModifiedDateFilter.any),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            if (filter.hasLocationFilter)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: InputChip(
                  label: Text(filter.internalStorage
                      ? 'Internal only'
                      : 'SD Card only'),
                  onDeleted: () {
                    // Reset both locations back to a "no restriction" state.
                    notifier.setInternalStorage(true);
                    notifier.setSdCard(true);
                  },
                  visualDensity: VisualDensity.compact,
                ),
              ),
            TextButton(
              onPressed: () => showSmartFilterSheet(context),
              child: Text('Edit filters (${filter.activeGroupCount})'),
            ),
          ],
        ),
      ),
    );
  }

  static String _typeChipLabel(SmartTypeFilter type) {
    switch (type) {
      case SmartTypeFilter.images:
        return 'Images';
      case SmartTypeFilter.videos:
        return 'Videos';
      case SmartTypeFilter.audio:
        return 'Audio';
      case SmartTypeFilter.documents:
        return 'Documents';
      case SmartTypeFilter.pdfs:
        return 'PDFs';
      case SmartTypeFilter.archives:
        return 'Archives';
      case SmartTypeFilter.hidden:
        return 'Hidden';
    }
  }

  static String _sizeChipLabel(FileSizeFilter size) {
    switch (size) {
      case FileSizeFilter.any:
        return 'Any size';
      case FileSizeFilter.above10mb:
        return '> 10 MB';
      case FileSizeFilter.above100mb:
        return '> 100 MB';
      case FileSizeFilter.above500mb:
        return '> 500 MB';
      case FileSizeFilter.above1gb:
        return '> 1 GB';
    }
  }

  static String _dateChipLabel(ModifiedDateFilter date) {
    switch (date) {
      case ModifiedDateFilter.any:
        return 'Any date';
      case ModifiedDateFilter.today:
        return 'Today';
      case ModifiedDateFilter.last7Days:
        return '7 days';
      case ModifiedDateFilter.last30Days:
        return '30 days';
      case ModifiedDateFilter.lastYear:
        return '1 year';
    }
  }
}