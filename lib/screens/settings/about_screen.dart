import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../services/link_service.dart';

/// About page: application info, version and links to the project resources.
/// Reachable via Settings → About.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: ListView(
        children: [
          const SizedBox(height: 32),
          // ── App identity ───────────────────────────────────────────────
          Column(
            children: [
              Image(image:  
              AssetImage('assets/images/icon.png'), width: 96, height: 96),
              const SizedBox(height: 16),
              Text('MediaRescue', style: theme.textTheme.headlineMedium),
              const SizedBox(height: 4),
              const _AppVersion(),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  'MediaRescue helps you find, browse, preview, and manage '
                  'media and files stored on your Android device.',
                  style: theme.textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Divider(),
          const _SectionHeader(label: 'Resources'),
          ListTile(
            leading: const Icon(Icons.code),
            title: const Text('GitHub'),
            subtitle: const Text(LinkService.githubUrl),
            onTap: () async {
              final ok = await LinkService.openUrl(LinkService.githubUrl);
              if (!ok && context.mounted) {
                _showOpenFailed(context);
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('Privacy Policy'),
            subtitle: const Text('Read how MediaRescue handles your data'),
            onTap: () => context.push('/privacy'),
          ),
          ListTile(
            leading: const Icon(Icons.mail_outline),
            title: const Text('Contact'),
            subtitle: const Text('Get help or share feedback'),
            onTap: () => context.push('/contact'),
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
        return Text(
          version == null ? 'Version …' : 'Version $version',
          style: theme.textTheme.bodyMedium
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        );
      },
    );
  }
}

final Future<PackageInfo> _packageInfo = PackageInfo.fromPlatform();

class _SectionHeader extends StatelessWidget {
  final String label;

  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.bold,
          fontSize: 12,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}