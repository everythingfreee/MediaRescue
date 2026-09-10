import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../services/link_service.dart';
import '../../widgets/app_card.dart';

class ShizukuGuideScreen extends StatelessWidget {
  const ShizukuGuideScreen({super.key});

  static const _steps = <(String, String)>[
    (
      'Install Shizuku',
      'Install Shizuku from its official source — Google Play Store or GitHub releases. MediaRescue never bundles or installs Shizuku.',
    ),
    ('Open Shizuku', 'Launch the Shizuku app once installed.'),
    (
      'Enable Developer options',
      'If Developer options are not enabled yet, Shizuku guides you in your device settings.',
    ),
    (
      'Enable Wireless debugging',
      'On Android 11 and above, enable Wireless debugging (Developer options → Wireless debugging). On older Android versions use adb via PC.',
    ),
    (
      'Pair Shizuku',
      'Enter the wireless debugging pairing code when prompted inside Shizuku.',
    ),
    (
      'Start the Shizuku service',
      'Press "Start" in the Shizuku app. Re-start after device reboots.',
    ),
    (
      'Return to MediaRescue',
      'Come back to MediaRescue. Advanced Scanning automatically detects a running Shizuku service.',
    ),
    (
      'Grant MediaRescue authorization',
      'When prompted, allow MediaRescue to use Shizuku. Revoke anytime in Shizuku.',
    ),
    (
      'Start Advanced Scanning',
      'Press "Start Advanced Scan" on the Advanced Scanning screen.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Shizuku Setup Guide')),
      body: ListView(
        padding: AppSpacing.pagePadding,
        children: [
          _IntroCard(theme: theme),
          const SizedBox(height: AppSpacing.md),
          ..._steps.indexed.map((step) {
            final (index, (title, body)) = step;
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _StepCard(index: index + 1, title: title, body: body),
            );
          }),
          const SizedBox(height: AppSpacing.md),
          const _OfficialSourcesCard(),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }
}

class _IntroCard extends StatelessWidget {
  final ThemeData theme;

  const _IntroCard({required this.theme});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              HugeIcon(
                icon: HugeIcons.strokeRoundedHelpCircle,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'What is Shizuku?',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Shizuku is a free, open-source tool that allows apps to perform extra read operations without requiring root access. With Shizuku, MediaRescue can list Android/data and Android/obb folders so no files remain hidden.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Shizuku is completely optional — all standard scanning and rescue features work normally without it.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  final int index;
  final String title;
  final String body;

  const _StepCard({
    required this.index,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$index',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(body, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OfficialSourcesCard extends StatelessWidget {
  const _OfficialSourcesCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Official Sources',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const HugeIcon(
              icon: HugeIcons.strokeRoundedPlayStore,
              color: AppColors.primary,
            ),
            title: const Text('Shizuku on Google Play (Official)'),
            subtitle: const Text('moe.shizuku.privileged.api'),
            trailing: const HugeIcon(
              icon: HugeIcons.strokeRoundedLinkSquare02,
              size: 18,
            ),
            onTap: () async {
              final ok = await LinkService.openShizukuPlayStore();
              if (!ok && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Could not open the Play Store.'),
                  ),
                );
              }
            },
          ),
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const HugeIcon(
              icon: HugeIcons.strokeRoundedCode,
              color: AppColors.secondary,
            ),
            title: const Text('Shizuku on GitHub (Official)'),
            subtitle: const Text('github.com/RikkaApps/Shizuku'),
            trailing: const HugeIcon(
              icon: HugeIcons.strokeRoundedLinkSquare02,
              size: 18,
            ),
            onTap: () async {
              final ok = await LinkService.openUrl(
                LinkService.shizukuGitHubUrl,
              );
              if (!ok && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Could not open browser.')),
                );
              }
            },
          ),
        ],
      ),
    );
  }
}
