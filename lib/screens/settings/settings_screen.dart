import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/storage_provider.dart';
import '../../providers/scanner_provider.dart';
import '../../providers/rescue_provider.dart';
import '../../providers/advanced_scan_provider.dart';
import '../../services/notification_service.dart';
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
          _SectionHeader(label: 'Rescue Destination'),
          const _RescueDestinationSection(),
          const Divider(),
          _SectionHeader(label: 'Notifications'),
          const _UpdateNotificationsTile(),
          const Divider(),
          _SectionHeader(label: 'Navigation'),
          ListTile(
            leading: const Icon(Icons.data_usage),
            title: const Text('Large Files'),
            onTap: () => context.push('/large-files'),
          ),
          const Divider(),
          _SectionHeader(label: 'Advanced Scanning'),
          const _AdvancedScanningSection(),
          const Divider(),
          _SectionHeader(label: 'About'),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('About MediaRescue'),
            subtitle: const Text('Version, resources and links'),
            onTap: () => context.push('/about'),
          ),
          ListTile(
            leading: const Icon(Icons.lock_outline),
            title: const Text('Privacy Policy'),
            subtitle: const Text('How MediaRescue handles your data and notifications'),
            onTap: () => context.push('/privacy'),
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

/// Where rescued files are copied. Supports one folder for everything or a
/// separate folder per media type. Each destination can be edited freely.
class _RescueDestinationSection extends ConsumerWidget {
  const _RescueDestinationSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(rescueSettingsProvider);
    final notifier = ref.read(rescueSettingsProvider.notifier);

    final tiles = settings.singleDestination
        ? [
            _DestinationTile(
              icon: Icons.folder_special,
              title: 'Rescue folder',
              path: settings.singlePath,
              onEdit: () => _editDestination(
                  context, ref, 'Rescue folder', notifier.setSinglePath),
            ),
          ]
        : [
            _DestinationTile(
              icon: Icons.image_outlined,
              title: 'Images',
              path: settings.imagesPath,
              onEdit: () => _editDestination(
                  context, ref, 'Images destination', notifier.setImagesPath),
            ),
            _DestinationTile(
              icon: Icons.videocam_outlined,
              title: 'Videos',
              path: settings.videosPath,
              onEdit: () => _editDestination(
                  context, ref, 'Videos destination', notifier.setVideosPath),
            ),
            _DestinationTile(
              icon: Icons.audiotrack,
              title: 'Audio',
              path: settings.audioPath,
              onEdit: () => _editDestination(
                  context, ref, 'Audio destination', notifier.setAudioPath),
            ),
            _DestinationTile(
              icon: Icons.insert_drive_file_outlined,
              title: 'Other files',
              path: settings.otherPath,
              onEdit: () => _editDestination(context, ref,
                  'Other files destination', notifier.setOtherPath),
            ),
          ];

    return Column(
      children: [
        SwitchListTile(
          secondary: const Icon(Icons.category_outlined),
          title: const Text('Single destination for everything'),
          subtitle: const Text('Save all rescued files to one folder'),
          value: settings.singleDestination,
          onChanged: notifier.setSingleDestination,
        ),
        ...tiles,
        ListTile(
          leading: const Icon(Icons.restart_alt),
          title: const Text('Reset to Defaults'),
          onTap: () {
            notifier.resetToDefaults();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Rescue destinations reset to defaults.')),
            );
          },
        ),
      ],
    );
  }

  Future<void> _editDestination(
    BuildContext context,
    WidgetRef ref,
    String title,
    void Function(String) onSave,
  ) async {
    final settings = ref.read(rescueSettingsProvider);
    final current = title.startsWith('Rescue folder')
        ? settings.singlePath
        : title.startsWith('Images')
            ? settings.imagesPath
            : title.startsWith('Videos')
                ? settings.videosPath
                : title.startsWith('Audio')
                    ? settings.audioPath
                    : settings.otherPath;
    final saved = await showDialog<String>(
      context: context,
      builder: (ctx) => _DestinationDialog(title: title, current: current),
    );
    if (saved == null || saved.isEmpty) return;
    // Best-effort: make sure the folder exists before the first rescue.
    await ref.read(storageServiceProvider).createDirectory(saved);
    onSave(saved);
  }
}

