import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../../models/file_item.dart';

class VideoPlayerScreen extends StatefulWidget {
  final FileItem item;
  final List<dynamic> allFiles;

  const VideoPlayerScreen({
    super.key,
    required this.item,
    this.allFiles = const [],
  });

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late PageController _pageController;
  late int _currentIndex;
  late VideoPlayerController _controller;
  bool _initialized = false;

  List<FileItem> get _videos {
    final files = widget.allFiles.cast<FileItem>();
    if (files.isEmpty) return [widget.item];
    return files.where((f) => f.isVideo).toList();
  }

  @override
  void initState() {
    super.initState();
    final videos = _videos;
    _currentIndex = videos.indexWhere((f) => f.path == widget.item.path);
    if (_currentIndex < 0) _currentIndex = 0;
    _pageController = PageController(initialPage: _currentIndex);
    _initController(videos[_currentIndex]);
  }

  void _initController(FileItem item) {
    if (_initialized) {
      _controller.dispose();
    }
    _controller = VideoPlayerController.file(File(item.path))
      ..initialize().then((_) {
        if (!mounted) return;
        setState(() {
          _initialized = true;
        });
        _controller.play();
      }).catchError((error) {
        debugPrint('Video init error: $error');
      });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final videos = _videos;

    return Scaffold(
      appBar: AppBar(
        title: Text(videos[_currentIndex].name),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      backgroundColor: Colors.black,
      body: PageView.builder(
        controller: _pageController,
        itemCount: videos.length,
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
            _initialized = false;
          });
          _initController(videos[index]);
        },
        itemBuilder: (context, index) {
          return Center(
            child: _initialized && index == _currentIndex
                ? AspectRatio(
                    aspectRatio: _controller.value.aspectRatio,
                    child: Stack(
                      alignment: Alignment.bottomCenter,
                      children: [
                        VideoPlayer(_controller),
                        _ControlsOverlay(controller: _controller),
                        VideoProgressIndicator(_controller,
                            allowScrubbing: true),
                      ],
                    ),
                  )
                : const CircularProgressIndicator(),
          );
        },
      ),
    );
  }
}

class _ControlsOverlay extends StatelessWidget {
  const _ControlsOverlay({required this.controller});

  final VideoPlayerController controller;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 50),
          reverseDuration: const Duration(milliseconds: 200),
          child: controller.value.isPlaying
              ? const SizedBox.shrink()
              : const ColoredBox(
                  color: Colors.black26,
                  child: Center(
                    child: Icon(
                      Icons.play_arrow,
                      color: Colors.white,
                      size: 100.0,
                      semanticLabel: 'Play',
                    ),
                  ),
                ),
        ),
        GestureDetector(
          onTap: () {
            controller.value.isPlaying
                ? controller.pause()
                : controller.play();
          },
        ),
      ],
    );
  }
}