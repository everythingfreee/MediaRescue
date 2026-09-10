import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import '../app/theme/app_colors.dart';
import '../models/file_item.dart';
import '../providers/storage_provider.dart';

final videoThumbnailProvider =
    FutureProvider.family<Uint8List?, String>((ref, path) async {
  final storageService = ref.watch(storageServiceProvider);
  return await storageService.getThumbnail(path);
});

class ThumbnailImage extends ConsumerWidget {
  final FileItem item;
  final double width;
  final double height;
  final double borderRadius;

  const ThumbnailImage({
    super.key,
    required this.item,
    this.width = 50,
    this.height = 50,
    this.borderRadius = 8,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (item.isDirectory) {
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.amber.withOpacity(0.15),
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        child: Center(
          child: HugeIcon(
            icon: HugeIcons.strokeRoundedFolder01,
            color: Colors.amber.shade700,
            size: width * 0.5,
          ),
        ),
      );
    }

    if (item.isImage) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: SizedBox(
          width: width,
          height: height,
          child: Image.file(
            File(item.path),
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return _fallbackContainer(
                context,
                const HugeIcon(icon: HugeIcons.strokeRoundedImage01, color: AppColors.images),
              );
            },
          ),
        ),
      );
    }

    if (item.isVideo) {
      final thumbnailAsync = ref.watch(videoThumbnailProvider(item.path));
      return ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: SizedBox(
          width: width,
          height: height,
          child: thumbnailAsync.when(
            data: (bytes) {
              if (bytes == null) {
                return _fallbackContainer(
                  context,
                  const HugeIcon(icon: HugeIcons.strokeRoundedVideo01, color: AppColors.videos),
                );
              }
              return Stack(
                fit: StackFit.expand,
                children: [
                  Image.memory(bytes, fit: BoxFit.cover),
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.black45,
                        shape: BoxShape.circle,
                      ),
                      child: const HugeIcon(
                        icon: HugeIcons.strokeRoundedPlay,
                        color: Colors.white,
                        size: 14,
                      ),
                    ),
                  ),
                ],
              );
            },
            loading: () => Container(
              color: Theme.of(context).colorScheme.surfaceContainerHigh,
              child: const Center(
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
            error: (err, stack) => _fallbackContainer(
              context,
              const HugeIcon(icon: HugeIcons.strokeRoundedVideo01, color: AppColors.videos),
            ),
          ),
        ),
      );
    }

    return _fallbackContainer(context, _getFileIcon());
  }

  Widget _fallbackContainer(BuildContext context, Widget icon) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Center(child: icon),
    );
  }

  Widget _getFileIcon() {
    if (item.isAudio) {
      return const HugeIcon(icon: HugeIcons.strokeRoundedMusicNote01, color: AppColors.audio);
    }
    if (item.isPdf) {
      return const HugeIcon(icon: HugeIcons.strokeRoundedPdf01, color: AppColors.documents);
    }
    if (item.isDocument || item.isText) {
      return const HugeIcon(icon: HugeIcons.strokeRoundedFile01, color: AppColors.documents);
    }
    if (item.isArchive) {
      return const HugeIcon(icon: HugeIcons.strokeRoundedZip01, color: AppColors.other);
    }
    if (item.isApk) {
      return const HugeIcon(icon: HugeIcons.strokeRoundedAndroid, color: AppColors.success);
    }
    return const HugeIcon(icon: HugeIcons.strokeRoundedFile01, color: AppColors.other);
  }
}