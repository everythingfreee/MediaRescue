import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_radius.dart';
import '../../app/theme/app_spacing.dart';
import '../../services/link_service.dart';
import '../../widgets/app_card.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: ListView(
        padding: AppSpacing.pagePadding,
        children: [
          const SizedBox(height: AppSpacing.md),
          Column(
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.12),
                  borderRadius: AppRadius.borderLg,
                ),
                clipBehavior: Clip.antiAlias,
                child: Image.asset('assets/images/icon.png', fit: BoxFit.cover),
              ),
              const SizedBox(height: AppSpacing.md),
              Text('MediaRescue', style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: AppSpacing.xs),
              const _AppVersion(),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Find, browse, preview, and manage media and files stored on your Android device.',
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            'RESOURCES & LINKS',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          AppCard(
            child: Column(
              children: [
                ListTile(
                  leading: const HugeIcon(icon: HugeIcons.strokeRoundedCode, color: AppColors.primary),
                  title: const Text('GitHub Repository'),
                  subtitle: const Text(LinkService.githubUrl),
                  trailing: const HugeIcon(icon: HugeIcons.strokeRoundedLinkSquare02, size: 18),
                  onTap: () async {
                    final ok = await LinkService.openUrl(LinkService.githubUrl);
                    if (!ok && context.mounted) {
                      _showOpenFailed(context);
                    }
                  },
                ),
                const Divider(),
                ListTile(
                  leading: const HugeIcon(icon: HugeIcons.strokeRoundedLock, color: AppColors.secondary),
                  title: const Text('Privacy Policy'),
                  subtitle: const Text('Read how MediaRescue handles your data'),
                  trailing: const HugeIcon(icon: HugeIcons.strokeRoundedArrowRight01, size: 18),
                  onTap: () => context.push('/privacy'),
                ),
                const Divider(),
                ListTile(
                  leading: const HugeIcon(icon: HugeIcons.strokeRoundedMail01, color: AppColors.other),
                  title: const Text('Contact Support'),
                  subtitle: const Text('Get help or share feedback'),
                  trailing: const HugeIcon(icon: HugeIcons.strokeRoundedArrowRight01, size: 18),
                  onTap: () => context.push('/contact'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showOpenFailed(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('No application is available to open this link.'),
      ),
    );
  }
}

class _AppVersion extends StatelessWidget {
  const _AppVersion();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FutureBuilder<PackageInfo>(
      future: _packageInfo,
      builder: (context, snapshot) {
        final version = snapshot.data?.version;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer.withOpacity(0.5),
            borderRadius: AppRadius.borderPill,
          ),
          child: Text(
            version == null ? 'Version …' : 'v$version',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
      },
    );
  }
}

final Future<PackageInfo> _packageInfo = PackageInfo.fromPlatform();