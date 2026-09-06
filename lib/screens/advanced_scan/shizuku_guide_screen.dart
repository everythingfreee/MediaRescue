import 'package:flutter/material.dart';

import '../../services/link_service.dart';

/// In-app, text-based Shizuku setup guide (no video yet — the architecture
/// reserves a section for a future video without redesigning the screen).
///
/// Shizuku is a third-party, free and open-source tool by RikkaApps. It is
/// entirely optional for MediaRescue. The guide never claims Shizuku grants
/// root access: it provides an elevated execution mechanism whose access
/// level depends on how it was started and on the Android version.
class ShizukuGuideScreen extends StatelessWidget {
  const ShizukuGuideScreen({super.key});

  static const _steps = <(String, String)>[
    (
      'Install Shizuku',
      'Install Shizuku from its official source — the Google Play Store or '
          'the official GitHub releases. MediaRescue never bundles or '
          'installs Shizuku for you.',
    ),
    (
      'Open Shizuku',
      'Launch the Shizuku app once it is installed.',
    ),
    (
      'Enable Developer options',
      'If your device does not have Developer options enabled yet, Shizuku '
          'will show you how to enable them in your device settings.',
    ),
    (
      'Enable Wireless debugging',
      'On Android 11 and above, enable Wireless debugging (Developer options '
          '→ Wireless debugging). On older Android versions you need a '
          'computer with adb to start Shizuku instead.',
    ),
    (
      'Pair Shizuku',
      'Follow Shizuku\u2019s pairing process — enter the wireless debugging '
          'pairing code when prompted. This is a one-time step.',
    ),
    (
      'Start the Shizuku service',
      'Press "Start" inside the Shizuku app. Shizuku must be started again '
          'after every device reboot on non-rooted devices.',
    ),
    (
      'Return to MediaRescue',
      'Come back to MediaRescue. The Advanced Scanning screen detects a '
          'running Shizuku service automatically.',
    ),
    (
      'Grant MediaRescue authorization',
      'When prompted (or via Settings → Advanced Scanning), allow '
          'MediaRescue to use Shizuku. You can revoke this at any time in '
          'the Shizuku app.',
    ),
    (
      'Start Advanced Scanning',
      'Open Advanced Scanning from the Home screen and press "Start Advanced '
          'Scan" to read Android/data and Android/obb.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Shizuku Setup Guide')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _IntroCard(theme: theme),
          const SizedBox(height: 8),
          ..._steps.indexed.map((step) {
            final (index, (title, body)) = step;
            return _StepCard(index: index + 1, title: title, body: body);
          }),
          const SizedBox(height: 8),
          const _OfficialSourcesCard(),
          const SizedBox(height: 8),
          const _VideoPlaceholderCard(),
          const SizedBox(height: 24),
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.travel_explore, color: theme.colorScheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'What is Shizuku?',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Shizuku is a free, open-source tool that lets apps perform a '
              'few extra read operations with an elevated execution '
              'mechanism — it is not root and does not require root. Android '
              'normally hides the app-private folders Android/data and '
              'Android/obb from other apps; with Shizuku running, '
              'MediaRescue can list those two folders so nothing on your '
              'phone stays invisible.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Shizuku is completely optional — every other MediaRescue '
              'feature works normally without it. All scanning is read-only '
              'and stays on your device.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
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
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          radius: 14,
          backgroundColor: theme.colorScheme.primaryContainer,
          child: Text(
            '$index',
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
        ),
        title: Text(
          title,
          style:
              theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(body, style: theme.textTheme.bodySmall),
      ),
    );
  }
}

class _OfficialSourcesCard extends StatelessWidget {
  const _OfficialSourcesCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Official sources',
              style:
                  theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.shop_outlined),
              title: const Text('Shizuku on Google Play (official)'),
              subtitle: const Text('moe.shizuku.privileged.api'),
              trailing: const Icon(Icons.open_in_new, size: 18),
              onTap: () async {
                final ok = await LinkService.openShizukuPlayStore();
                if (!ok && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Could not open the Play Store.')),
                  );
                }
              },
            ),
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.code),
              title: const Text('Shizuku on GitHub (official)'),
              subtitle: const Text('github.com/RikkaApps/Shizuku'),
              trailing: const Icon(Icons.open_in_new, size: 18),
              onTap: () async {
                final ok = await LinkService.openUrl(LinkService.shizukuGitHubUrl);
                if (!ok && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Could not open the browser.')),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Reserved for a future video tutorial — the text guide above is fully
/// usable on its own and this section requires no redesign to extend.
class _VideoPlaceholderCard extends StatelessWidget {
  const _VideoPlaceholderCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(Icons.videocam_outlined, size: 40, color: theme.colorScheme.outline),
            const SizedBox(height: 8),
            Text(
              'Video Guide',
              style:
                  theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Video tutorial coming soon.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}