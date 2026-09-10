import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../app/app.dart' show themeModeProvider;
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../providers/advanced_scan_provider.dart';
import '../../providers/rescue_provider.dart';
import '../../providers/scanner_provider.dart';
import '../../providers/storage_provider.dart';
import '../../services/notification_service.dart';
import '../../widgets/app_card.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: AppSpacing.pagePadding,
        children: [
          const _SectionHeader(label: 'Appearance'),
          const SizedBox(height: AppSpacing.sm),
          AppCard(
            child: Column(
              children: [
                _ThemeTile(
                  label: 'System default',
                  mode: ThemeMode.system,
                  current: themeMode,
                  ref: ref,
                ),
                const Divider(),
                _ThemeTile(
                  label: 'Light mode',
                  mode: ThemeMode.light,
                  current: themeMode,
                  ref: ref,
                ),
                const Divider(),
                _ThemeTile(
                  label: 'Dark mode',
                  mode: ThemeMode.dark,
                  current: themeMode,
                  ref: ref,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),

          const _SectionHeader(label: 'Storage & Access'),
          const SizedBox(height: AppSpacing.sm),
          AppCard(
            child: Column(
              children: [
                ListTile(
                  leading: const HugeIcon(
                    icon: HugeIcons.strokeRoundedShieldPlus,
                    color: AppColors.primary,
                  ),
                  title: const Text('Manage Storage Access'),
                  subtitle: const Text(
                    'Open system settings for All files access',
                  ),
                  onTap: () async {
                    final storageService = ref.read(storageServiceProvider);
                    await storageService.requestAccess();
                  },
                ),
                const Divider(),
                ListTile(
                  leading: const HugeIcon(
                    icon: HugeIcons.strokeRoundedRefresh,
                    color: AppColors.secondary,
                  ),
                  title: const Text('Rescan Storage'),
                  subtitle: const Text('Re-index all accessible media files'),
                  onTap: () {
                    ref.read(scanControllerProvider.notifier).startScan();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Rescanning storage...')),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),

          const _SectionHeader(label: 'Rescue Destination'),
          const SizedBox(height: AppSpacing.sm),
          const AppCard(child: _RescueDestinationSection()),
          const SizedBox(height: AppSpacing.xl),

          const _SectionHeader(label: 'Notifications'),
          const SizedBox(height: AppSpacing.sm),
          const AppCard(child: _UpdateNotificationsTile()),
          const SizedBox(height: AppSpacing.xl),

          const _SectionHeader(label: 'Specialized Discovery'),
          const SizedBox(height: AppSpacing.sm),
          AppCard(
            child: Column(
              children: [
                ListTile(
                  leading: const HugeIcon(
                    icon: HugeIcons.strokeRoundedHardDrive,
                    color: AppColors.documents,
                  ),
                  title: const Text('Large Files'),
                  subtitle: const Text(
                    'Filter and manage large storage consumers',
                  ),
                  onTap: () => context.push('/large-files'),
                ),
                const Divider(),
                const _AdvancedScanningSection(),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),

          const _SectionHeader(label: 'About & Information'),
          const SizedBox(height: AppSpacing.sm),
          AppCard(
            child: Column(
              children: [
                ListTile(
                  leading: const HugeIcon(
                    icon: HugeIcons.strokeRoundedInformationCircle,
                    color: AppColors.primary,
                  ),
                  title: const Text('About MediaRescue'),
                  subtitle: const Text('Version, resources and credits'),
                  onTap: () => context.push('/about'),
                ),
                const Divider(),
                ListTile(
                  leading: const HugeIcon(
                    icon: HugeIcons.strokeRoundedMail01,
                    color: AppColors.secondary,
                  ),
                  title: const Text('Contact Support'),
                  subtitle: const Text('Send feedback or report issues'),
                  onTap: () => context.push('/contact'),
                ),
                const Divider(),
                ListTile(
                  leading: const HugeIcon(
                    icon: HugeIcons.strokeRoundedLock,
                    color: AppColors.other,
                  ),
                  title: const Text('Privacy Policy'),
                  subtitle: const Text('How MediaRescue handles your data'),
                  onTap: () => context.push('/privacy'),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: Theme.of(context).colorScheme.primary,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.2,
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
    final isSelected = current == mode;
    return ListTile(
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      leading: Icon(
        isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
        color: isSelected ? Theme.of(context).colorScheme.primary : null,
      ),
      onTap: () => ref.read(themeModeProvider.notifier).set(mode),
    );
  }
}

class _RescueDestinationSection extends ConsumerWidget {
  const _RescueDestinationSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(rescueSettingsProvider);
    final notifier = ref.read(rescueSettingsProvider.notifier);

    final tiles = settings.singleDestination
        ? [
            _DestinationTile(
              icon: HugeIcons.strokeRoundedFolder01,
              title: 'Rescue folder',
              path: settings.singlePath,
              onEdit: () => _editDestination(
                context,
                ref,
                'Rescue folder',
                notifier.setSinglePath,
              ),
            ),
          ]
        : [
            _DestinationTile(
              icon: HugeIcons.strokeRoundedImage01,
              title: 'Images',
              path: settings.imagesPath,
              onEdit: () => _editDestination(
                context,
                ref,
                'Images destination',
                notifier.setImagesPath,
              ),
            ),
            _DestinationTile(
              icon: HugeIcons.strokeRoundedVideo01,
              title: 'Videos',
              path: settings.videosPath,
              onEdit: () => _editDestination(
                context,
                ref,
                'Videos destination',
                notifier.setVideosPath,
              ),
            ),
            _DestinationTile(
              icon: HugeIcons.strokeRoundedMusicNote01,
              title: 'Audio',
              path: settings.audioPath,
              onEdit: () => _editDestination(
                context,
                ref,
                'Audio destination',
                notifier.setAudioPath,
              ),
            ),
            _DestinationTile(
              icon: HugeIcons.strokeRoundedFile01,
              title: 'Other files',
              path: settings.otherPath,
              onEdit: () => _editDestination(
                context,
                ref,
                'Other files destination',
                notifier.setOtherPath,
              ),
            ),
          ];

    return Column(
      children: [
        SwitchListTile(
          secondary: const HugeIcon(icon: HugeIcons.strokeRoundedFourSquare),
          title: const Text('Single folder for all rescues'),
          subtitle: const Text('Save all rescued files into one directory'),
          value: settings.singleDestination,
          onChanged: notifier.setSingleDestination,
        ),
        const Divider(),
        ...tiles,
        const Divider(),
        ListTile(
          leading: const HugeIcon(
            icon: HugeIcons.strokeRoundedRefresh,
            color: AppColors.error,
          ),
          title: const Text('Reset Destinations'),
          onTap: () {
            notifier.resetToDefaults();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Rescue destinations reset to defaults.'),
              ),
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
    await ref.read(storageServiceProvider).createDirectory(saved);
    onSave(saved);
  }
}

String _displayPath(String path) {
  final prefix = '$defaultStorageRoot/';
  return path.startsWith(prefix) ? path.substring(prefix.length) : path;
}

class _DestinationTile extends StatelessWidget {
  final List<List<dynamic>> icon;
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
      leading: HugeIcon(
        icon: icon,
        color: Theme.of(context).colorScheme.primary,
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(
        _displayPath(path),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: const HugeIcon(icon: HugeIcons.strokeRoundedEdit02, size: 18),
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
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
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
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}

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

  void _refresh() {
    final subscribed = NotificationService.isSubscribed;
    if (!mounted) return;
    setState(() => _enabled = subscribed);
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _onChanged(bool value) async {
    if (value) {
      final permitted = await NotificationService.areNotificationsEnabled();
      if (!permitted) {
        await NotificationService.requestPermissionIfNeeded();
      }
      if (NotificationService.isSubscribed ||
          await NotificationService.areNotificationsEnabled()) {
        await NotificationService.subscribe();
      }
    } else {
      await NotificationService.unsubscribe();
    }
    if (!mounted) return;
    setState(() => _enabled = NotificationService.isSubscribed);

    if (value && !NotificationService.isSubscribed) {
      _showMessage(
        'Notifications are disabled for MediaRescue in system settings.',
      );
    } else if (value) {
      _showMessage('Update notifications turned on.');
    } else {
      _showMessage('Update notifications turned off.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      secondary: const HugeIcon(icon: HugeIcons.strokeRoundedNotification01),
      title: const Text('Update notifications'),
      subtitle: const Text(
        'Receive announcements when a new version is released',
      ),
      value: _enabled ?? false,
      onChanged: _enabled == null ? null : _onChanged,
    );
  }
}

class _AdvancedScanningSection extends ConsumerWidget {
  const _AdvancedScanningSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(advancedScanProvider);
    final status = ref.read(advancedScanProvider);
    final shizukuStatus = status.shizukuStatus;

    return Column(
      children: [
        ListTile(
          leading: const HugeIcon(
            icon: HugeIcons.strokeRoundedCpu,
            color: AppColors.primary,
          ),
          title: const Text('Advanced Scanning'),
          subtitle: Text(_statusLabel(shizukuStatus)),
          onTap: () => context.push('/advanced-scan'),
        ),
        const Divider(),
        ListTile(
          leading: const HugeIcon(
            icon: HugeIcons.strokeRoundedHelpCircle,
            color: AppColors.secondary,
          ),
          title: const Text('Shizuku Setup Guide'),
          subtitle: const Text('How to setup Shizuku service'),
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
