import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../app/theme/app_radius.dart';
import '../app/theme/app_spacing.dart';
import '../models/file_item.dart';
import '../providers/browser_provider.dart';
import '../providers/selection_provider.dart';
import '../providers/storage_provider.dart';
import 'media_info_sheet.dart';

Future<void> showFileActionsSheet(
  BuildContext context,
  WidgetRef ref,
  FileItem item, {
  VoidCallback? onOpen,
  List<Widget> additionalActions = const [],
}) async {
  final theme = Theme.of(context);
  
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: theme.colorScheme.surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
    ),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Bottom sheet drag handle
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.outline,
                borderRadius: AppRadius.borderPill,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withOpacity(0.5),
                  borderRadius: AppRadius.borderSm,
                ),
                child: HugeIcon(
                  icon: item.isImage
                      ? HugeIcons.strokeRoundedImage01
                      : item.isVideo
                      ? HugeIcons.strokeRoundedVideo01
                      : item.isAudio
                      ? HugeIcons.strokeRoundedMusicNote01
                      : item.isPdf
                      ? HugeIcons.strokeRoundedPdf01
                      : HugeIcons.strokeRoundedFile01,
                  color: theme.colorScheme.primary,
                ),
              ),
              title: Text(
                item.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                item.parentDirectory,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall,
              ),
            ),
            const Divider(height: 16),
            if (onOpen != null)
              ListTile(
                leading: const HugeIcon(icon: HugeIcons.strokeRoundedPlayCircle, color: Colors.blue),
                title: const Text('Preview'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  onOpen();
                },
              ),
            ListTile(
              leading: const HugeIcon(icon: HugeIcons.strokeRoundedInformationCircle, color: Colors.purple),
              title: const Text('Information'),
              onTap: () {
                Navigator.of(ctx).pop();
                showMediaInfoSheet(context, ref, item);
              },
            ),
            ...additionalActions,
            ListTile(
              leading: const HugeIcon(icon: HugeIcons.strokeRoundedFolderOpen, color: Colors.amber),
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
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    ),
  );
}

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
    ref.read(storageServiceProvider).openFileLocation(item.path);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Opening location in file manager…')),
    );
  }
}
