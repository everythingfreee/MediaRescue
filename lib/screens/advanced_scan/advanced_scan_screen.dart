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
import '../../providers/advanced_scan_provider.dart';
import '../../providers/filter_provider.dart';
import '../../providers/rescue_provider.dart';
import '../../providers/selection_provider.dart';
import '../../providers/storage_provider.dart';
import '../../services/link_service.dart';
import '../../services/advanced_scan_service.dart';
import '../../widgets/app_card.dart';
import '../../widgets/file_actions_sheet.dart';
import '../../widgets/smart_filter_sheet.dart';
import '../../widgets/thumbnail_image.dart';

enum _AdvancedSort { name, size, modified }

class AdvancedScanScreen extends ConsumerStatefulWidget {
  const AdvancedScanScreen({super.key});

  @override
  ConsumerState<AdvancedScanScreen> createState() => _AdvancedScanScreenState();
}

class _AdvancedScanScreenState extends ConsumerState<AdvancedScanScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  bool _largeThumbnails = false;
  bool _preparingPreview = false;
  _AdvancedSort _sort = _AdvancedSort.name;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final controller = ref.read(advancedScanProvider.notifier);
        controller.loadCachedFiles();
        controller.refreshStatus();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(advancedScanProvider);
    final theme = Theme.of(context);
    final scanning =
        state.scanStatus == AdvancedScanStatus.scanning ||
        state.scanStatus == AdvancedScanStatus.starting;
    final ready =
        state.shizukuStatus == ShizukuStatus.authorized ||
        state.shizukuStatus == ShizukuStatus.serviceConnected;
    final completed = state.scanStatus == AdvancedScanStatus.completed;
    final filter = ref.watch(advancedSmartFilterProvider);
    final files = _visibleFiles(state.files, filter);
    final selected = ref.watch(selectionProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Advanced Scanning'),
        actions: [
          IconButton(
            tooltip: 'Sort files',
            icon: const HugeIcon(icon: HugeIcons.strokeRoundedSorting01),
            onPressed: () => _showSortMenu(context),
          ),
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
              provider: advancedSmartFilterProvider,
            ),
          ),
          IconButton(
            tooltip: _largeThumbnails ? 'List view' : 'Large thumbnails',
            icon: HugeIcon(
              icon: _largeThumbnails ? HugeIcons.strokeRoundedMenu01 : HugeIcons.strokeRoundedGrid,
            ),
            onPressed: () =>
                setState(() => _largeThumbnails = !_largeThumbnails),
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              if (!completed)
                SliverToBoxAdapter(
                  child: _topSection(state, theme, scanning, ready),
                ),
              if (state.files.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: _resultsHeader(
                    state,
                    theme,
                    scanning,
                    filter,
                    files.length,
                  ),
                ),
                if (_largeThumbnails)
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                    sliver: SliverGrid.builder(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: AppSpacing.sm,
                            mainAxisSpacing: AppSpacing.sm,
                            childAspectRatio: .78,
                          ),
                      itemCount: files.length,
                      itemBuilder: (context, index) => _AdvancedGridTile(
                        item: files[index],
                        onTap: () => _openFile(files[index], files),
                        onRescue: () => _rescue(files[index]),
                        selected: selected.contains(files[index].path),
                      ),
                    ),
                  )
                else
                  SliverList.builder(
                    itemCount: files.length,
                    itemBuilder: (context, index) => _AdvancedResultTile(
                      item: files[index],
                      onOpen: () => _openFile(files[index], files),
                      onRescue: () => _rescue(files[index]),
                      selected: selected.contains(files[index].path),
                    ),
                  ),
                const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xl)),
              ],
            ],
          ),
          if (_preparingPreview)
            Positioned.fill(
              child: ColoredBox(
                color: Colors.black54,
                child: Center(
                  child: AppCard(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          'Preparing preview…',
                          style: theme.textTheme.titleMedium,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _CompletedScanFooter(
              state: state,
              onRescan: !scanning && ready
                  ? () => ref.read(advancedScanProvider.notifier).startScan()
                  : null,
            ),
            if (selected.isNotEmpty)
              _AdvancedSelectionBar(
                files: files,
                onClear: () => ref.read(selectionProvider.notifier).clear(),
              ),
          ],
        ),
      ),
    );
  }

  List<FileItem> _visibleFiles(List<FileItem> source, SmartFilterState filter) {
    final files = applySmartFilters(
      source.where((file) => !file.isDirectory).where((file) {
        final query = _query.trim().toLowerCase();
        return query.isEmpty ||
            file.name.toLowerCase().contains(query) ||
            file.path.toLowerCase().contains(query);
      }).toList(),
      filter,
    );
    files.sort((a, b) {
      switch (_sort) {
        case _AdvancedSort.name:
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        case _AdvancedSort.size:
          return b.size.compareTo(a.size);
        case _AdvancedSort.modified:
          return b.modifiedDate.compareTo(a.modifiedDate);
      }
    });
    return files;
  }

  void _showSortMenu(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg))),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final entry in const [
              (_AdvancedSort.name, 'Name'),
              (_AdvancedSort.size, 'Largest first'),
              (_AdvancedSort.modified, 'Recently modified'),
            ])
              ListTile(
                leading: Icon(
                  _sort == entry.$1
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  color: _sort == entry.$1 ? Theme.of(context).colorScheme.primary : null,
                ),
                title: Text(entry.$2),
                onTap: () {
                  setState(() => _sort = entry.$1);
                  Navigator.pop(context);
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _openFile(FileItem item, List<FileItem> files) async {
    final supported =
        item.isImage || item.isVideo || item.isAudio || item.isPdf;
    if (!supported) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cannot preview this file type yet.')),
        );
      }
      return;
    }
    if (mounted) setState(() => _preparingPreview = true);
    try {
      if (item.isImage || item.isVideo) {
        final mediaFiles = files
            .where((file) => file.isImage || file.isVideo)
            .toList();
        final copiedItems = (await Future.wait(
          mediaFiles.map((file) async {
            final cachedPath = _previewCachePath(file);
            final copied = _isCachedPath(file.path)
                ? true
                : await AdvancedScanService.instance.copyAdvancedFile(
                    file.path,
                    cachedPath,
                  );
            return copied ? file.copyWith(path: cachedPath) : null;
          }),
        )).whereType<FileItem>().toList();
        if (!mounted) return;
        final previewItem = copiedItems.firstWhere(
          (file) => file.name == item.name,
          orElse: () => const FileItem(
            path: '',
            name: '',
            size: 0,
            modifiedDate: 0,
            isDirectory: false,
          ),
        );
        if (previewItem.path.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not prepare this file for preview.'),
            ),
          );
          return;
        }
        context.push(
          '/preview/media',
          extra: {'item': previewItem, 'allFiles': copiedItems},
        );
      } else {
        final cachedPath = _previewCachePath(item);
        final copied = _isCachedPath(item.path)
            ? true
            : await AdvancedScanService.instance.copyAdvancedFile(
                item.path,
                cachedPath,
                overwrite: false,
              );
        if (!copied || !mounted) return;
        final previewItem = item.copyWith(path: cachedPath);
        if (item.isAudio) {
          context.push(
            '/preview/audio',
            extra: {
              'item': previewItem,
              'allFiles': [previewItem],
            },
          );
        } else if (item.isPdf) {
          context.push('/preview/pdf', extra: previewItem);
        }
      }
    } finally {
      if (mounted) setState(() => _preparingPreview = false);
    }
  }

  String _previewCachePath(FileItem item) =>
      '${AdvancedScanController.previewCachePath}/${item.name}';

  bool _isCachedPath(String path) =>
      path.startsWith('${AdvancedScanController.previewCachePath}/');

  Future<void> _rescue(FileItem item) async {
    final settings = ref.read(rescueSettingsProvider);
    final destination = settings.destinationFor(item);
    final targetPath = '$destination/${item.name}';
    final copied = _isCachedPath(item.path)
        ? await ref
              .read(storageServiceProvider)
              .copyFileVerified(item.path, destination, false)
              .then(
                (result) =>
                    result['success'] == true ||
                    result['alreadyExists'] == true,
              )
        : await AdvancedScanService.instance.copyAdvancedFile(
            item.path,
            targetPath,
          );
    if (copied) {
      await ref.read(storageServiceProvider).indexMedia([targetPath]);
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          copied ? 'Copied to $destination' : 'Could not copy this file',
        ),
      ),
    );
  }

  Widget _topSection(
    AdvancedScanState state,
    ThemeData theme,
    bool scanning,
    bool ready,
  ) {
    return Padding(
      padding: AppSpacing.pagePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ShizukuStatusCard(state: state),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Scan Android/data and Android/obb using Shizuku.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Read-only: Advanced Scanning never modifies or deletes system data.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (scanning)
            _ScanProgressCard(state: state)
          else
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(borderRadius: AppRadius.borderMd),
              ),
              onPressed: ready
                  ? () => ref.read(advancedScanProvider.notifier).startScan()
                  : null,
              icon: const HugeIcon(icon: HugeIcons.strokeRoundedCpu, color: Colors.white),
              label: const Text('Start Advanced Scan'),
            ),
          if (state.message != null) ...[
            const SizedBox(height: AppSpacing.md),
            _MessageCard(state: state),
          ],
          if (state.rootStatuses.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            ...state.rootStatuses.keys.map(
              (index) => _RootStatusRow(
                index: index,
                status: state.rootStatuses[index] ?? 'unknown',
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _resultsHeader(
    AdvancedScanState state,
    ThemeData theme,
    bool scanning,
    SmartFilterState filter,
    int visibleCount,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            onChanged: (value) => setState(() => _query = value),
            decoration: const InputDecoration(
              prefixIcon: HugeIcon(icon: HugeIcons.strokeRoundedSearch01, size: 20),
              hintText: 'Search scanned items',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: Text(
                  '$visibleCount files found',
                  style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              if (!scanning)
                TextButton(
                  onPressed: () =>
                      ref.read(advancedScanProvider.notifier).clearResults(),
                  child: const Text('Clear'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ShizukuStatusCard extends ConsumerWidget {
  final AdvancedScanState state;

  const _ShizukuStatusCard({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final (icon, color, title, subtitle) = switch (state.shizukuStatus) {
      ShizukuStatus.unknown => (
        HugeIcons.strokeRoundedClock01,
        theme.colorScheme.outline,
        'Checking Shizuku…',
        'One moment please.',
      ),
      ShizukuStatus.unavailable => (
        HugeIcons.strokeRoundedAlertCircle,
        AppColors.error,
        'Shizuku is not installed',
        'Advanced Scanning requires Shizuku service. It is completely optional.',
      ),
      ShizukuStatus.binderNotReceived => (
        HugeIcons.strokeRoundedRefresh,
        AppColors.warning,
        'Waiting for Shizuku connection',
        'Shizuku is installed, but binder has not connected yet.',
      ),
      ShizukuStatus.binderDisconnected => (
        HugeIcons.strokeRoundedLink01,
        AppColors.warning,
        'Shizuku connection lost',
        'Shizuku service disconnected.',
      ),
      ShizukuStatus.notRunning => (
        HugeIcons.strokeRoundedPlay,
        AppColors.warning,
        'Shizuku is not running',
        'Start Shizuku service then return to MediaRescue.',
      ),
      ShizukuStatus.waitingForPermission => (
        HugeIcons.strokeRoundedClock01,
        AppColors.warning,
        'Waiting for Shizuku authorization…',
        'Confirm authorization dialog in Shizuku.',
      ),
      ShizukuStatus.permissionDenied => (
        HugeIcons.strokeRoundedCancel01,
        AppColors.error,
        'Authorization denied',
        'MediaRescue needs Shizuku permission to scan data folders.',
      ),
      ShizukuStatus.authorized => (
        HugeIcons.strokeRoundedCheckmarkCircle02,
        AppColors.success,
        'Shizuku authorized — ready to scan',
        'Connected and ready to perform advanced scanning.',
      ),
      ShizukuStatus.serviceConnected => (
        HugeIcons.strokeRoundedCheckmarkCircle02,
        AppColors.success,
        'Shizuku connected — ready to scan',
        'Advanced Scanning service connected.',
      ),
      ShizukuStatus.error => (
        HugeIcons.strokeRoundedAlertCircle,
        AppColors.error,
        'Shizuku state error',
        'Ensure Shizuku is running properly.',
      ),
    };

    final canAuthorize =
        state.shizukuStatus == ShizukuStatus.notRunning ||
        state.shizukuStatus == ShizukuStatus.waitingForPermission ||
        state.shizukuStatus == ShizukuStatus.permissionDenied;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              HugeIcon(icon: icon, color: color),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            subtitle,
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              OutlinedButton.icon(
                onPressed: () => context.push('/shizuku-guide'),
                icon: const HugeIcon(icon: HugeIcons.strokeRoundedHelpCircle, size: 16),
                label: const Text('Setup Guide'),
              ),
              if (canAuthorize)
                FilledButton.icon(
                  onPressed: () => ref
                      .read(advancedScanProvider.notifier)
                      .requestAuthorization(),
                  icon: const HugeIcon(icon: HugeIcons.strokeRoundedKey01, size: 16),
                  label: const Text('Authorize MediaRescue'),
                ),
              if (state.shizukuStatus == ShizukuStatus.unavailable)
                FilledButton.icon(
                  onPressed: () async {
                    final ok = await LinkService.openShizukuPlayStore();
                    if (!ok && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Could not open Play Store.'),
                        ),
                      );
                    }
                  },
                  icon: const HugeIcon(icon: HugeIcons.strokeRoundedDownload01, size: 16),
                  label: const Text('Get Shizuku'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CompletedScanFooter extends StatelessWidget {
  final AdvancedScanState state;
  final VoidCallback? onRescan;

  const _CompletedScanFooter({required this.state, required this.onRescan});

  bool get _connected =>
      state.shizukuStatus == ShizukuStatus.authorized ||
      state.shizukuStatus == ShizukuStatus.serviceConnected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _connected ? AppColors.success : AppColors.error;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
      color: theme.colorScheme.surfaceContainerLow,
      child: Row(
        children: [
          HugeIcon(
            icon: _connected ? HugeIcons.strokeRoundedCheckmarkCircle02 : HugeIcons.strokeRoundedAlertCircle,
            color: color,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              _connected ? 'Shizuku Connected' : 'Shizuku Disconnected',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ElevatedButton.icon(
            onPressed: onRescan,
            icon: const HugeIcon(icon: HugeIcons.strokeRoundedRefresh, size: 16),
            label: const Text('Rescan'),
          ),
        ],
      ),
    );
  }
}

class _ScanProgressCard extends ConsumerWidget {
  final AdvancedScanState state;

  const _ScanProgressCard({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  state.scanStatus == AdvancedScanStatus.starting
                      ? 'Starting scan service…'
                      : (state.progressStage.isEmpty
                            ? 'Scanning…'
                            : state.progressStage),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            '${state.filesFound} items indexed',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.sm),
          const LinearProgressIndicator(minHeight: 3),
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () =>
                  ref.read(advancedScanProvider.notifier).stopScan(),
              icon: const HugeIcon(icon: HugeIcons.strokeRoundedCancel01, size: 16, color: AppColors.error),
              label: const Text('Cancel Scan', style: TextStyle(color: AppColors.error)),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  final AdvancedScanState state;

  const _MessageCard({required this.state});

  @override
  Widget build(BuildContext context) {
    final isError = state.scanStatus == AdvancedScanStatus.failed;
    return AppCard(
      borderColor: isError ? AppColors.error : AppColors.info,
      child: Row(
        children: [
          HugeIcon(
            icon: isError ? HugeIcons.strokeRoundedAlertCircle : HugeIcons.strokeRoundedInformationCircle,
            color: isError ? AppColors.error : AppColors.info,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              state.message ?? '',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _RootStatusRow extends StatelessWidget {
  final int index;
  final String status;

  const _RootStatusRow({required this.index, required this.status});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = AdvancedScanController.rootLabels[index] ?? 'Root $index';
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        children: [
          HugeIcon(
            icon: switch (status) {
              'ok' => HugeIcons.strokeRoundedCheckmarkCircle02,
              'missing' => HugeIcons.strokeRoundedHelpCircle,
              _ => HugeIcons.strokeRoundedCancel01,
            },
            size: 16,
            color: switch (status) {
              'ok' => AppColors.success,
              'missing' => AppColors.warning,
              _ => AppColors.error,
            },
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(switch (status) {
              'ok' => '$label — accessible',
              'missing' => '$label — missing',
              _ => '$label — inaccessible',
            }, style: theme.textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}

class _AdvancedResultTile extends ConsumerWidget {
  final FileItem item;
  final VoidCallback onOpen;
  final VoidCallback onRescue;
  final bool selected;

  const _AdvancedResultTile({
    required this.item,
    required this.onOpen,
    required this.onRescue,
    required this.selected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final relative = item.path.replaceFirst('/storage/emulated/0/', '');
    return ListTile(
      leading: ThumbnailImage(item: item, width: 44, height: 44, borderRadius: AppRadius.sm),
      title: Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(
        relative,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTypography.codeMono,
      ),
      onTap: onOpen,
      trailing: IconButton(
        icon: const HugeIcon(icon: HugeIcons.strokeRoundedMoreVertical, size: 18),
        onPressed: () => showFileActionsSheet(
          context,
          ref,
          item,
          onOpen: onOpen,
          additionalActions: [
            ListTile(
              leading: const HugeIcon(icon: HugeIcons.strokeRoundedDownload01, color: AppColors.primary),
              title: const Text('Copy to Rescue'),
              onTap: () {
                Navigator.of(context).pop();
                onRescue();
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _AdvancedGridTile extends ConsumerWidget {
  final FileItem item;
  final VoidCallback onTap;
  final VoidCallback onRescue;
  final bool selected;

  const _AdvancedGridTile({
    required this.item,
    required this.onTap,
    required this.onRescue,
    required this.selected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
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
              child: ThumbnailImage(item: item, width: double.infinity, height: double.infinity, borderRadius: 0),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.xs + 2),
              child: Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdvancedSelectionBar extends ConsumerWidget {
  final List<FileItem> files;
  final VoidCallback onClear;

  const _AdvancedSelectionBar({required this.files, required this.onClear});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedPaths = ref.watch(selectionProvider);
    final selected = files
        .where((file) => selectedPaths.contains(file.path))
        .toList();
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.all(AppSpacing.lg),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: AppRadius.borderPill,
        border: Border.all(color: theme.colorScheme.outline, width: 1),
      ),
      child: Row(
        children: [
          Expanded(child: Text('${selectedPaths.length} selected', style: const TextStyle(fontWeight: FontWeight.bold))),
          ElevatedButton.icon(
            onPressed: selected.isEmpty
                ? null
                : () => _copySelected(context, ref, selected),
            icon: const HugeIcon(icon: HugeIcons.strokeRoundedDownload01, color: Colors.white, size: 16),
            label: const Text('Copy to Rescue'),
          ),
          IconButton(
            onPressed: onClear,
            icon: HugeIcon(icon: HugeIcons.strokeRoundedCancel01, color: theme.colorScheme.onSurface),
            tooltip: 'Clear selection',
          ),
        ],
      ),
    );
  }

  Future<void> _copySelected(
    BuildContext context,
    WidgetRef ref,
    List<FileItem> files,
  ) async {
    final settings = ref.read(rescueSettingsProvider);
    var copiedCount = 0;
    final copiedPaths = <String>[];
    for (final file in files) {
      final destination = settings.destinationFor(file);
      final ok =
          file.path.startsWith('${AdvancedScanController.previewCachePath}/')
          ? await ref
                .read(storageServiceProvider)
                .copyFileVerified(file.path, destination, false)
                .then(
                  (result) =>
                      result['success'] == true ||
                      result['alreadyExists'] == true,
                )
          : await AdvancedScanService.instance.copyAdvancedFile(
              file.path,
              '$destination/${file.name}',
            );
      if (ok) {
        copiedCount++;
        copiedPaths.add('$destination/${file.name}');
      }
    }
    if (copiedPaths.isNotEmpty) {
      await ref.read(storageServiceProvider).indexMedia(copiedPaths);
    }
    ref.read(selectionProvider.notifier).clear();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Copied $copiedCount of ${files.length} files to Rescue.',
          ),
        ),
      );
    }
  }
}
