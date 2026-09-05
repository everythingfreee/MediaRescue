import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/file_item.dart';
import '../providers/browser_provider.dart';
import '../providers/selection_provider.dart';
import '../providers/storage_provider.dart';
import 'media_info_sheet.dart';

/// Shared "select a file → actions" entry point used by the Search, Large
/// Files and Hidden Media screens. Keeps the existing MediaRescue design
/// language and never removes existing per-screen actions.
///
/// Available actions:
///  - [Information]  — the existing detailed metadata sheet.
///  - [Open Location]— the in-app folder browser at the file's directory
///    (falls back to the system file manager for paths outside the shared
///    internal storage root, e.g. SD cards).
///  - [Preview]      — optional [onOpen] callback (the caller's normal tap
///    behaviour), shown only when provided.
///  - [additionalActions] — caller-specific entries (e.g. "Why hidden?" on
///    the Hidden Media screen), rendered after Information.
Future<void> showFileActionsSheet(
  BuildContext context,
  WidgetRef ref,
  FileItem item, {
  VoidCallback? onOpen,
  List<Widget> additionalActions = const [],
}) async {
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: Theme.of(context).colorScheme.surface,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Icon(
                item.isImage
                    ? Icons.image
                    : item.isVideo
                    ? Icons.video_file
                    : item.isAudio
                    ? Icons.audiotrack
                    : item.isPdf
                    ? Icons.picture_as_pdf
                    : Icons.insert_drive_file,
              ),
            ),
            title: Text(
              item.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              item.parentDirectory,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const Divider(height: 1),
          if (onOpen != null)
            ListTile(
              leading: const Icon(Icons.play_circle_outline),
              title: const Text('Preview'),
              onTap: () {
                Navigator.of(ctx).pop();
                onOpen();
              },
            ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('Information'),
            onTap: () {
              Navigator.of(ctx).pop();
              showMediaInfoSheet(context, ref, item);
            },
          ),
          ...additionalActions,
          ListTile(
            leading: const Icon(Icons.folder_open),
            title: const Text('Open Location'),
            subtitle: Text(
              item.parentDirectory,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            onTap: () {
              Navigator.of(ctx).pop();
              openFileLocationInApp(context, ref, item);
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

/// Navigates the existing Browse tab to the directory containing [item].
///
/// Files under `/storage/emulated/0` are opened with the in-app browser
/// (the user "lands at" the containing directory). Anything else (SD card,
/// unexpected path) falls back to the system file manager, reusing the
/// existing native `openFileLocation` implementation.
void openFileLocationInApp(BuildContext context, WidgetRef ref, FileItem item) {
  final root = storageRoot;
  final parent = item.parentDirectory;
  final String? relative;
  if (parent.startsWith('$root/')) {
    relative = parent.substring(root.length + 1);
  } else if (parent == root) {
    relative = '';
  } else {
    relative = null;
  }

  if (relative != null) {
    final segments = relative.isEmpty ? <String>[] : relative.split('/');
    ref.read(currentPathProvider.notifier).resetTo(segments);
    ref.read(selectionProvider.notifier).clear();
    context.go('/browse');
  } else {
    // SD card / non-standard path — use the system file manager fallback.
    ref.read(storageServiceProvider).openFileLocation(item.path);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Opening location in file manager…')),
    );
  }
}
