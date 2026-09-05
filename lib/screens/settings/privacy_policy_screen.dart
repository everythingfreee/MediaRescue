import 'package:flutter/material.dart';

import '../../services/link_service.dart';

/// Privacy Policy page: a short, accurate in-app summary plus a link to the
/// full canonical policy hosted by the project.
/// Reachable via Settings → About → Privacy Policy.
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Privacy Policy')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
        children: [
          Text(
            'Privacy Policy',
            style: theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          Text(
            'MediaRescue is an offline-first file manager. This summary '
            'describes how the application handles your data. The full, '
            'canonical policy is linked below.',
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(height: 24),
          const _PolicyItem(
            icon: Icons.folder_outlined,
            title: 'Storage & file access',
            body:
                'MediaRescue asks for full access to your device storage so it '
                'can scan folders and manage your media files. Granting (or '
                'revoking) this access is controlled entirely by you in the '
                'Android system settings.',
          ),
          const _PolicyItem(
            icon: Icons.manage_search,
            title: 'Local scanning & processing',
            body:
                'Storage scanning, thumbnails, previews, large-file detection '
                'and file operations all run locally on your device. MediaRescue '
                'does not upload your media files anywhere, and it does not share '
                'or sell your personal data.',
          ),
          const _PolicyItem(
            icon: Icons.notifications_active_outlined,
            title: 'Notifications & Firebase Cloud Messaging',
            body:
                'With your permission, MediaRescue uses Firebase Cloud '
                'Messaging to announce new releases. For this to work the app '
                'communicates with Google\'s Firebase servers to receive update '
                'notifications — no media or personal files are involved. You '
                'can enable or disable these notifications at any time from '
                'Settings, or in the Android notification settings.',
          ),
          const _PolicyItem(
            icon: Icons.storefront,
            title: 'Google Play',
            body:
                'MediaRescue checks Google Play for newer versions and can '
                'install updates through Google Play\'s official In-App Updates. '
                'The store handles the download and installation. Update checks '
                'are optional and never required for the app to work.',
          ),
          const _PolicyItem(
            icon: Icons.handshake_outlined,
            title: 'Third-party services & data sharing',
            body:
                'The only third-party services used are Google\'s Firebase and '
                'Google Play, strictly for notifications and updates. MediaRescue '
                'operates no backend, has no accounts, and stores none of your '
                'files on any server.',
          ),
          const _PolicyItem(
            icon: Icons.tune,
            title: 'Your controls',
            body:
                'You control storage access, notification permission and '
                'update notifications directly in the app and in the Android '
                'settings. The app continues to work normally regardless of '
                'which of these you disable.',
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () async {
              final ok = await LinkService.openUrl(LinkService.privacyPolicyUrl);
              if (!ok && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'No application is available to open this link.',
                    ),
                  ),
                );
              }
            },
            icon: const Icon(Icons.open_in_new),
            label: const Text('Read Full Privacy Policy'),
          ),
          const SizedBox(height: 8),
          Text(
            LinkService.privacyPolicyUrl,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _PolicyItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  const _PolicyItem({
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(body, style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}