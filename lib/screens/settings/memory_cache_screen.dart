import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_radius.dart';
import '../../app/theme/app_spacing.dart';
import '../../services/memory_service.dart';
import '../../services/notification_service.dart';
import '../../widgets/app_badge.dart';
import '../../widgets/app_card.dart';
import '../../widgets/media_info_sheet.dart' show formatBytes, formatDate;

/// Developer inspector for the metadata MediaRescue caches locally for Memory
/// notifications.
///
/// It shows exactly what the Memory system keeps on device — path, media type,
/// creation/caching dates, the cached artwork and the notification bookkeeping —
/// so the notification pipeline can be verified without a debugger attached.
/// Reachable from Settings → Developer (debug builds only).
///
/// Everything listed here is local device data; nothing is uploaded.
class MemoryCacheScreen extends StatefulWidget {
  const MemoryCacheScreen({super.key});

  @override
  State<MemoryCacheScreen> createState() => _MemoryCacheScreenState();
}

class _MemoryCacheScreenState extends State<MemoryCacheScreen> {
  List<MemoryEntry> _entries = const <MemoryEntry>[];
  int _cacheBytes = 0;
  bool _loading = true;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final entries = await MemoryService.debugEntries();
    final bytes = await MemoryService.debugCacheBytes();
    if (!mounted) return;
    setState(() {
      _entries = entries;
      _cacheBytes = bytes;
      _loading = false;
    });
  }

  Future<void> _sendTestNotification() async {
    if (_sending) return;
    setState(() => _sending = true);

    final permitted = await NotificationService.areNotificationsEnabled();
    final entry = permitted ? await MemoryService.sendTestNotification() : null;

    if (!mounted) return;
    setState(() => _sending = false);
    await _load();
    if (!mounted) return;

    final message = !permitted
        ? 'Notifications are disabled for MediaRescue in system settings.'
        : entry == null
        ? 'Nothing could be sent — no cached media is still on disk.'
        : 'Test Memory notification sent for a random pick: "${entry.name}".';
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _showEntryDetails(MemoryEntry entry) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (sheetContext) => _MemoryEntrySheet(entry: entry),
    );
  }

  /// Empty-state / list / loading placeholder for the cache entries.
  List<Widget> _buildEntryList(ThemeData theme) {
    if (_loading) {
      return const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: AppSpacing.xxl),
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }
    if (_entries.isEmpty) {
      return [
        AppCard(
          child: Column(
            children: [
              const HugeIcon(
                icon: HugeIcons.strokeRoundedViewOff,
                color: AppColors.other,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'No memories cached yet',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Open Hidden Media once so MediaRescue can cache the metadata '
                'of your hidden images, videos and audio files.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ];
    }
    return [
      const _SectionLabel(label: 'Entries'),
      const SizedBox(height: AppSpacing.sm),
      for (final entry in _entries) ...[
        _MemoryEntryTile(entry: entry, onTap: () => _showEntryDetails(entry)),
        const SizedBox(height: AppSpacing.sm),
      ],
    ];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final withArtwork = _entries
        .where((entry) => entry.thumbnail?.isNotEmpty == true)
        .length;
    final dated = _entries.where((entry) => entry.creationDate > 0).length;
    final resolved = _entries.where((entry) => entry.dateResolved).length;
    final missing = _entries
        .where((entry) => !File(entry.path).existsSync())
        .length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Memory cache'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Reload cached metadata',
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      body: ListView(
        padding: AppSpacing.pagePadding,
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const HugeIcon(
                      icon: HugeIcons.strokeRoundedInformationCircle,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      'Developer tool',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'The metadata MediaRescue caches on this device for Memory '
                  'notifications. Use it to verify the notification pipeline: '
                  'cache → random test pick → artwork → tap → player. '
                  'Nothing here leaves your device.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          _SectionLabel(label: 'Cached memories (${_entries.length})'),
          const SizedBox(height: AppSpacing.sm),
          AppCard(
            child: Column(
              children: [
                _StatRow(
                  icon: HugeIcons.strokeRoundedLocker01,
                  label: 'Entries cached',
                  value: '${_entries.length}',
                ),
                const Divider(height: AppSpacing.xl),
                _StatRow(
                  icon: HugeIcons.strokeRoundedImage01,
                  label: 'With cached artwork',
                  value: '$withArtwork',
                ),
                const Divider(height: AppSpacing.xl),
                _StatRow(
                  icon: HugeIcons.strokeRoundedSecurityCheck,
                  label: 'Creation dates resolved',
                  value: '$resolved of $dated dated',
                ),
                const Divider(height: AppSpacing.xl),
                _StatRow(
                  icon: HugeIcons.strokeRoundedAlertCircle,
                  label: 'Files no longer on disk',
                  value: '$missing',
                ),
                const Divider(height: AppSpacing.xl),
                _StatRow(
                  icon: HugeIcons.strokeRoundedHardDrive,
                  label: 'Cache size on disk',
                  value: formatBytes(_cacheBytes),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          AppCard(
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: _sending
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const HugeIcon(
                      icon: HugeIcons.strokeRoundedNotification01,
                      color: AppColors.primary,
                    ),
              title: const Text('Send test Memory notification'),
              subtitle: const Text(
                'Random cached media — never the same pick twice in a row',
              ),
              onTap: _sending ? null : _sendTestNotification,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          ..._buildEntryList(theme),
        ],
      ),
    );
  }
}

/// Small section label used between the developer cards.
class _SectionLabel extends StatelessWidget {
  final String label;

  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      label.toUpperCase(),
      style: theme.textTheme.labelSmall?.copyWith(
        fontWeight: FontWeight.bold,
        letterSpacing: 1.1,
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}

/// One label/value row inside the cache summary card.
class _StatRow extends StatelessWidget {
  final List<List<dynamic>> icon;
  final String label;
  final String value;

  const _StatRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        HugeIcon(icon: icon, size: 20, color: AppColors.primary),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

/// Accent colour + icon used for a cached media type.
Color _typeColor(String mediaType) => switch (mediaType) {
  'image' => AppColors.images,
  'video' => AppColors.videos,
  'audio' => AppColors.audio,
  _ => AppColors.other,
};

List<List<dynamic>> _typeIcon(String mediaType) => switch (mediaType) {
  'image' => HugeIcons.strokeRoundedImage01,
  'video' => HugeIcons.strokeRoundedVideo01,
  'audio' => HugeIcons.strokeRoundedMusicNote01,
  _ => HugeIcons.strokeRoundedFile01,
};


/// One cached Memory: artwork, name, media type and the cached dates.
class _MemoryEntryTile extends StatelessWidget {
  final MemoryEntry entry;
  final VoidCallback onTap;

  const _MemoryEntryTile({required this.entry, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = _typeColor(entry.mediaType);
    final exists = File(entry.path).existsSync();

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: AppRadius.borderMd,
            child: SizedBox(
              width: 56,
              height: 56,
              child: _MemoryThumbnail(entry: entry, accent: accent),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.name.isEmpty ? 'Unnamed media' : entry.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  entry.path,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: [
                    AppBadge(
                      label: entry.mediaType,
                      color: accent.withValues(alpha: 0.15),
                      textColor: accent,
                    ),
                    AppBadge(
                      label: entry.creationDate > 0
                          ? formatDate(entry.creationDate)
                          : 'undated',
                    ),
                    if (!exists)
                      const AppBadge(
                        label: 'missing',
                        color: Color(0x26EF4444),
                        textColor: AppColors.error,
                      ),
                    if (entry.lastNotified != null)
                      AppBadge(label: 'notified ${entry.lastNotified}'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Icon(
            Icons.chevron_right,
            color: theme.colorScheme.onSurfaceVariant,
            size: 20,
          ),
        ],
      ),
    );
  }
}

/// Cached artwork when the entry has one, otherwise a media-type icon.
class _MemoryThumbnail extends StatelessWidget {
  final MemoryEntry entry;
  final Color accent;

  const _MemoryThumbnail({required this.entry, required this.accent});

  @override
  Widget build(BuildContext context) {
    final bytes = _decodeThumbnail(entry.thumbnail);
    if (bytes == null) {
      return Container(
        color: accent.withValues(alpha: 0.15),
        child: Center(
          child: HugeIcon(
            icon: _typeIcon(entry.mediaType),
            size: 26,
            color: accent,
          ),
        ),
      );
    }
    return Image.memory(bytes, fit: BoxFit.cover);
  }
}

/// Decodes a cached base64 JPEG thumbnail, or `null` when it is unusable.
Uint8List? _decodeThumbnail(String? base64Thumbnail) {
  if (base64Thumbnail == null || base64Thumbnail.isEmpty) return null;
  try {
    final bytes = base64Decode(base64Thumbnail);
    return bytes.isEmpty ? null : bytes;
  } catch (_) {
    return null;
  }
}


/// Full metadata of a single cached Memory, shown as a bottom sheet.
class _MemoryEntrySheet extends StatelessWidget {
  final MemoryEntry entry;

  const _MemoryEntrySheet({required this.entry});

  Future<void> _openMedia(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final opened = await MemoryService.openCachedEntry(entry);
    if (!opened) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('This media file is no longer on disk.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final thumbnailBytes = _decodeThumbnail(entry.thumbnail)?.length ?? 0;
    final exists = File(entry.path).existsSync();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  HugeIcon(
                    icon: _typeIcon(entry.mediaType),
                    size: 22,
                    color: _typeColor(entry.mediaType),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      entry.name.isEmpty ? 'Unnamed media' : entry.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              _DetailRow(label: 'Identifier', value: entry.id),
              _DetailRow(label: 'Media type', value: entry.mediaType),
              _DetailRow(label: 'Path', value: entry.path),
              _DetailRow(
                label: 'Still on disk',
                value: exists ? 'yes' : 'no — deleted or moved',
              ),
              _DetailRow(
                label: 'Creation date',
                value: entry.creationDate > 0
                    ? '${formatDate(entry.creationDate)} '
                          '(${entry.creationDate})'
                    : 'not resolved',
              ),
              _DetailRow(
                label: 'Date resolved',
                value: entry.dateResolved ? 'yes' : 'no',
              ),
              _DetailRow(
                label: 'Cached at',
                value: entry.cachedAt > 0
                    ? '${formatDate(entry.cachedAt)} (${entry.cachedAt})'
                    : 'unknown',
              ),
              _DetailRow(
                label: 'Last notified',
                value: entry.lastNotified ?? 'never',
              ),
              _DetailRow(
                label: 'Cached artwork',
                value: thumbnailBytes > 0
                    ? '${formatBytes(thumbnailBytes)} JPEG'
                    : 'none',
              ),
              const SizedBox(height: AppSpacing.lg),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: exists ? () => _openMedia(context) : null,
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('Open media'),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Opens the media through the same code path a tapped Memory '
                'notification uses.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One label/value line of the metadata sheet.
class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 118,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

