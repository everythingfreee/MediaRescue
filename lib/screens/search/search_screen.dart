import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_radius.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_typography.dart';
import '../../models/file_item.dart';
import '../../models/smart_filter.dart';
import '../../providers/filter_provider.dart';
import '../../providers/scanner_provider.dart';
import '../../widgets/file_actions_sheet.dart';
import '../../widgets/smart_filter_sheet.dart';
import '../../widgets/thumbnail_image.dart';

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
    _debounce = Timer(const Duration(milliseconds: 300), () {
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
    if (item.isImage || item.isVideo) {
      final media = results.where((f) => f.isImage || f.isVideo).toList();
      context.push('/preview/media', extra: {'item': item, 'allFiles': media});
    } else if (item.isAudio) {
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
          decoration: InputDecoration(
            hintText: 'Search indexed media by name...',
            border: InputBorder.none,
            prefixIcon: const HugeIcon(icon: HugeIcons.strokeRoundedSearch01, size: 20),
            suffixIcon: _controller.text.isNotEmpty
                ? IconButton(
                    icon: const HugeIcon(icon: HugeIcons.strokeRoundedCancel01, size: 18),
                    onPressed: () {
                      _controller.clear();
                      ref.read(searchQueryProvider.notifier).set('');
                    },
                  )
                : null,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Smart Filters',
            icon: Badge(
              isLabelVisible: filter.isActive,
              label: Text('${filter.activeGroupCount}'),
              child: HugeIcon(
                icon: HugeIcons.strokeRoundedFilter,
                color: filter.isActive ? AppColors.primary : Theme.of(context).colorScheme.onSurface,
              ),
            ),
            onPressed: () => showSmartFilterSheet(context),
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
            HugeIcon(icon: HugeIcons.strokeRoundedSearch01, size: 64, color: AppColors.other),
            SizedBox(height: AppSpacing.md),
            Text('Search files by filename or filter criteria'),
          ],
        ),
      );
    }
    if (results.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            HugeIcon(icon: HugeIcons.strokeRoundedSearch01, size: 64, color: AppColors.error),
            SizedBox(height: AppSpacing.md),
            Text('No files found matching search'),
          ],
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      itemCount: results.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final item = results[index];
        return ListTile(
          leading: ThumbnailImage(item: item, width: 44, height: 44, borderRadius: AppRadius.sm),
          title: Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text(
            '${_formatSize(item.size)}  •  ${item.mimeType ?? 'Unknown'}',
            style: AppTypography.codeMono,
          ),
          trailing: IconButton(
            icon: const HugeIcon(icon: HugeIcons.strokeRoundedMoreVertical, size: 18),
            tooltip: 'File actions',
            onPressed: () => showFileActionsSheet(
              context,
              ref,
              item,
              onOpen: () => _openFile(context, item, results),
            ),
          ),
          onTap: () => _openFile(context, item, results),
        );
      },
    );
  }
}

class _ActiveFilterBar extends ConsumerWidget {
  const _ActiveFilterBar({required this.filter});

  final SmartFilterState filter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(smartFilterProvider.notifier);
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
      color: theme.colorScheme.surfaceContainerLow,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            if (filter.types.isNotEmpty)
              ...filter.types.map(
                (type) => Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.xs),
                  child: InputChip(
                    label: Text(_typeChipLabel(type)),
                    onDeleted: () => notifier.toggleType(type),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ),
            if (filter.hasSizeFilter)
              Padding(
                padding: const EdgeInsets.only(right: AppSpacing.xs),
                child: InputChip(
                  label: Text(_sizeChipLabel(filter.sizeFilter)),
                  onDeleted: () =>
                      notifier.setSizeFilter(FileSizeFilter.any),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            if (filter.hasDateFilter)
              Padding(
                padding: const EdgeInsets.only(right: AppSpacing.xs),
                child: InputChip(
                  label: Text(_dateChipLabel(filter.dateFilter)),
                  onDeleted: () =>
                      notifier.setDateFilter(ModifiedDateFilter.any),
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