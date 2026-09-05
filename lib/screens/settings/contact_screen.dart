import 'package:flutter/material.dart';

import '../../services/link_service.dart';

/// Contact page: official support email and GitHub repository links.
/// Reachable via Settings → About → Contact.
class ContactScreen extends StatelessWidget {
  const ContactScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Contact')),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
            child: Text(
              'Questions, feedback or a bug to report? MediaRescue is an '
              'open-source project — reach out any time.',
              style: theme.textTheme.bodyLarge,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Text(
                          LinkService.contactEmail,
                          style: theme.textTheme.titleMedium,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: () async {
                            final ok = await LinkService.openEmailCompose();
                            if (!ok && context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'No email application is available on '
                                    'this device.',
                                  ),
                                ),
                              );
                            }
                          },
                          icon: const Icon(Icons.mail_outline),
                          label: const Text('Email Us'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 32),
          const _SectionHeader(label: 'Project'),
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
            leading: const Icon(Icons.bug_report_outlined),
            title: const Text('Report an Issue'),
            subtitle: const Text(LinkService.githubIssuesUrl),
            onTap: () async {
              final ok = await LinkService.openUrl(LinkService.githubIssuesUrl);
              if (!ok && context.mounted) {
                _showOpenFailed(context);
              }
            },
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