import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/file_item.dart';
import '../providers/storage_provider.dart';

/// Cache for video thumbnails (images use FileImage directly).
final videoThumbnailProvider =
    FutureProvider.family<Uint8List?, String>((ref, path) async {
  final storageService = ref.watch(storageServiceProvider);
  return await storageService.getThumbnail(path);
});

class ThumbnailImage extends ConsumerWidget {
  final FileItem item;
  final double width;
  final double height;

  const ThumbnailImage({
    super.key,
    required this.item,
    this.width = 50,
    this.height = 50,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (item.isDirectory) {
      return Icon(Icons.folder, size: width, color: Colors.amber);
    }

    // For images, use FileImage directly - it's fast and reliable
    if (item.isImage) {
      return SizedBox(
        width: width,
        height: height,
        child: Image.file(
          File(item.path),
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Icon(Icons.image, size: width, color: Colors.grey);
          },
        ),
      );
    }

    // For videos, use the native thumbnail extraction
    if (item.isVideo) {
      final thumbnailAsync = ref.watch(videoThumbnailProvider(item.path));
      return SizedBox(
        width: width,
        height: height,
        child: thumbnailAsync.when(
          data: (bytes) {
            if (bytes == null) {
              return Icon(Icons.video_file, size: width, color: Colors.grey);
            }
            return Image.memory(bytes, fit: BoxFit.cover);
          },
          loading: () => Container(
            color: Colors.black12,
            child: const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
          error: (err, stack) =>
              Icon(Icons.video_file, size: width, color: Colors.grey),
        ),
      );
    }

    // For other file types, show a type-specific icon
    return Icon(_getFileIcon(), size: width, color: Colors.grey);
  }

  IconData _getFileIcon() {
    if (item.isAudio) return Icons.audiotrack;
    if (item.isPdf) return Icons.picture_as_pdf;
    if (item.isDocument) return Icons.description;
    if (item.isText) return Icons.article;
    if (item.isArchive) return Icons.folder_zip;
    if (item.isApk) return Icons.android;
    return Icons.insert_drive_file;
  }
}