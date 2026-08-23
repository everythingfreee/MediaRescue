import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../../app/app.dart';
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

class _VideoPlayerScreenState extends State<VideoPlayerScreen>
    with RouteAware {
  late PageController _pageController;
  late int _currentIndex;
  VideoPlayerController? _controller;
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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != null) {
      routeObserver.subscribe(this, route);
    }
  }

  @override
  void didPopNext() {
    // Returning to this screen — resume playback.
    _controller?.play();
  }

  @override
  void didPushNext() {
    // Another screen (e.g. a tab) is now on top — pause playback.
    _controller?.pause();
  }

  void _initController(FileItem item) {
    // Always dispose the old controller before creating a new one
    final oldController = _controller;
    _controller = null;
    _initialized = false;
    if (oldController != null) {
      try {
        oldController.pause();
      } catch (_) {}
      oldController.dispose();
    }

    final newController = VideoPlayerController.file(File(item.path));
    _controller = newController;
    newController.initialize().then((_) {
      if (!mounted || _controller != newController) {
        // The controller was replaced before initialization completed
        newController.dispose();
        return;
      }
      setState(() {
        _initialized = true;
      });
      newController.play();
    }).catchError((error) {
      debugPrint('Video init error: $error');
      if (_controller == newController) {
        setState(() {
          _initialized = false;
        });
      }
    });
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    _pageController.dispose();
    _controller?.dispose();
    _controller = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final videos = _videos;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          color: Colors.white,
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).maybePop(),
        ),
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
          });
          _initController(videos[index]);
        },
        itemBuilder: (context, index) {
          final controller = _controller;
          return Center(
            child: _initialized && index == _currentIndex && controller != null
                ? AspectRatio(
                    aspectRatio: controller.value.aspectRatio,
                    child: Stack(
                      alignment: Alignment.bottomCenter,
                      children: [
                        VideoPlayer(controller),
                        _ControlsOverlay(controller: controller),
                        VideoProgressIndicator(controller,
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