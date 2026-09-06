import 'package:flutter/material.dart';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/file_item.dart';
import '../../models/smart_filter.dart';
import '../../providers/advanced_scan_provider.dart';
import '../../providers/filter_provider.dart';
import '../../providers/rescue_provider.dart';
import '../../providers/selection_provider.dart';
import '../../providers/storage_provider.dart';
import '../../services/link_service.dart';
import '../../services/advanced_scan_service.dart';
import '../../widgets/file_actions_sheet.dart';
import '../../widgets/smart_filter_sheet.dart';
import '../../widgets/thumbnail_image.dart';

enum _AdvancedSort { name, size, modified }

String _formatSize(int bytes) {
  if (bytes <= 0) return '—';
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
}

/// Dedicated Advanced Scanning screen (optional Shizuku feature).
///
/// Shows the live Shizuku status, guides the user through setup when needed,
/// starts/cancels the read-only scan of Android/data and Android/obb and
/// lists the results. Fully independent from the normal scanner.
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
    // Re-evaluate Shizuku state on every entry (no stale "Authorized" state
    // after app restarts or permission revocation).
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
            icon: const Icon(Icons.sort),
            onPressed: () => _showSortMenu(context),
          ),
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
              provider: advancedSmartFilterProvider,
            ),
          ),
          IconButton(
            tooltip: _largeThumbnails ? 'List view' : 'Large thumbnails',
            icon: Icon(_largeThumbnails ? Icons.view_list : Icons.grid_view),
            onPressed: () =>
                setState(() => _largeThumbnails = !_largeThumbnails),
          ),
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
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    sliver: SliverGrid.builder(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
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
                const SliverToBoxAdapter(child: SizedBox(height: 24)),
              ],
            ],
          ),
          if (_preparingPreview)
            Positioned.fill(
              child: ColoredBox(
                color: Colors.black54,
                child: Center(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(),
                          const SizedBox(height: 16),
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
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ShizukuStatusCard(state: state),
          const SizedBox(height: 16),
          Text(
            'Scan Android/data and Android/obb using Shizuku.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Read-only: Advanced Scanning never modifies, moves or deletes anything.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          if (scanning)
            _ScanProgressCard(state: state)
          else
            FilledButton.icon(
              // Starting requires verified authorization — never inferred from
              // Shizuku merely being installed or running.
              onPressed: ready
                  ? () => ref.read(advancedScanProvider.notifier).startScan()
                  : null,
              icon: const Icon(Icons.radar),
              label: const Text('Start Advanced Scan'),
            ),
          if (state.message != null) ...[
            const SizedBox(height: 12),
            _MessageCard(state: state),
          ],
          if (state.rootStatuses.isNotEmpty) ...[
            const SizedBox(height: 8),
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
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            onChanged: (value) => setState(() => _query = value),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Search scanned files',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  '$visibleCount files'
                  '${state.errorCount > 0 ? '  •  ${state.errorCount} could not be accessed' : ''}',
                  style: theme.textTheme.bodyMedium,
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

/// Shows the verified Shizuku state and the matching next action.
class _ShizukuStatusCard extends ConsumerWidget {
  final AdvancedScanState state;

  const _ShizukuStatusCard({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final (icon, color, title, subtitle) = switch (state.shizukuStatus) {
      ShizukuStatus.unknown => (
        Icons.hourglass_top,
        theme.colorScheme.outline,
        'Checking Shizuku…',
        'One moment please.',
      ),
      ShizukuStatus.unavailable => (
        Icons.extension_off,
        theme.colorScheme.error,
        'Shizuku is not installed',
        'Advanced Scanning needs the free, open-source Shizuku app. '
            'It is completely optional — MediaRescue works fully without it.',
      ),
      ShizukuStatus.binderNotReceived => (
        Icons.sync_problem,
        Colors.orange,
        'Waiting for Shizuku connection',
        'Shizuku is installed, but its binder has not connected yet. Try again in a moment.',
      ),
      ShizukuStatus.binderDisconnected => (
        Icons.link_off,
        Colors.orange,
        'Shizuku connection lost',
        'Shizuku disconnected. Restart its service, then return to MediaRescue.',
      ),
      ShizukuStatus.notRunning => (
        Icons.play_disabled,
        Colors.orange,
        'Shizuku is not running',
        'Open Shizuku and start its service, then come back to MediaRescue.',
      ),
      ShizukuStatus.waitingForPermission => (
        Icons.hourglass_top,
        Colors.orange,
        'Waiting for Shizuku authorization…',
        'Confirm the authorization dialog shown by Shizuku.',
      ),
      ShizukuStatus.permissionDenied => (
        Icons.gpp_bad,
        theme.colorScheme.error,
        'Shizuku authorization was denied',
        'Advanced Scanning stays unavailable until MediaRescue is authorized in Shizuku.',
      ),
      ShizukuStatus.authorized => (
        Icons.verified_user,
        Colors.green,
        'Shizuku authorized — ready to scan',
        'MediaRescue will connect to Shizuku when the scan starts.',
      ),
      ShizukuStatus.serviceConnected => (
        Icons.verified_user,
        Colors.green,
        'Shizuku connected — ready to scan',
        'The Advanced Scanning service is connected.',
      ),
      ShizukuStatus.error => (
        Icons.error_outline,
        theme.colorScheme.error,
        'Shizuku state could not be checked',
        'Make sure Shizuku is installed and running, then try again.',
      ),
    };

    final canAuthorize =
        state.shizukuStatus == ShizukuStatus.notRunning ||
        state.shizukuStatus == ShizukuStatus.waitingForPermission ||
        state.shizukuStatus == ShizukuStatus.permissionDenied;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color),
                const SizedBox(width: 12),
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
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => context.push('/shizuku-guide'),
                  icon: const Icon(Icons.menu_book_outlined, size: 18),
                  label: const Text('Shizuku Setup Guide'),
                ),
                if (canAuthorize)
                  FilledButton.tonalIcon(
                    onPressed: () => ref
                        .read(advancedScanProvider.notifier)
                        .requestAuthorization(),
                    icon: const Icon(Icons.key, size: 18),
                    label: const Text('Authorize MediaRescue'),
                  ),
                if (state.shizukuStatus == ShizukuStatus.unavailable)
                  FilledButton.tonalIcon(
                    onPressed: () async {
                      final ok = await LinkService.openShizukuPlayStore();
                      if (!ok && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Could not open the Play Store.'),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.download, size: 18),
                    label: const Text('Get Shizuku (official)'),
                  ),
              ],
            ),
          ],
        ),
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

  String get _statusTitle => switch (state.shizukuStatus) {
    ShizukuStatus.authorized => 'Shizuku authorized',
    ShizukuStatus.serviceConnected => 'Shizuku connected',
    ShizukuStatus.unavailable => 'Shizuku unavailable',
    ShizukuStatus.notRunning => 'Shizuku not running',
    ShizukuStatus.binderNotReceived => 'Shizuku connection pending',
    ShizukuStatus.binderDisconnected => 'Shizuku disconnected',
    ShizukuStatus.permissionDenied => 'Shizuku permission denied',
    ShizukuStatus.waitingForPermission => 'Waiting for authorization',
    ShizukuStatus.unknown => 'Shizuku status unknown',
    ShizukuStatus.error => 'Shizuku status unavailable',
  };

  void _showDetails(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Shizuku connection'),
        content: Text(
          'Status: $_statusTitle\n\n'
          '${_connected ? 'MediaRescue can use Shizuku for Advanced Scanning.' : 'Advanced Scanning is unavailable until Shizuku is connected and authorized.'}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _connected ? Colors.green : theme.colorScheme.error;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () => _showDetails(context),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  children: [
                    Icon(
                      _connected ? Icons.check_circle : Icons.error,
                      color: color,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _statusTitle,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: color,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const Icon(Icons.chevron_right),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: onRescan,
            icon: const Icon(Icons.refresh),
            label: const Text('Rescan'),
          ),
        ],
      ),
    );
  }
}

/// Live progress while starting / scanning, with a Cancel action.
class _ScanProgressCard extends ConsumerWidget {
  final AdvancedScanState state;

  const _ScanProgressCard({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
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
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    state.scanStatus == AdvancedScanStatus.starting
                        ? 'Starting the scanning service…'
                        : (state.progressStage.isEmpty
                              ? 'Scanning…'
                              : state.progressStage),
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '${state.filesFound} entries found'
              '${state.errorCount > 0 ? '  •  ${state.errorCount} could not be accessed' : ''}',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            const LinearProgressIndicator(minHeight: 3),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () =>
                    ref.read(advancedScanProvider.notifier).stopScan(),
                icon: const Icon(Icons.stop_circle_outlined),
                label: const Text('Cancel Scan'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// User-facing outcome message (failures, cancellations, summaries).
class _MessageCard extends StatelessWidget {
  final AdvancedScanState state;

  const _MessageCard({required this.state});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isError = state.scanStatus == AdvancedScanStatus.failed;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.info_outline,
              size: 20,
              color: isError
                  ? theme.colorScheme.error
                  : theme.colorScheme.primary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                state.message ?? '',
                style: theme.textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Per-root status row (Android/data / Android/obb).
class _RootStatusRow extends StatelessWidget {
  final int index;
  final String status;

  const _RootStatusRow({required this.index, required this.status});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = AdvancedScanController.rootLabels[index] ?? 'Root $index';
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(
            switch (status) {
              'ok' => Icons.check_circle,
              'missing' => Icons.help_outline,
              _ => Icons.block,
            },
            size: 16,
            color: switch (status) {
              'ok' => Colors.green,
              'missing' => Colors.orange,
              _ => theme.colorScheme.error,
            },
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(switch (status) {
              'ok' => '$label — accessible',
              'missing' => '$label — does not exist',
              'inaccessible' => '$label — could not be accessed',
              _ => '$label — could not be checked',
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
    final theme = Theme.of(context);
    final relative = item.path.replaceFirst('/storage/emulated/0/', '');
    return ListTile(
      dense: true,
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: _AdvancedThumbnail(item: item, width: 46, height: 46),
      ),
      title: Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        relative,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      onTap: () {
        if (ref.read(selectionProvider).isNotEmpty) {
          ref.read(selectionProvider.notifier).toggle(item);
        } else {
          onOpen();
        }
      },
      onLongPress: () => ref.read(selectionProvider.notifier).toggle(item),
      tileColor: selected
          ? Theme.of(context).colorScheme.secondaryContainer
          : null,
      trailing: IconButton(
        icon: const Icon(Icons.more_vert),
        tooltip: 'File actions',
        onPressed: () => showFileActionsSheet(
          context,
          ref,
          item,
          onOpen: onOpen,
          additionalActions: [
            ListTile(
              leading: const Icon(Icons.save_alt),
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
      onTap: () {
        if (ref.read(selectionProvider).isNotEmpty) {
          ref.read(selectionProvider.notifier).toggle(item);
        } else {
          onTap();
        }
      },
      overlayColor: WidgetStatePropertyAll(
        selected ? Theme.of(context).colorScheme.secondaryContainer : null,
      ),
      onLongPress: () => showFileActionsSheet(
        context,
        ref,
        item,
        onOpen: onTap,
        additionalActions: [
          ListTile(
            leading: const Icon(Icons.check_box_outlined),
            title: const Text('Select file'),
            onTap: () {
              Navigator.of(context).pop();
              ref.read(selectionProvider.notifier).toggle(item);
            },
          ),
          ListTile(
            leading: const Icon(Icons.save_alt),
            title: const Text('Copy to Rescue'),
            onTap: () {
              Navigator.of(context).pop();
              onRescue();
            },
          ),
        ],
      ),
      borderRadius: BorderRadius.circular(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox.expand(
                    child: ColoredBox(
                      color: theme.colorScheme.surfaceContainerHighest,
                      child: _AdvancedThumbnail(
                        item: item,
                        width: 120,
                        height: 120,
                      ),
                    ),
                  ),
                ),
                if (selected)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.check,
                        color: theme.colorScheme.onPrimary,
                        size: 24,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis),
          Text(_formatSize(item.size), style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _AdvancedThumbnail extends StatefulWidget {
  final FileItem item;
  final double width;
  final double height;

  const _AdvancedThumbnail({
    required this.item,
    required this.width,
    required this.height,
  });

  @override
  State<_AdvancedThumbnail> createState() => _AdvancedThumbnailState();
}

class _AdvancedThumbnailState extends State<_AdvancedThumbnail> {
  String? _path;

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  Future<void> _prepare() async {
    if (!widget.item.isImage && !widget.item.isVideo) return;
    final path =
        '${AdvancedScanController.previewCachePath}/${widget.item.name}';
    final copied =
        widget.item.path.startsWith(
          '${AdvancedScanController.previewCachePath}/',
        ) ||
        await AdvancedScanService.instance.copyAdvancedFile(
          widget.item.path,
          path,
        );
    if (copied && mounted) {
      setState(() => _path = path);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_path == null) {
      return Icon(
        widget.item.isVideo ? Icons.video_file : Icons.image,
        size: widget.width,
        color: Colors.grey,
      );
    }
    final cached = widget.item.copyWith(path: _path);
    if (widget.item.isImage) {
      return Image.file(
        File(_path!),
        width: widget.width,
        height: widget.height,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) =>
            Icon(Icons.image, size: widget.width),
      );
    }
    return ThumbnailImage(
      item: cached,
      width: widget.width,
      height: widget.height,
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
    return BottomAppBar(
      child: Row(
        children: [
          Expanded(child: Text('${selectedPaths.length} selected')),
          IconButton(
            tooltip: 'Select all',
            icon: const Icon(Icons.select_all),
            onPressed: () =>
                ref.read(selectionProvider.notifier).selectAll(files),
          ),
          FilledButton.icon(
            onPressed: selected.isEmpty
                ? null
                : () => _copySelected(context, ref, selected),
            icon: const Icon(Icons.save_alt),
            label: const Text('Copy to Rescue'),
          ),
          IconButton(
            onPressed: onClear,
            icon: const Icon(Icons.close),
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