String _displayPath(String path) {
  final prefix = '$defaultStorageRoot/';
  return path.startsWith(prefix) ? path.substring(prefix.length) : path;
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

class _DestinationTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String path;
  final VoidCallback onEdit;

  const _DestinationTile({
    required this.icon,
    required this.title,
    required this.path,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(
        _displayPath(path),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: const Icon(Icons.edit_outlined, size: 20),
      onTap: onEdit,
    );
  }
}

class _DestinationDialog extends StatefulWidget {
  final String title;
  final String current;

  const _DestinationDialog({required this.title, required this.current});

  @override
  State<_DestinationDialog> createState() => _DestinationDialogState();
}

class _DestinationDialogState extends State<_DestinationDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: _displayPath(widget.current),
  );

  static const List<String> _quickPicks = [
    'Pictures/MediaRescue',
    'Movies/MediaRescue',
    'Music/MediaRescue',
    'Documents/MediaRescue',
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    var value = _controller.text.trim();
    while (value.startsWith('/')) {
      value = value.substring(1);
    }
    while (value.endsWith('/')) {
      value = value.substring(0, value.length - 1);
    }
    if (value.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a folder path.')),
      );
      return;
    }
    Navigator.of(context).pop('$defaultStorageRoot/$value');
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            decoration: const InputDecoration(
              prefixText: '$defaultStorageRoot/',
              hintText: 'Pictures/MediaRescue',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (_) => _save(),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final pick in _quickPicks)
                ActionChip(
                  label: Text(pick, style: const TextStyle(fontSize: 12)),
                  onPressed: () => setState(() => _controller.text = pick),
                ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _save,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
/// Toggle for receiving MediaRescue update notifications (FCM topic
/// `mediarescue-updates`). Toggling on requests notification permission when
/// the system has not decided yet and subscribes to the topic; toggling off
/// unsubscribes. Denied permission never blocks normal app usage.
class _UpdateNotificationsTile extends StatefulWidget {
  const _UpdateNotificationsTile();

  @override
  State<_UpdateNotificationsTile> createState() =>
      _UpdateNotificationsTileState();
}

class _UpdateNotificationsTileState extends State<_UpdateNotificationsTile> {
  bool? _enabled;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final enabled = await NotificationService.areNotificationsEnabled();
    if (!mounted) return;
    setState(() => _enabled = enabled);
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _onChanged(bool value) async {
    if (value) {
      await NotificationService.requestPermissionIfNeeded();
    } else {
      await NotificationService.unsubscribe();
    }
    final enabled = await NotificationService.areNotificationsEnabled();
    if (!mounted) return;
    setState(() => _enabled = enabled);

    if (value && !enabled) {
      _showMessage(
        'Notifications are disabled for MediaRescue. Enable them in your '
        'device settings to receive update announcements.',
      );
    } else if (!value) {
      _showMessage('Update notifications turned off.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      secondary: const Icon(Icons.notifications_active_outlined),
      title: const Text('Update notifications'),
      subtitle: const Text(
        'Receive announcements when a new version is available '
        '(Firebase Cloud Messaging).',
      ),
            value: _enabled ?? false,
      onChanged: _enabled == null ? null : _onChanged,
    );
  }
}

/// Settings section for the OPTIONAL Shizuku-based Advanced Scanning feature.
///
/// Shows the live Shizuku status (re-read from the advanced scan controller),
/// and opens the Advanced Scanning screen or the setup guide.
class _AdvancedScanningSection extends ConsumerWidget {
  const _AdvancedScanningSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Re-evaluate status on every entry so the label is never stale after a
    // Shizuku restart / permission grant / revocation.
    ref.watch(advancedScanProvider);
    final status = ref.read(advancedScanProvider);
    final shizukuStatus = status.shizukuStatus;

    return Column(
      children: [
        ListTile(
          leading: const Icon(Icons.travel_explore),
          title: const Text('Advanced Scanning'),
          subtitle: Text(_statusLabel(shizukuStatus),
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          onTap: () => context.push('/advanced-scan'),
        ),
        ListTile(
          leading: const Icon(Icons.book_outlined),
          title: const Text('Shizuku Setup Guide'),
          subtitle: const Text('How to install, start and authorize Shizuku'),
          onTap: () => context.push('/shizuku-guide'),
        ),
      ],
    );
  }

    String _statusLabel(ShizukuStatus status) {
    return switch (status) {
      ShizukuStatus.authorized || ShizukuStatus.serviceConnected => 'Ready',
      ShizukuStatus.unavailable => 'Shizuku not installed',
      ShizukuStatus.binderNotReceived => 'Waiting for Shizuku connection',
      ShizukuStatus.binderDisconnected => 'Shizuku connection lost',
      ShizukuStatus.notRunning => 'Shizuku not running',
      ShizukuStatus.error => 'Error — tap to check',
      ShizukuStatus.unknown => 'Advanced Scanning',
      ShizukuStatus.permissionDenied => 'Permission denied',
      ShizukuStatus.waitingForPermission => 'Waiting for authorization',
    };
  }
}