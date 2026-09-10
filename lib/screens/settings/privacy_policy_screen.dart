import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../services/link_service.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Privacy Policy')),
      body: ListView(
        padding: AppSpacing.pagePadding,
        children: [
          Text(
            'MediaRescue Privacy Summary',
            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'MediaRescue is an offline-first file management application. All scanning and media processing operations execute locally on your device.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          const _PolicyCard(
            icon: HugeIcons.strokeRoundedFolder01,
            title: 'Storage & file access',
            body:
                'MediaRescue asks for full access to your device storage so it can index folders and manage media. Access permissions are controlled entirely by you via Android system settings.',
          ),
          const SizedBox(height: AppSpacing.md),
          const _PolicyCard(
            icon: HugeIcons.strokeRoundedSearch01,
            title: 'Local scanning & processing',
            body:
                'All file indexing, thumbnail generation, large-file detection, and rescue file copies run offline on device. MediaRescue does not upload or sell your personal files.',
          ),
          const SizedBox(height: AppSpacing.md),
          const _PolicyCard(
            icon: HugeIcons.strokeRoundedNotification01,
            title: 'Notifications & Firebase Cloud Messaging',
            body:
                'With your explicit permission, MediaRescue uses Firebase Cloud Messaging to announce update releases. No personal files are ever transmitted.',
          ),
          const SizedBox(height: AppSpacing.md),
          const _PolicyCard(
            icon: HugeIcons.strokeRoundedStore01,
            title: 'Google Play In-App Updates',
            body:
                'MediaRescue checks Google Play for updates via official APIs. Google Play manages download and installation.',
          ),
          const SizedBox(height: AppSpacing.xl),
          AppButton(
            label: 'Read Full Privacy Policy Online',
            icon: const HugeIcon(icon: HugeIcons.strokeRoundedLinkSquare02, color: Colors.white),
            onPressed: () async {
              final ok = await LinkService.openUrl(LinkService.privacyPolicyUrl);
              if (!ok && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('No application is available to open this link.'),
                  ),
                );
              }
            },
            isFullWidth: true,
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }
}

class _PolicyCard extends StatelessWidget {
  final List<List<dynamic>> icon;
  final String title;
  final String body;

  const _PolicyCard({
    required this.icon,
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
          HugeIcon(icon: icon, color: AppColors.primary, size: 22),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: AppSpacing.xs),
                Text(body, style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}