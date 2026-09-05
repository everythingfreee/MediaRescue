import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/file_item.dart';
import '../../models/hidden_media.dart';
import '../../providers/gallery_provider.dart';
import '../../providers/hidden_media_provider.dart';
import '../../providers/scanner_provider.dart';
import '../../widgets/file_actions_sheet.dart';
import '../../widgets/smart_filter_sheet.dart';
import '../../widgets/thumbnail_image.dart';

String _formatSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
}

/// Dedicated Hidden / Unusual Media screen.
///
/// Shows every file classified as hidden by the combined-evidence model and
/// explains exactly WHY each item was classified (only true signals).
/// Supports a name search, Smart Filters (scoped to this screen) and a
/// List / Large Icons view toggle.
class HiddenMediaScreen extends ConsumerStatefulWidget {
  const HiddenMediaScreen({super.key});

  @override
  ConsumerState<HiddenMediaScreen> createState() => _HiddenMediaScreenState();
}

class _HiddenMediaScreenState extends ConsumerState<HiddenMediaScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    // Start every visit with a clean search query (Smart Filters persist on
    // purpose so a returning visitor keeps their narrowed view).
    if (ref.read(hiddenMediaQueryProvider).isNotEmpty) {
      ref.read(hiddenMediaQueryProvider.notifier).set('');
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      ref.read(hiddenMediaQueryProvider.notifier).set(value);
    });
  }

  void _clearSearch() {
    _searchController.clear();
    ref.read(hiddenMediaQueryProvider.notifier).set('');
  }

  void _clearAllNarrowing() {
    _clearSearch();
    ref.read(hiddenMediaFilterProvider.notifier).clear();
  }

  @override
  Widget build(BuildContext context) {
    final itemsAsync = ref.watch(hiddenMediaItemsProvider);
    final filtered = ref.watch(filteredHiddenMediaProvider);
    final viewMode = ref.watch(hiddenMediaViewProvider);
    final filter = ref.watch(hiddenMediaFilterProvider);
    final query = ref.watch(hiddenMediaQueryProvider);
    // While a scan is running the index is still being built — keep the
    // loading state visible until the scan settles (the provider skips its
    // computation in that case).
    final isScanning = ref.watch(isScanningProvider);

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          onChanged: _onQueryChanged,
          decoration: InputDecoration(
            hintText: 'Search hidden media...',
            border: InputBorder.none,
            prefixIcon: const Icon(Icons.search),
            suffixIcon: query.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    tooltip: 'Clear search',
                    onPressed: _clearSearch,
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
              child: Icon(
                filter.isActive ? Icons.filter_alt : Icons.filter_alt_outlined,
              ),
            ),
            onPressed: () => showSmartFilterSheet(
              context,
              provider: hiddenMediaFilterProvider,
            ),
          ),
          IconButton(
            icon: Icon(
              viewMode == GalleryViewMode.grid
                  ? Icons.view_list
                  : Icons.grid_view,
            ),
            tooltip: viewMode == GalleryViewMode.grid
                ? 'Switch to list view'
                : 'Switch to large icons',
            onPressed: () =>
                ref.read(hiddenMediaViewProvider.notifier).toggle(),
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
                  Text('Analyzing storage for hidden media...'),
                ],
              ),
            )
          : itemsAsync.when(
              loading: () => const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Analyzing storage for hidden media...'),
                  ],
                ),
              ),
              error: (error, stack) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 64,
                      color: Colors.grey,
                    ),
                    const SizedBox(height: 16),
                    const Text('Hidden Media could not be calculated.'),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: () => ref.invalidate(hiddenMediaItemsProvider),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ),
              data: (items) {
                if (items.isEmpty) {
                  // Heuristic empty state — never claim the phone has no
                  // hidden files at all.
                  return const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.visibility_outlined,
                          size: 64,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'No Hidden Media Found',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        SizedBox(height: 8),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 32),
                          child: Text(
                            "MediaRescue didn't find any media matching "
                            'the hidden/unusual criteria.',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  );
                }
                if (filtered.isEmpty) {
                  // Search/filters narrowed everything away.
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.search_off,
                          size: 64,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 16),
                        const Text('No matching hidden media'),
                        const SizedBox(height: 4),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 32),
                          child: Text(
                            'Try a different search or clear the filters.',
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 12),
                        FilledButton.tonal(
                          onPressed: _clearAllNarrowing,
                          child: const Text('Clear search & filters'),
                        ),
                      ],
                    ),
                  );
                }
                return viewMode == GalleryViewMode.grid
                    ? _HiddenMediaGridView(items: filtered)
                    : _HiddenMediaListView(items: filtered);
              },
            ),
    );
  }
}

