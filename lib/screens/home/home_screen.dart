import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/scanner_provider.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scanState = ref.watch(scanControllerProvider);
    final stats = ref.watch(storageStatsProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final isScanning = scanState.status == ScanStatus.scanning;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            title: const Text('MediaRescue'),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: 'Rescan storage',
                onPressed: () =>
                    ref.read(scanControllerProvider.notifier).startScan(),
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Scan Progress (while scanning) ─────────────────────────
                  if (isScanning) ...[
                    _ScanProgressCard(scanState: scanState),
                    const SizedBox(height: 24),
                  ],

                  // ── Storage Summary Card ───────────────────────────────────
                  _SectionHeader(label: 'Storage Summary'),
                  const SizedBox(height: 8),
                  if (scanState.status == ScanStatus.idle)
                    const _LoadingCard(message: 'Starting scan...')
                  else if (scanState.status == ScanStatus.error)
                    _ErrorCard(message: scanState.error ?? 'Scan failed')
                  else
                    _StorageSummaryCard(stats: stats, formatSize: _formatSize),

                  const SizedBox(height: 24),

                  // ── Quick Actions ──────────────────────────────────────────
                  _SectionHeader(label: 'Quick Actions'),
                  const SizedBox(height: 8),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 2.4,
                    children: [
                      _QuickActionTile(
                        icon: Icons.folder_open,
                        label: 'Browse Files',
                        color: colorScheme.primaryContainer,
                        onTap: () => context.go('/browse'),
                      ),
                      _QuickActionTile(
                        icon: Icons.photo_library_outlined,
                        label: 'Gallery',
                        color: colorScheme.tertiaryContainer,
                        onTap: () => context.go('/gallery'),
                      ),
                      _QuickActionTile(
                        icon: Icons.data_usage,
                        label: 'Large Files',
                        color: colorScheme.errorContainer,
                        onTap: () => context.push('/large-files'),
                      ),
                      _QuickActionTile(
                        icon: Icons.visibility_outlined,
                        label: 'Hidden Media',
                        color: colorScheme.secondaryContainer,
                        onTap: () => context.push('/hidden-media'),
                      ),
                      _QuickActionTile(
                        icon: Icons.search,
                        label: 'Search',
                        color: colorScheme.secondaryContainer,
                        onTap: () => context.go('/search'),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // ── Cleanup Suggestions ────────────────────────────────────
                  _SectionHeader(label: 'Cleanup Suggestions'),
                  const SizedBox(height: 8),
                  if (scanState.status == ScanStatus.complete)
                    _CleanupSuggestions(stats: stats, formatSize: _formatSize)
                  else if (isScanning)
                    const _LoadingCard(message: 'Analyzing...')
                  else
                    const SizedBox.shrink(),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScanProgressCard extends StatelessWidget {
  final ScanState scanState;

  const _ScanProgressCard({required this.scanState});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 12),
                Text(
                  'Scanning storage...',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '${scanState.filesDiscovered} files discovered',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 4),
            Text(
              'Current location:',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Text(
              scanState.currentPath.isEmpty
                  ? '/storage/emulated/0'
                  : scanState.currentPath,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                    color: Theme.of(context).colorScheme.primary,
                  ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context)
          .textTheme
          .titleMedium
          ?.copyWith(fontWeight: FontWeight.bold),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  final String message;
  const _LoadingCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(message),
          ],
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  const _ErrorCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.red),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }
}

class _StorageSummaryCard extends StatelessWidget {
  final Map<String, int> stats;
  final String Function(int) formatSize;

  const _StorageSummaryCard({required this.stats, required this.formatSize});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final categories = [
      ('Images', Icons.image, Colors.purple, stats['Images'] ?? 0),
      ('Videos', Icons.video_file, Colors.blue, stats['Videos'] ?? 0),
      ('Audio', Icons.audiotrack, Colors.green, stats['Audio'] ?? 0),
      ('Documents', Icons.picture_as_pdf, Colors.orange, stats['Documents'] ?? 0),
      ('Other', Icons.insert_drive_file, Colors.grey, stats['Other'] ?? 0),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.storage, color: colorScheme.primary),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      formatSize(stats['Total'] ?? 0),
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Text('${stats['Count'] ?? 0} files discovered'),
                  ],
                ),
              ],
            ),
            const Divider(height: 24),
            ...categories.map((c) {
              final (label, icon, color, size) = c;
              if (size == 0) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Icon(icon, color: color, size: 18),
                    const SizedBox(width: 8),
                    Expanded(child: Text(label)),
                    Text(formatSize(size),
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _CleanupSuggestions extends StatelessWidget {
  final Map<String, int> stats;
  final String Function(int) formatSize;

  const _CleanupSuggestions({required this.stats, required this.formatSize});

  @override
  Widget build(BuildContext context) {
    final suggestions = <(String, String, IconData, Color, String)>[];
    final videos = stats['Videos'] ?? 0;
    final images = stats['Images'] ?? 0;
    final other = stats['Other'] ?? 0;

    if (videos > 500 * 1024 * 1024) {
      suggestions.add((
        'Large video files',
        '${formatSize(videos)} in videos — review for cleanup',
        Icons.video_collection,
        Colors.blue,
        '/large-files',
      ));
    }
    if (images > 200 * 1024 * 1024) {
      suggestions.add((
        'Many images',
        '${formatSize(images)} in images — check for duplicates',
        Icons.photo_library,
        Colors.purple,
        '/gallery',
      ));
    }
    if (other > 100 * 1024 * 1024) {
      suggestions.add((
        'Unknown files',
        '${formatSize(other)} in other files — review',
        Icons.help_outline,
        Colors.grey,
        '/browse',
      ));
    }

    if (suggestions.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.check_circle_outline, color: Colors.green),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'No immediate cleanup suggestions. Your storage looks good!',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: suggestions.map((s) {
        final (title, subtitle, icon, color, route) = s;
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: Icon(icon, color: color),
            title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(subtitle),
            trailing: const Icon(Icons.arrow_forward_ios, size: 14),
            onTap: () {
              // Full-screen destinations must be pushed (so Back returns to
              // the previous screen); tab destinations use go().
              if (route == '/large-files') {
                context.push(route);
              } else {
                context.go(route);
              }
            },
          ),
        );
      }).toList(),
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Ink(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(icon),
              const SizedBox(width: 8),
              Flexible(
                child: Text(label,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}