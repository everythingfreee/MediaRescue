import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../services/link_service.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';

class ContactScreen extends StatelessWidget {
  const ContactScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Contact')),
      body: ListView(
        padding: AppSpacing.pagePadding,
        children: [
          Text(
            'Questions, feedback or a bug report? MediaRescue is an open-source project — reach out any time.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppCard(
            child: Column(
              children: [
                const HugeIcon(icon: HugeIcons.strokeRoundedMail01, size: 48, color: AppColors.primary),
                const SizedBox(height: AppSpacing.md),
                Text(
                  LinkService.contactEmail,
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.md),
                AppButton(
                  label: 'Send Email',
                  icon: const HugeIcon(icon: HugeIcons.strokeRoundedMail01, color: Colors.white),
                  onPressed: () async {
                    final ok = await LinkService.openEmailCompose();
                    if (!ok && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('No email application is available on this device.'),
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            'PROJECT LINKS',
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
                  leading: const HugeIcon(icon: HugeIcons.strokeRoundedBug01, color: AppColors.error),
                  title: const Text('Report an Issue'),
                  subtitle: const Text(LinkService.githubIssuesUrl),
                  trailing: const HugeIcon(icon: HugeIcons.strokeRoundedLinkSquare02, size: 18),
                  onTap: () async {
                    final ok = await LinkService.openUrl(LinkService.githubIssuesUrl);
                    if (!ok && context.mounted) {
                      _showOpenFailed(context);
                    }
                  },
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