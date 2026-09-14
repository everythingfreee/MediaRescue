import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../../app/app.dart';
import 'package:flutter/services.dart';
import '../../models/file_item.dart';
import '../../utils/screen_wake.dart';

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
  bool _isFullScreen = false;
  VoidCallback? _controllerListener;

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
    if (oldController != null && _controllerListener != null) {
      oldController.removeListener(_controllerListener!);
    }
    _controllerListener = null;
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
      // Auto‑repeat listener: restart video when it ends
      _controllerListener = () {
        final ctrl = _controller;
        if (ctrl != null && ctrl.value.isInitialized) {
          if (ctrl.value.isPlaying) {
            ScreenWake.enable();
          } else {
            ScreenWake.disable();
          }
          final position = ctrl.value.position;
          final duration = ctrl.value.duration;
          if (position >= duration && !ctrl.value.isPlaying) {
            ctrl.seekTo(Duration.zero);
            ctrl.play();
          }
        }
      };
      _controller?.addListener(_controllerListener!);
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

  void _toggleFullScreen() {
    setState(() {
      _isFullScreen = !_isFullScreen;
    });
    if (_isFullScreen) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    }
  }

  @override
  void dispose() {
    if (_controllerListener != null) {
      _controller?.removeListener(_controllerListener!);
    }
    ScreenWake.disable();
    if (_isFullScreen) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    }
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
      appBar: _isFullScreen
          ? null
          : AppBar(
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
                        _ControlsOverlay(
                          controller: controller,
                          item: videos[index],
                          allFiles: videos,
                        ),
                        VideoProgressIndicator(controller,
                            allowScrubbing: true),
                        if (_isFullScreen ||
                            controller.value.aspectRatio > 1.0)
                          Positioned(
                            top: 8,
                            right: 8,
                            child: IconButton(
                              icon: Icon(
                                _isFullScreen
                                    ? Icons.fullscreen_exit
                                    : Icons.fullscreen,
                                color: Colors.white,
                              ),
                              tooltip: _isFullScreen
                                  ? 'Exit fullscreen'
                                  : 'Fullscreen',
                              onPressed: _toggleFullScreen,
                            ),
                          ),
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
  const _ControlsOverlay({
    required this.controller,
    required this.item,
    required this.allFiles,
  });

  final VideoPlayerController controller;
  final FileItem item;
  final List<FileItem> allFiles;

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