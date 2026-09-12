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
    _debounce = Timer(const Duration(milliseconds: 300), () {
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
    final isScanning = ref.watch(isScanningProvider);

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          onChanged: _onQueryChanged,
          decoration: InputDecoration(
            hintText: 'Search hidden media...',
            border: InputBorder.none,
            prefixIcon: const HugeIcon(icon: HugeIcons.strokeRoundedViewOff, size: 20),
            suffixIcon: query.isNotEmpty
                ? IconButton(
                    icon: const HugeIcon(icon: HugeIcons.strokeRoundedCancel01, size: 18),
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
              child: HugeIcon(
                icon: HugeIcons.strokeRoundedFilter,
                color: filter.isActive ? AppColors.primary : Theme.of(context).colorScheme.onSurface,
              ),
            ),
            onPressed: () => showSmartFilterSheet(
              context,
              provider: hiddenMediaFilterProvider,
            ),
          ),
          IconButton(
            icon: HugeIcon(
              icon: viewMode == GalleryViewMode.grid
                  ? HugeIcons.strokeRoundedMenu01
                  : HugeIcons.strokeRoundedGrid,
            ),
            tooltip: viewMode == GalleryViewMode.grid
                ? 'List view'
                : 'Grid view',
            onPressed: () =>
                ref.read(hiddenMediaViewProvider.notifier).toggle(),
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
                    SizedBox(height: AppSpacing.md),
                    Text('Analyzing storage for hidden media...'),
                  ],
                ),
              ),
              error: (error, stack) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const HugeIcon(
                      icon: HugeIcons.strokeRoundedAlertCircle,
                      size: 64,
                      color: AppColors.error,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    const Text('Hidden Media could not be calculated.'),
                    const SizedBox(height: AppSpacing.md),
                    ElevatedButton.icon(
                      onPressed: () => ref.invalidate(hiddenMediaItemsProvider),
                      icon: const HugeIcon(icon: HugeIcons.strokeRoundedRefresh, color: Colors.white),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ),
              data: (items) {
                if (items.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        HugeIcon(
                          icon: HugeIcons.strokeRoundedViewOff,
                          size: 64,
                          color: AppColors.secondary,
                        ),
                        SizedBox(height: AppSpacing.md),
                        Text(
                          'No Hidden Media Found',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        SizedBox(height: AppSpacing.xs),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
                          child: Text(
                            "MediaRescue didn't find any hidden or unusual media files.",
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  );
                }
                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const HugeIcon(
                          icon: HugeIcons.strokeRoundedSearch01,
                          size: 64,
                          color: AppColors.other,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        const Text('No matching hidden media'),
                        const SizedBox(height: AppSpacing.xs),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
                          child: Text(
                            'Try a different search query or reset your active filters.',
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        OutlinedButton(
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

Widget _hiddenMediaHeader(BuildContext context, List<HiddenMediaItem> items) {
  final totalSize = items.fold<int>(0, (s, e) => s + e.item.size);
  return Padding(
    padding: AppSpacing.pagePadding,
    child: Align(
      alignment: Alignment.centerLeft,
      child: Text(
        '${items.length} hidden item${items.length == 1 ? '' : 's'}  •  ${_formatSize(totalSize)}',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
      ),
    ),
  );
}

ListTile _whyHiddenActionTile(
  BuildContext sheetContext,
  HiddenMediaItem entry,
) {
  return ListTile(
    leading: const HugeIcon(icon: HugeIcons.strokeRoundedInformationCircle, color: AppColors.secondary),
    title: const Text('Why hidden?'),
    onTap: () {
      Navigator.of(sheetContext).pop();
      _showWhyHidden(sheetContext, entry);
    },
  );
}

void _showWhyHidden(BuildContext context, HiddenMediaItem entry) {
  final theme = Theme.of(context);
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: theme.colorScheme.surface,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg))),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outline,
                  borderRadius: AppRadius.borderPill,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.xs),
              child: Text(
                'Why hidden?',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Text(
                entry.item.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall,
              ),
            ),
            const Divider(height: 24),
            ...entry.reasons.reasonLabels.map(
              (label) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.xs),
                child: Row(
                  children: [
                    const HugeIcon(icon: HugeIcons.strokeRoundedCheckmarkCircle02, size: 18, color: AppColors.success),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600))),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    ),
  );
}

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
          child: ListView.separated(
            itemCount: items.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final entry = items[index];
              final item = entry.item;
              return ListTile(
                leading: ThumbnailImage(item: item, width: 44, height: 44, borderRadius: AppRadius.sm),
                title: Text(
                  item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_formatSize(item.size)}  •  ${item.mimeType ?? 'Unknown'}',
                      style: AppTypography.codeMono,
                    ),
                    Text(
                      entry.reasons.reasonLabels.join('  •  '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.secondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                trailing: IconButton(
                  icon: const HugeIcon(icon: HugeIcons.strokeRoundedMoreVertical, size: 18),
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
            padding: const EdgeInsets.all(AppSpacing.sm),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 160,
              mainAxisSpacing: AppSpacing.sm,
              crossAxisSpacing: AppSpacing.sm,
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
      borderRadius: AppRadius.borderMd,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: AppRadius.borderMd,
          border: Border.all(color: theme.colorScheme.outline, width: 1),
          color: theme.cardTheme.color,
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
                borderRadius: 0,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.xs + 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    _formatSize(item.size),
                    style: theme.textTheme.bodySmall,
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
