import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/storage_provider.dart';
import '../../providers/scanner_provider.dart';
import '../../app/app.dart' show themeModeProvider;

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          _SectionHeader(label: 'Appearance'),
          _ThemeTile(
            label: 'System default',
            mode: ThemeMode.system,
            current: themeMode,
            ref: ref,
          ),
          _ThemeTile(
            label: 'Light',
            mode: ThemeMode.light,
            current: themeMode,
            ref: ref,
          ),
          _ThemeTile(
            label: 'Dark',
            mode: ThemeMode.dark,
            current: themeMode,
            ref: ref,
          ),
          const Divider(),
          _SectionHeader(label: 'Storage'),
          ListTile(
            leading: const Icon(Icons.security),
            title: const Text('Manage Storage Access'),
            subtitle: const Text('Open system settings for All files access'),
            onTap: () async {
              final storageService = ref.read(storageServiceProvider);
              await storageService.requestAccess();
            },
          ),
          ListTile(
            leading: const Icon(Icons.refresh),
            title: const Text('Rescan Storage'),
            subtitle: const Text('Re-index all accessible files'),
            onTap: () {
              ref.read(scanControllerProvider.notifier).startScan();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Rescanning storage...')),
              );
            },
          ),
          const Divider(),
          _SectionHeader(label: 'Navigation'),
          ListTile(
            leading: const Icon(Icons.data_usage),
            title: const Text('Large Files'),
            onTap: () => context.go('/large-files'),
          ),
          const Divider(),
          _SectionHeader(label: 'About'),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('Version'),
            subtitle: Text('1.0.1'),
          ),
          const ListTile(
            leading: Icon(Icons.lock_outline),
            title: Text('Privacy'),
            subtitle: Text('All files stay on your device. Nothing is uploaded.'),
          ),
        ],
      ),
    );
  }
}

class _ThemeTile extends StatelessWidget {
  final String label;
  final ThemeMode mode;
  final ThemeMode current;
  final WidgetRef ref;

  const _ThemeTile({
    required this.label,
    required this.mode,
    required this.current,
    required this.ref,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(label),
      leading: Icon(
        current == mode ? Icons.radio_button_checked : Icons.radio_button_unchecked,
        color: current == mode ? Theme.of(context).colorScheme.primary : null,
      ),
      onTap: () => ref.read(themeModeProvider.notifier).set(mode),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Text(
        label.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
      ),
    );
  }
}