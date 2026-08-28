import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/file_item.dart';
import '../providers/storage_provider.dart';

const List<String> _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

const String _unavailable = 'Unavailable';

String formatBytes(int bytes) {
  if (bytes <= 0) return '0 B';
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
}

String formatDurationFromMs(int ms) {
  if (ms <= 0) return _unavailable;
  final d = Duration(milliseconds: ms);
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  final s = d.inSeconds.remainder(60);
  if (h > 0) {
    return '${h.toString().padLeft(2, '0')}:'
        '${m.toString().padLeft(2, '0')}:'
        '${s.toString().padLeft(2, '0')}';
  }
  return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
}
class _MediaInfoSheet extends StatefulWidget {
  final WidgetRef ref;
  final FileItem item;

  const _MediaInfoSheet({required this.ref, required this.item});

  @override
  State<_MediaInfoSheet> createState() => _MediaInfoSheetState();
}

class _MediaInfoSheetState extends State<_MediaInfoSheet> {
  Map<String, Object?>? _meta;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    final meta =
        await widget.ref.read(storageServiceProvider).getFileMediaInfo(
              widget.item.path,
            );
    if (!mounted) return;
    setState(() {
      _meta = meta;
      _loading = false;
    });
  }

  String _s(Object? value) {
    if (value == null) return _unavailable;
    final s = value.toString().trim();
    return s.isEmpty ? _unavailable : s;
  }

  String _channels(Object? value) {
    final n = value is int ? value : int.tryParse(value?.toString() ?? '');
    if (n == null || n <= 0) return _unavailable;
    if (n == 1) return '1 (Mono)';
    if (n == 2) return '2 (Stereo)';
    return n.toString();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final item = widget.item;
    final meta = _meta ?? const <String, Object?>{};

    final typeLabel = item.isImage
        ? 'Image'
        : item.isVideo
            ? 'Video'
            : item.isAudio
                ? 'Audio'
                : 'File';

    final rows = <(String, String)>[
      ('Filename', item.name),
      ('File size', formatBytes((meta['size'] as num?)?.toInt() ?? item.size)),
      if (meta['width'] != null && meta['height'] != null)
        ('Resolution', '${meta['width']} × ${meta['height']}'),
      if (item.isVideo || item.isAudio)
        ('Duration',
            formatDurationFromMs((meta['durationMs'] as num?)?.toInt() ?? 0)),
      if (meta['frameRate'] != null)
        ('Frame rate', '${_s(meta['frameRate'])} fps'),
      if (item.isVideo || item.isAudio)
        ('Bitrate', formatBitrate((meta['bitrate'] as num?)?.toInt() ?? 0)),
      if (item.isVideo) ('Audio', _s(meta['audioCodec'])),
      if (item.isAudio || (item.isVideo && meta['sampleRate'] != null))
        ('Sample rate', meta['sampleRate'] != null
            ? '${_s(meta['sampleRate'])} Hz'
            : _unavailable),
      if (item.isAudio || (item.isVideo && meta['channels'] != null))
        ('Channels', _channels(meta['channels'])),
      ('Format',
          item.extension.isEmpty ? _unavailable : item.extension.toUpperCase()),
      ('MIME type', item.mimeType ?? _unavailable),
      ('Original path', item.path),
      ('Modified', formatDate(item.modifiedDate)),
      if (meta['creationDate'] != null)
        ('Created (from metadata)', _s(meta['creationDate'])),
    ];

    return SafeArea(
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.62,
        maxChildSize: 0.9,
        minChildSize: 0.35,
        builder: (context, scrollController) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'File information — $typeLabel',
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                      tooltip: 'Close',
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: _loading
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const CircularProgressIndicator(),
                            const SizedBox(height: 12),
                            Text('Reading metadata…',
                                style: theme.textTheme.bodySmall),
                          ],
                        ),
                      )
                    : ListView(
                        controller: scrollController,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 8),
                        children: [
                          for (final row in rows)
                            _InfoRow(label: row.$1, value: row.$2),
                        ],
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(value, style: theme.textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}

String formatBitrate(int bps) {
  if (bps <= 0) return _unavailable;
  if (bps >= 1000000) return '${(bps / 1000000).toStringAsFixed(1)} Mbps';
  return '${(bps / 1000).toStringAsFixed(0)} kbps';
}

String formatDate(int milliseconds) {
  if (milliseconds <= 0) return _unavailable;
  final date = DateTime.fromMillisecondsSinceEpoch(milliseconds);
  return '${_months[date.month - 1]} ${date.day}, ${date.year}';
}

/// Builds and shows the detailed metadata bottom sheet for [item].
Future<void> showMediaInfoSheet(
  BuildContext context,
  WidgetRef ref,
  FileItem item,
) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    builder: (ctx) => _MediaInfoSheet(ref: ref, item: item),
  );
}