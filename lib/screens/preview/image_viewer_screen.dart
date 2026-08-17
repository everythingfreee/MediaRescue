import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import '../../models/file_item.dart';

class ImageViewerScreen extends ConsumerStatefulWidget {
  final FileItem item;
  final List<dynamic> allFiles;

  const ImageViewerScreen({
    super.key,
    required this.item,
    this.allFiles = const [],
  });

  @override
  ConsumerState<ImageViewerScreen> createState() => _ImageViewerScreenState();
}

class _ImageViewerScreenState extends ConsumerState<ImageViewerScreen> {
  late PageController _pageController;
  late int _currentIndex;

  List<FileItem> get _images {
    final files = widget.allFiles.cast<FileItem>();
    if (files.isEmpty) return [widget.item];
    return files.where((f) => f.isImage).toList();
  }

  @override
  void initState() {
    super.initState();
    final images = _images;
    _currentIndex = images.indexWhere((f) => f.path == widget.item.path);
    if (_currentIndex < 0) _currentIndex = 0;
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final images = _images;

    return Scaffold(
      appBar: AppBar(
        title: Text(images[_currentIndex].name),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      backgroundColor: Colors.black,
      body: PhotoViewGallery.builder(
        pageController: _pageController,
        itemCount: images.length,
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        builder: (context, index) {
          final item = images[index];
          return PhotoViewGalleryPageOptions(
            imageProvider: FileImage(File(item.path)),
            minScale: PhotoViewComputedScale.contained,
            maxScale: PhotoViewComputedScale.covered * 2,
            errorBuilder: (context, error, stackTrace) {
              return const Center(
                child: Text(
                  'Failed to load image',
                  style: TextStyle(color: Colors.white),
                ),
              );
            },
          );
        },
        loadingBuilder: (context, event) => const Center(
          child: CircularProgressIndicator(),
        ),
      ),
    );
  }
}