/// Opens a hidden file with the immersive preview, matching Search/Browse.
void _openHiddenFile(
  BuildContext context,
  FileItem item,
  List<FileItem> media,
) {
  if (item.isImage || item.isVideo) {
    context.push('/preview/media', extra: {'item': item, 'allFiles': media});
  } else if (item.isAudio) {
    context.push('/preview/audio', extra: {'item': item, 'allFiles': media});
  } else if (item.isPdf) {
    context.push('/preview/pdf', extra: item);
  } else {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Cannot preview this file type yet.')),
    );
  }
}

/// Header row shared by both view modes.
Widget _hiddenMediaHeader(BuildContext context, List<HiddenMediaItem> items) {
  final totalSize = items.fold<int>(0, (s, e) => s + e.item.size);
  return Padding(
    padding: const EdgeInsets.all(16),
    child: Align(
      alignment: Alignment.centerLeft,
      child: Text(
        '${items.length} hidden item${items.length == 1 ? '' : 's'}  •  '
        '${_formatSize(totalSize)}',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    ),
  );
}

/// The "Why hidden?" entry injected into the shared file-actions sheet.
ListTile _whyHiddenActionTile(
  BuildContext sheetContext,
  HiddenMediaItem entry,
) {
  return ListTile(
    leading: const Icon(Icons.help_outline),
    title: const Text('Why hidden?'),
    onTap: () {
      Navigator.of(sheetContext).pop();
      _showWhyHidden(sheetContext, entry);
    },
  );
}

/// Explains why one item was classified as hidden — only true signals.
void _showWhyHidden(BuildContext context, HiddenMediaItem entry) {
  final theme = Theme.of(context);
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: theme.colorScheme.surface,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Text(
              'Why hidden?',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              entry.item.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 8),
          ...entry.reasons.reasonLabels.map(
            (label) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, size: 18, color: Colors.green),
                  const SizedBox(width: 10),
                  Expanded(child: Text(label)),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Text(
              'Hidden Media detection is heuristic — a file qualifies when '
              'several independent signals agree.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

/// List view — dense rows with reasons inline (the previous default).
class _HiddenMediaListView extends ConsumerWidget {
  final List<HiddenMediaItem> items;

  const _HiddenMediaListView({required this.items});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final media = items.map((e) => e.item).toList();

    return Column(
      children: [
        _hiddenMediaHeader(context, items),
        Expanded(
          child: ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, index) {
              final entry = items[index];
              final item = entry.item;
              return ListTile(
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: ThumbnailImage(item: item, width: 44, height: 44),
                ),
                title: Text(
                  item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_formatSize(item.size)}  •  '
                      '${item.mimeType ?? 'Unknown'}',
                    ),
                    Text(
                      entry.reasons.reasonLabels.join('  •  '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.more_vert),
                  tooltip: 'File actions',
                  onPressed: () => showFileActionsSheet(
                    context,
                    ref,
                    item,
                    onOpen: () => _openHiddenFile(context, item, media),
                    additionalActions: [_whyHiddenActionTile(context, entry)],
                  ),
                ),
                onTap: () => _openHiddenFile(context, item, media),
                onLongPress: () => _showWhyHidden(context, entry),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Large Icons view — a thumbnail grid mirroring the Gallery's grid layout.
class _HiddenMediaGridView extends ConsumerWidget {
  final List<HiddenMediaItem> items;

  const _HiddenMediaGridView({required this.items});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final media = items.map((e) => e.item).toList();

    return Column(
      children: [
        _hiddenMediaHeader(context, items),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 160,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 0.85,
            ),
            itemCount: items.length,
            itemBuilder: (context, index) {
              return _HiddenMediaGridTile(entry: items[index], media: media);
            },
          ),
        ),
      ],
    );
  }
}

class _HiddenMediaGridTile extends ConsumerWidget {
  final HiddenMediaItem entry;
  final List<FileItem> media;

  const _HiddenMediaGridTile({required this.entry, required this.media});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final item = entry.item;
    final theme = Theme.of(context);

    return InkWell(
      onTap: () => _openHiddenFile(context, item, media),
      onLongPress: () => showFileActionsSheet(
        context,
        ref,
        item,
        onOpen: () => _openHiddenFile(context, item, media),
        additionalActions: [_whyHiddenActionTile(context, entry)],
      ),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: theme.colorScheme.surfaceContainerHighest,
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ThumbnailImage(
                item: item,
                width: double.infinity,
                height: double.infinity,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    _formatSize(item.size),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
