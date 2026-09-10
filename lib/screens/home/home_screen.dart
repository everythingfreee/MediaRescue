import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_radius.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_typography.dart';
import '../../providers/scanner_provider.dart';
import '../../widgets/app_card.dart';

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
    final theme = Theme.of(context);
    final isScanning = scanState.status == ScanStatus.scanning;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 110,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(
                left: AppSpacing.lg,
                bottom: AppSpacing.md,
              ),
              title: Row(
                children: [
                  Text(
                    'MediaRescue',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: isScanning ? AppColors.warning : AppColors.success,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              IconButton(
                icon: const HugeIcon(
                  icon: HugeIcons.strokeRoundedRefresh,
                  color: AppColors.primary,
                ),
                tooltip: 'Rescan storage',
                onPressed: () =>
                    ref.read(scanControllerProvider.notifier).startScan(),
              ),
              const SizedBox(width: AppSpacing.sm),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: AppSpacing.pagePadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Scan Progress Card ─────────────────────────────────────
                  if (isScanning) ...[
                    _ScanProgressHeroCard(scanState: scanState),
                    const SizedBox(height: AppSpacing.xl),
                  ],

                  // ── Storage Summary Section ────────────────────────────────
                  const _SectionHeader(
                    title: 'Storage Summary',
                    subtitle: 'Storage discovery breakdown',
                  ),
                  const SizedBox(height: AppSpacing.md),
                  if (scanState.status == ScanStatus.idle)
                    const _LoadingCard(message: 'Starting scan...')
                  else if (scanState.status == ScanStatus.error)
                    _ErrorCard(message: scanState.error ?? 'Scan failed')
                  else
                    _StorageSummaryCard(stats: stats, formatSize: _formatSize),

                  const SizedBox(height: AppSpacing.xl),

                  // ── Quick Actions Grid ─────────────────────────────────────
                  const _SectionHeader(
                    title: 'Quick Actions',
                    subtitle: 'Access rescue features & file browsers',
                  ),
                  const SizedBox(height: AppSpacing.md),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: AppSpacing.md,
                    crossAxisSpacing: AppSpacing.md,
                    childAspectRatio: 2.2,
                    children: [
                      _QuickActionTile(
                        icon: HugeIcons.strokeRoundedFolder01,
                        label: 'Browse Files',
                        color: AppColors.primary,
                        onTap: () => context.go('/browse'),
                      ),
                      _QuickActionTile(
                        icon: HugeIcons.strokeRoundedImage01,
                        label: 'Gallery',
                        color: AppColors.images,
                        onTap: () => context.go('/gallery'),
                      ),
                      _QuickActionTile(
                        icon: HugeIcons.strokeRoundedHardDrive,
                        label: 'Large Files',
                        color: AppColors.documents,
                        onTap: () => context.push('/large-files'),
                      ),
                      _QuickActionTile(
                        icon: HugeIcons.strokeRoundedLocker01,
                        label: 'Hidden Media',
                        color: AppColors.secondary,
                        onTap: () => context.push('/hidden-media'),
                      ),
                      _QuickActionTile(
                        icon: HugeIcons.strokeRoundedCpu,
                        label: 'Advanced Scan',
                        color: AppColors.primary,
                        onTap: () => context.push('/advanced-scan'),
                      ),
                      _QuickActionTile(
                        icon: HugeIcons.strokeRoundedSearch01,
                        label: 'Search',
                        color: AppColors.other,
                        onTap: () => context.go('/search'),
                      ),
                    ],
                  ),

                  const SizedBox(height: AppSpacing.xl),

                  // ── Cleanup Suggestions ────────────────────────────────────
                  const _SectionHeader(
                    title: 'Cleanup Suggestions',
                    subtitle: 'Smart recommendations based on discovery',
                  ),
                  const SizedBox(height: AppSpacing.md),
                  if (scanState.status == ScanStatus.complete)
                    _CleanupSuggestions(stats: stats, formatSize: _formatSize)
                  else if (isScanning)
                    const _LoadingCard(message: 'Analyzing storage...')
                  else
                    const SizedBox.shrink(),

                  const SizedBox(height: AppSpacing.xxl),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScanProgressHeroCard extends StatelessWidget {
  final ScanState scanState;

  const _ScanProgressHeroCard({required this.scanState});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppCard(
      color: theme.colorScheme.primaryContainer.withOpacity(0.4),
      borderColor: theme.colorScheme.primary.withOpacity(0.3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
              const SizedBox(width: AppSpacing.md),
              Text(
                'Scanning storage...',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            '${scanState.filesDiscovered} files discovered',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text('Current directory:', style: theme.textTheme.bodySmall),
          const SizedBox(height: AppSpacing.xs),
          Text(
            scanState.currentPath.isEmpty
                ? '/storage/emulated/0'
                : scanState.currentPath,
            style: AppTypography.codeMono.copyWith(
              color: theme.colorScheme.primary,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionHeader({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(subtitle, style: theme.textTheme.bodySmall),
      ],
    );
  }
}

class _LoadingCard extends StatelessWidget {
  final String message;
  const _LoadingCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: AppSpacing.md),
              Text(message),
            ],
          ),
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
    return AppCard(
      borderColor: AppColors.error.withOpacity(0.5),
      child: Row(
        children: [
          const HugeIcon(
            icon: HugeIcons.strokeRoundedAlertCircle,
            color: AppColors.error,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: Text(message)),
        ],
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
    final theme = Theme.of(context);
    final totalSize = stats['Total'] ?? 0;

    final categories = [
      (
        'Images',
        HugeIcons.strokeRoundedImage01,
        AppColors.images,
        stats['Images'] ?? 0,
      ),
      (
        'Videos',
        HugeIcons.strokeRoundedVideo01,
        AppColors.videos,
        stats['Videos'] ?? 0,
      ),
      (
        'Audio',
        HugeIcons.strokeRoundedMusicNote01,
        AppColors.audio,
        stats['Audio'] ?? 0,
      ),
      (
        'Documents',
        HugeIcons.strokeRoundedFile01,
        AppColors.documents,
        stats['Documents'] ?? 0,
      ),
      (
        'Other',
        HugeIcons.strokeRoundedFolder01,
        AppColors.other,
        stats['Other'] ?? 0,
      ),
    ];

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.12),
                  borderRadius: AppRadius.borderMd,
                ),
                child: HugeIcon(
                  icon: HugeIcons.strokeRoundedHardDrive,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    formatSize(totalSize),
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    '${stats['Count'] ?? 0} total files indexed',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          // Category progress bar segment
          if (totalSize > 0) ...[
            ClipRRect(
              borderRadius: AppRadius.borderPill,
              child: SizedBox(
                height: 10,
                child: Row(
                  children: categories.map((c) {
                    final size = c.$4;
                    if (size == 0) return const SizedBox.shrink();
                    final flex = ((size / totalSize) * 1000).toInt().clamp(
                      1,
                      1000,
                    );
                    return Expanded(
                      flex: flex,
                      child: Container(color: c.$3),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
          ...categories.map((c) {
            final (label, icon, color, size) = c;
            if (size == 0) return const SizedBox.shrink();
            final percentage = totalSize > 0
                ? ((size / totalSize) * 100).toStringAsFixed(1)
                : '0';

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: Row(
                children: [
                  HugeIcon(icon: icon, color: color, size: 18),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      label,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    '$percentage%  •  ${formatSize(size)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
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
    final suggestions =
        <(String, String, List<List<dynamic>>, Color, String)>[];
    final videos = stats['Videos'] ?? 0;
    final images = stats['Images'] ?? 0;
    final other = stats['Other'] ?? 0;

    if (videos > 500 * 1024 * 1024) {
      suggestions.add((
        'Large Video Files',
        '${formatSize(videos)} in video files — review for cleanup',
        HugeIcons.strokeRoundedVideo01 as dynamic,
        AppColors.videos,
        '/large-files',
      ));
    }
    if (images > 200 * 1024 * 1024) {
      suggestions.add((
        'Image Collection',
        '${formatSize(images)} in images — check for duplicates',
        HugeIcons.strokeRoundedImage01 as dynamic,
        AppColors.images,
        '/gallery',
      ));
    }
    if (other > 100 * 1024 * 1024) {
      suggestions.add((
        'Other Files',
        '${formatSize(other)} in uncategorized files',
        HugeIcons.strokeRoundedFolder01 as dynamic,
        AppColors.other,
        '/browse',
      ));
    }

    if (suggestions.isEmpty) {
      return AppCard(
        child: Row(
          children: [
            const HugeIcon(
              icon: HugeIcons.strokeRoundedCheckmarkCircle02,
              color: AppColors.success,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                'No immediate cleanup suggestions. Storage is optimal!',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: suggestions.map((s) {
        final (title, subtitle, icon, color, route) = s;
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: AppCard(
            onTap: () {
              if (route == '/large-files') {
                context.push(route);
              } else {
                context.go(route);
              }
            },
            child: Row(
              children: [
                HugeIcon(icon: icon, color: color),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const HugeIcon(
                  icon: HugeIcons.strokeRoundedArrowRight01,
                  size: 18,
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  final List<List<dynamic>> icon;
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
    final theme = Theme.of(context);

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.md),
      color: color.withOpacity(0.1),
      borderColor: color.withOpacity(0.2),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.xs + 2),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: AppRadius.borderSm,
            ),
            child: HugeIcon(icon: icon, color: color, size: 20),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
