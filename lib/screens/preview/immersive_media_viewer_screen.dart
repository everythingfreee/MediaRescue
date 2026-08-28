import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:photo_view/photo_view.dart';
import 'package:video_player/video_player.dart';

import '../../app/app.dart' show routeObserver;
import '../../models/file_item.dart';
import '../../providers/rescue_provider.dart';
import '../../providers/storage_provider.dart';
import '../../widgets/media_info_sheet.dart';
import '../../widgets/thumbnail_image.dart';

const List<String> _shortMonths = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// Immersive, vertically scrollable media preview used everywhere the app
/// displays images or videos. Combines quick browsing (TikTok/Reels style
/// paging) with the MediaRescue actions (double tap rescue, actions menu,
/// info panel, playback controls and clean fullscreen).
class ImmersiveMediaViewerScreen extends ConsumerStatefulWidget {
  final List<FileItem> items;
  final int initialIndex;

  const ImmersiveMediaViewerScreen({
    super.key,
    required this.items,
    this.initialIndex = 0,
  });

  @override
  ConsumerState<ImmersiveMediaViewerScreen> createState() =>
      _ImmersiveMediaViewerScreenState();
}

class _ImmersiveMediaViewerScreenState
    extends ConsumerState<ImmersiveMediaViewerScreen> with RouteAware {
  static const List<double> _speedOptions = [0.5, 1.0, 1.5, 2.0];

  /// Width of the touch zones along the left/right edges of a video used for
  /// the edge-hold temporary 2× speed gesture.
  static const double _edgeBoostZoneWidth = 48;

  /// One-time player tour persistence key (stored via native preferences).
  static const String _tourSeenPrefKey = 'player_tour_seen';

  late final List<FileItem> _items;
  late final PageController _pageController;
  late int _currentIndex;

  // ── Video state ──────────────────────────────────────────────────────────
  VideoPlayerController? _videoController;
  bool _videoInitialized = false;
  bool _videoInitializing = false;
  bool _videoFailed = false;
  double _selectedSpeed = 1.0;
  bool _edgeBoostActive = false;
  final Set<int> _edgeActivePointers = {};

  // ── UI state ─────────────────────────────────────────────────────────────
  bool _controlsVisible = true;
  Timer? _controlsTimer;
  bool _cleanFullscreen = false;
  bool _shouldResumeOnReturn = false;

  // ── Player tour state ─────────────────────────────────────────────────────
  bool _tourVisible = false;
  int _tourStep = 0;
  bool _tourPrefChecked = false;
  bool _wasPlayingBeforeTour = false;

  // ── Gesture state ────────────────────────────────────────────────────────
  bool _imageZoomed = false;
  bool _videoPinching = false;
  final Map<int, Offset> _pinchPointers = {};
  double _lastPinchDist = 0;
  double _pinchAccum = 0;
  bool _sliderDragging = false;
  double _sliderDragValue = 0;

  // ── Rescue / feedback state ──────────────────────────────────────────────
  bool _isBusy = false;
  _RescueFlashState? _rescueFlash;
  Timer? _flashTimer;
  bool _playPauseFlashVisible = false;
  IconData _playPauseFlashIcon = Icons.play_arrow_rounded;
  Timer? _playPauseTimer;
  final Set<String> _rescuedPaths = {};

  bool get _isCurrentVideo => _items[_currentIndex].isVideo;

  @override
  void initState() {
    super.initState();
    _items = List<FileItem>.from(widget.items);
    _currentIndex = widget.initialIndex.clamp(0, _items.length - 1);
    _pageController = PageController(initialPage: _currentIndex);
    if (_items[_currentIndex].isVideo) {
      _initVideo(_currentIndex);
      _maybeShowFirstTimeTour();
    }
    _scheduleControlsHide();
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
  void didPushNext() {
    // A dialog / sheet / another screen covered this viewer — pause playback.
    final c = _videoController;
    if (c != null && c.value.isPlaying) {
      _shouldResumeOnReturn = true;
      c.pause();
    } else {
      _shouldResumeOnReturn = false;
    }
  }

  @override
  void didPopNext() {
    super.didPopNext();
    if (_shouldResumeOnReturn) {
      _shouldResumeOnReturn = false;
      final c = _videoController;
      if (c != null && _videoInitialized && !_edgeBoostActive) {
        c.play();
      }
    }
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    _controlsTimer?.cancel();
    _flashTimer?.cancel();
    _playPauseTimer?.cancel();
    _disposeVideo();
    _pageController.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  BUILD
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final currentItem = _items[_currentIndex];
    final safeTop = MediaQuery.paddingOf(context).top;
    final safeBottom = MediaQuery.paddingOf(context).bottom;

    final physics = (_imageZoomed || _videoPinching)
        ? const NeverScrollableScrollPhysics()
        : const PageScrollPhysics();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_tourVisible) {
          // System back closes the tour overlay first, not the viewer.
          _closeTour();
          return;
        }
        if (_cleanFullscreen) {
          _exitCleanFullscreen();
          return;
        }
        if (context.canPop()) {
          context.pop();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            PageView.builder(
              controller: _pageController,
              scrollDirection: Axis.vertical,
              itemCount: _items.length,
              physics: physics,
              allowImplicitScrolling: true,
              onPageChanged: _onPageChanged,
              itemBuilder: (context, index) => _buildMediaPage(index),
            ),
            _buildControlsOverlay(safeTop, safeBottom, currentItem),
            _buildCenterFlashes(currentItem),
            if (_tourVisible) _buildPlayerTourOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaPage(int index) {
    final item = _items[index];
    final active = index == _currentIndex;
    if (item.isImage) {
      return _ImageMediaPage(
        item: item,
        active: active,
        onTap: _onTapImage,
        onDoubleTap: _onDoubleTap,
        onLongPress: _onLongPress,
        onZoomChanged: (zoomed) {
          if (zoomed && !active) return;
          if (zoomed != _imageZoomed) {
            setState(() => _imageZoomed = zoomed);
          }
        },
      );
    }
    if (item.isVideo) {
      return _VideoMediaPage(
        item: item,
        active: active,
        controller: active ? _videoController : null,
        initialized: active && _videoInitialized,
        initializing: active && _videoInitializing,
        failed: active && _videoFailed,
        onTap: _onTapVideo,
        onDoubleTap: _onDoubleTap,
        onLongPress: _onLongPress,
        onPointerDown: _onVideoPointerDown,
        onPointerMove: _onVideoPointerMove,
        onPointerUp: _onVideoPointerUp,
        onPointerCancel: _onVideoPointerCancel,
      );
    }
    return const SizedBox.shrink();
  }

  void _onPageChanged(int index) {
    if (index == _currentIndex) return;
    _controlsTimer?.cancel();
    setState(() {
      _currentIndex = index;
      _imageZoomed = false;
      _videoPinching = false;
      _pinchPointers.clear();
      _pinchAccum = 0;
      _sliderDragging = false;
      if (_edgeBoostActive) {
        _edgeBoostActive = false;
        _edgeActivePointers.clear();
      }
    });
    if (_items[index].isVideo) {
      _initVideo(index);
      _maybeShowFirstTimeTour();
    } else {
      _disposeVideo();
    }
    _showControls();
  }
// ═══════════════════════════════════════════════════════════════════════════
  //  VIDEO LIFECYCLE
  // ═══════════════════════════════════════════════════════════════════════════

  void _initVideo(int index) {
    final item = _items[index];
    if (!item.isVideo) return;
    final old = _videoController;
    _videoController = null;
    setState(() {
      _videoInitialized = false;
      _videoInitializing = true;
      _videoFailed = false;
    });
    if (old != null) {
      try {
        old.pause();
      } catch (_) {}
      try {
        old.dispose();
      } catch (_) {}
    }

    final controller = VideoPlayerController.file(File(item.path));
    _videoController = controller;
    controller.initialize().then((_) {
      if (!mounted || _videoController != controller) {
        try {
          controller.dispose();
        } catch (_) {}
        return;
      }
      if (_currentIndex != index || !_items[index].isVideo) {
        try {
          controller.dispose();
        } catch (_) {}
        return;
      }
      setState(() {
        _videoInitialized = true;
        _videoInitializing = false;
      });
      final speed = _edgeBoostActive ? 2.0 : _selectedSpeed;
      try {
        controller.setPlaybackSpeed(speed);
      } catch (_) {}
      controller.play();
    }).catchError((Object error) {
      if (!mounted || _videoController != controller) return;
      setState(() {
        _videoInitialized = false;
        _videoInitializing = false;
        _videoFailed = true;
      });
    });
  }

  void _disposeVideo() {
    final c = _videoController;
    _videoController = null;
    _videoInitialized = false;
    _videoInitializing = false;
    _videoFailed = false;
    if (c != null) {
      try {
        c.pause();
      } catch (_) {}
      try {
        c.dispose();
      } catch (_) {}
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  CONTROL OVERLAYS
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildControlsOverlay(
    double safeTop,
    double safeBottom,
    FileItem currentItem,
  ) {
    final isVideo = currentItem.isVideo;
    return Positioned.fill(
      child: IgnorePointer(
        ignoring: !_controlsVisible,
        child: AnimatedOpacity(
          opacity: _controlsVisible ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 250),
          child: Stack(
            children: [
              if (!_cleanFullscreen) ...[
                _buildHeader(safeTop, currentItem),
                _buildRightRail(),
              ],
              if (isVideo) _buildVideoControls(safeBottom, currentItem),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(double safeTop, FileItem item) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black87, Colors.transparent],
          ),
        ),
        padding: EdgeInsets.only(top: safeTop + 4, bottom: 10),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              tooltip: 'Back',
              onPressed: () => Navigator.of(context).pop(),
            ),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _truncateFilename(item.name),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Modified ${_formatModifiedDate(item.modifiedDate)}',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 14),
              child: Text(
                '${_currentIndex + 1} / ${_items.length}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRightRail() {
    return Positioned(
      right: 6,
      top: 0,
      bottom: 0,
      child: Center(
        child: Material(
          color: Colors.transparent,
          child: IconButton(
            icon: const Icon(Icons.info_outline, color: Colors.white),
            tooltip: 'File information',
            onPressed: () => _showInfo(),
          ),
        ),
      ),
    );
  }
Widget _buildVideoControls(double safeBottom, FileItem item) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [Colors.black87, Colors.transparent],
          ),
        ),
        padding: EdgeInsets.fromLTRB(4, 20, 4, safeBottom + 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildSeekRow(_videoController),
            Row(
              children: [
                const SizedBox(width: 8),
                _buildSpeedChip(),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.help_outline, color: Colors.white),
                  tooltip: 'Player guide',
                  onPressed: _openTour,
                ),
                IconButton(
                  icon: Icon(
                    _cleanFullscreen
                        ? Icons.fullscreen_exit
                        : Icons.fullscreen,
                    color: Colors.white,
                  ),
                  tooltip:
                      _cleanFullscreen ? 'Exit fullscreen' : 'Clean fullscreen',
                  onPressed: _toggleFullscreen,
                ),
                const SizedBox(width: 4),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSeekRow(VideoPlayerController? controller) {
    if (controller == null || !_videoInitialized) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Icon(Icons.play_arrow_rounded, color: Colors.white),
            SizedBox(width: 8),
            Text('00:00', style: TextStyle(color: Colors.white)),
            SizedBox(width: 8),
            Expanded(child: LinearProgressIndicator(color: Colors.white30)),
            SizedBox(width: 8),
            Text('00:00', style: TextStyle(color: Colors.white)),
          ],
        ),
      );
    }
    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final durationMs = value.duration.inMilliseconds;
        final posMs = _sliderDragging
            ? _sliderDragValue
            : value.position.inMilliseconds.toDouble();
        final clamped = posMs.clamp(0.0, durationMs.toDouble());
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              IconButton(
                icon: Icon(
                  value.isPlaying
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 34,
                ),
                tooltip: value.isPlaying ? 'Pause' : 'Play',
                onPressed: _togglePlay,
              ),
              Text(
                _formatPlaybackTime(clamped.toInt()),
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: Colors.white,
                    inactiveTrackColor: Colors.white30,
                    thumbColor: Colors.white,
                    overlayColor: Colors.white24,
                    trackHeight: 2,
                  ),
                  child: Slider(
                    value: durationMs > 0 ? clamped : 0,
                    max: durationMs > 0 ? durationMs.toDouble() : 1,
                    onChangeStart: (v) {
                      setState(() {
                        _sliderDragging = true;
                        _sliderDragValue = v;
                      });
                      controller.seekTo(Duration(milliseconds: v.toInt()));
                    },
                    onChanged: (v) {
                      setState(() => _sliderDragValue = v);
                      controller.seekTo(Duration(milliseconds: v.toInt()));
                    },
                    onChangeEnd: (v) {
                      controller.seekTo(Duration(milliseconds: v.toInt()));
                      setState(() {
                        _sliderDragValue = v;
                        _sliderDragging = false;
                      });
                    },
                  ),
                ),
              ),
              Text(
                _formatPlaybackTime(durationMs),
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
              const SizedBox(width: 6),
            ],
          ),
        );
      },
    );
  }
Widget _buildSpeedChip() {
    return PopupMenuButton<double>(
      initialValue: _selectedSpeed,
      onSelected: _setSelectedSpeed,
      tooltip: 'Playback speed',
      color: Colors.black87,
      itemBuilder: (context) => [
        for (final speed in _speedOptions)
          PopupMenuItem<double>(
            value: speed,
            child: Row(
              children: [
                Icon(
                  speed == _selectedSpeed
                      ? Icons.check_circle
                      : Icons.circle_outlined,
                  size: 18,
                  color:
                      speed == _selectedSpeed ? Colors.white : Colors.white38,
                ),
                const SizedBox(width: 10),
                Text(
                  '${_speedLabel(speed)}×',
                  style: const TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white24,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          '${_speedLabel(_selectedSpeed)}×',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  CENTER FLASHES
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildCenterFlashes(FileItem item) {
    return Stack(
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: Center(
              child: AnimatedOpacity(
                opacity: _playPauseFlashVisible ? 1 : 0,
                duration: const Duration(milliseconds: 150),
                child: AnimatedScale(
                  scale: _playPauseFlashVisible ? 1 : 0.7,
                  duration: const Duration(milliseconds: 150),
                  child: Icon(
                    _playPauseFlashIcon,
                    size: 64,
                    color: Colors.white70,
                  ),
                ),
              ),
            ),
          ),
        ),
        if (_isBusy)
          Positioned.fill(
            child: IgnorePointer(
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const CircularProgressIndicator(color: Colors.white),
                ),
              ),
            ),
          ),
        if (_rescueFlash != null)
          Positioned.fill(
            child: IgnorePointer(
              child: Center(child: _rescueFlashWidget(_rescueFlash!)),
            ),
          ),
        if (_edgeBoostActive && item.isVideo)
          Positioned(
            top: MediaQuery.paddingOf(context).top + 64,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Text(
                  '2×',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _rescueFlashWidget(_RescueFlashState flash) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutBack,
      builder: (context, t, child) {
        return Opacity(
          opacity: t.clamp(0.0, 1.0),
          child: Transform.scale(scale: 0.7 + 0.3 * t, child: child),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(flash.icon, size: 36, color: flash.color),
            const SizedBox(height: 6),
            Text(
              flash.text,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
// ═══════════════════════════════════════════════════════════════════════════
  //  GESTURES / CONTROLS
  // ═══════════════════════════════════════════════════════════════════════════

  void _showControls() {
    _controlsTimer?.cancel();
    if (!mounted) return;
    setState(() => _controlsVisible = true);
    _scheduleControlsHide();
  }

  void _scheduleControlsHide() {
    _controlsTimer?.cancel();
    _controlsTimer = Timer(const Duration(milliseconds: 3600), () {
      if (mounted) setState(() => _controlsVisible = false);
    });
  }

  void _onTapImage() {
    if (_controlsVisible) {
      _controlsTimer?.cancel();
      setState(() => _controlsVisible = false);
    } else {
      _showControls();
    }
  }

  void _onTapVideo() {
    if (_videoInitialized) {
      _togglePlay();
    } else {
      _showControls();
    }
  }

  void _togglePlay() {
    final c = _videoController;
    if (c == null || !_videoInitialized) return;
    if (c.value.isPlaying) {
      c.pause();
      _flashPlayPause(Icons.pause_rounded);
    } else {
      if (c.value.duration > Duration.zero &&
          c.value.position >= c.value.duration) {
        c.seekTo(Duration.zero);
      }
      c.play();
      _flashPlayPause(Icons.play_arrow_rounded);
    }
    _showControls();
  }

  void _flashPlayPause(IconData icon) {
    _playPauseTimer?.cancel();
    setState(() {
      _playPauseFlashIcon = icon;
      _playPauseFlashVisible = true;
    });
    _playPauseTimer = Timer(const Duration(milliseconds: 600), () {
      if (mounted) setState(() => _playPauseFlashVisible = false);
    });
  }

  void _setSelectedSpeed(double speed) {
    setState(() => _selectedSpeed = speed);
    final c = _videoController;
    if (c != null && _videoInitialized && !_edgeBoostActive) {
      try {
        c.setPlaybackSpeed(speed);
      } catch (_) {}
    }
  }

  String _speedLabel(double speed) {
    return speed == speed.roundToDouble()
        ? speed.toInt().toString()
        : speed.toString();
  }

  void _enterCleanFullscreen() {
    if (_cleanFullscreen) return;
    _cleanFullscreen = true;
    _showControls();
  }

  void _exitCleanFullscreen() {
    if (!_cleanFullscreen) return;
    _cleanFullscreen = false;
    _showControls();
  }

  void _toggleFullscreen() {
    if (_cleanFullscreen) {
      _exitCleanFullscreen();
    } else {
      _enterCleanFullscreen();
    }
  }

  // ── Video raw pointer handling: edge hold 2× + pinch fullscreen ───────────

  void _onVideoPointerDown(PointerDownEvent event) {
    _pinchPointers[event.pointer] = event.position;
    if (_pinchPointers.length == 2) {
      final pts = _pinchPointers.values.toList();
      _lastPinchDist = (pts[0] - pts[1]).distance;
    }
    final width = MediaQuery.sizeOf(context).width;
    if (event.position.dx < _edgeBoostZoneWidth ||
        event.position.dx > width - _edgeBoostZoneWidth) {
      _edgeActivePointers.add(event.pointer);
      _onEdgeBoost(true);
    }
  }

  void _onVideoPointerMove(PointerMoveEvent event) {
    if (_pinchPointers.length < 2) return;
    _pinchPointers[event.pointer] = event.position;
    if (_pinchPointers.length != 2) return;
    final pts = _pinchPointers.values.toList();
    final dist = (pts[0] - pts[1]).distance;
    final delta = dist - _lastPinchDist;
    _lastPinchDist = dist;
    _pinchAccum += delta;
    if (!_videoPinching && _pinchAccum.abs() > 24) {
      _videoPinching = true;
      if (_pinchAccum < 0) {
        _enterCleanFullscreen();
      } else {
        _exitCleanFullscreen();
      }
      _pinchAccum = 0;
      setState(() {});
    }
  }

  void _onVideoPointerUp(PointerUpEvent event) {
    if (_edgeActivePointers.remove(event.pointer)) {
      if (_edgeActivePointers.isEmpty) _onEdgeBoost(false);
    }
    _pinchPointers.remove(event.pointer);
    _pinchAccum = 0;
    if (_pinchPointers.isEmpty) {
      _videoPinching = false;
      setState(() {});
    }
  }

  void _onVideoPointerCancel(PointerCancelEvent event) {
    if (_edgeActivePointers.remove(event.pointer)) {
      if (_edgeActivePointers.isEmpty) _onEdgeBoost(false);
    }
    _pinchPointers.remove(event.pointer);
    _pinchAccum = 0;
    if (_pinchPointers.isEmpty) {
      _videoPinching = false;
      setState(() {});
    }
  }

  void _onEdgeBoost(bool active) {
    if (!_isCurrentVideo) return;
    if (active) {
      if (_edgeBoostActive) return;
      setState(() => _edgeBoostActive = true);
      final c = _videoController;
      if (c != null && _videoInitialized) {
        try {
          c.setPlaybackSpeed(2.0);
        } catch (_) {}
      }
    } else {
      if (!_edgeBoostActive) return;
      setState(() => _edgeBoostActive = false);
      final c = _videoController;
      if (c != null && _videoInitialized) {
        try {
          c.setPlaybackSpeed(_selectedSpeed);
        } catch (_) {}
      }
    }
  }
// ═══════════════════════════════════════════════════════════════════════════
  //  RESCUE
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _onDoubleTap() async {
    await _rescueCurrent();
  }

  Future<void> _rescueCurrent() async {
    if (_isBusy) return;
    final item = _items[_currentIndex];
    final source = File(item.path);
    if (!source.existsSync()) {
      _flash('File not found');
      return;
    }
    if (_rescuedPaths.contains(item.path)) {
      _flash('Already rescued');
      return;
    }

    final storage = ref.read(storageServiceProvider);
    final settings = ref.read(rescueSettingsProvider);
    final destDir = settings.destinationFor(item);
    if (destDir.trim().isEmpty) {
      showSnack('No rescue destination is configured.');
      return;
    }
    final targetPath = '$destDir/${item.name}';

    if (_pathsEqual(targetPath, item.path)) {
      _flash('Already rescued');
      return;
    }

    var overwrite = false;
    if (File(targetPath).existsSync()) {
      final action = await _showDuplicateDialog(targetPath);
      if (action == null) return; // cancelled
      if (action == 0) {
        _flash('Already rescued');
        return;
      }
      overwrite = true;
    }

    setState(() => _isBusy = true);
    final result =
        await storage.copyFileVerified(item.path, destDir, overwrite);
    if (!mounted) return;
    setState(() => _isBusy = false);

    final success = result['success'] == true;
    if (!success) {
      if (result['alreadyExists'] == true) {
        _flash('Already rescued');
      } else {
        _flash(
          'Rescue failed',
          icon: Icons.error_outline,
          color: const Color(0xFFFF5252),
        );
        showSnack('Could not rescue "${item.name}".');
      }
      return;
    }

    final copiedPath = (result['targetPath'] as String?)?.isNotEmpty == true
        ? result['targetPath']! as String
        : targetPath;
    _rescuedPaths.add(item.path);
    await storage.indexMedia([copiedPath]);
    _flash('Rescued');
    await _showAfterRescueDialog(item, destDir, copiedPath);
  }

  Future<int?> _showDuplicateDialog(String targetPath) async {
    return showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Already rescued'),
        content: Text(
          'A file named "${targetPath.split('/').last}" already exists at:\n\n'
          '"${_relPath(targetPath)}"\n\nWhat would you like to do?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(0),
            child: const Text('Keep existing'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(1),
            child: const Text('Overwrite'),
          ),
        ],
      ),
    );
  }
Future<void> _showAfterRescueDialog(
    FileItem item,
    String destDir,
    String copiedPath,
  ) async {
    if (!mounted) return;
    final destLabel = _relPath(destDir);
    final type = item.isVideo ? 'Video' : (item.isAudio ? 'Audio' : 'Media');
    final action = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.check_circle, color: Colors.green, size: 40),
        title: Text('$type rescued successfully'),
        content: Text(
          'A copy of this file has been saved to:\n\n'
          '"${destLabel.isEmpty ? destDir : destLabel}"\n\n'
          'The original file is still in its original location.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop('keep'),
            child: const Text('Keep Original'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop('delete'),
            child: const Text('Delete Original'),
          ),
        ],
      ),
    );
    if (action != 'delete' || !mounted) return;

    // Verify the rescued copy before touching the original file.
    final copy = File(copiedPath);
    final verified = copy.existsSync() &&
        copy.lengthSync() == _safeLength(item.path);
    if (!verified) {
      showSnack(
        'Rescued copy could not be verified — the original was kept: '
        '"${_relPath(copiedPath)}"',
      );
      return;
    }

    final storage = ref.read(storageServiceProvider);
    final deleted = await storage.deleteFiles([item.path]);
    if (deleted) {
      await storage.indexMedia([item.path]);
      _rescuedPaths.remove(item.path);
      if (!mounted) return;
      showSnack(
        'Original deleted. The rescued copy is in "${_relPath(destDir)}".',
      );
      _removeCurrentItem();
    } else if (mounted) {
      showSnack(
        'The rescued copy was created, but the original could not be deleted.',
      );
    }
  }

  int _safeLength(String path) {
    try {
      return File(path).lengthSync();
    } catch (_) {
      return 0;
    }
  }

  void _removeCurrentItem() {
    if (!mounted) return;
    final removedIndex = _currentIndex;
    _items.removeAt(removedIndex);
    if (_items.isEmpty) {
      Navigator.of(context).pop();
      return;
    }
    final nextIndex = _currentIndex.clamp(0, _items.length - 1);
    _disposeVideo();
    setState(() => _currentIndex = nextIndex);
    if (_items[nextIndex].isVideo) {
      _initVideo(nextIndex);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _pageController.hasClients) {
        _pageController.jumpToPage(nextIndex);
      }
    });
    _showControls();
  }

  void _flash(
    String text, {
    IconData icon = Icons.check_circle_outline,
    Color color = const Color(0xFF4CAF50),
  }) {
    _flashTimer?.cancel();
    setState(() => _rescueFlash = _RescueFlashState(text, icon, color));
    _flashTimer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _rescueFlash = null);
    });
  }

  void showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _showInfo() async {
    final item = _items[_currentIndex];
    await showMediaInfoSheet(context, ref, item);
  }
  // ═══════════════════════════════════════════════════════════════════════════
  //  ONE-TIME PLAYER TOUR
  // ═══════════════════════════════════════════════════════════════════════════

  static const List<_TourStepData> _tourSteps = [
    _TourStepData(
      icon: Icons.swipe_vertical_rounded,
      title: 'Swipe to browse',
      body: 'Swipe up for the next file and down for the previous one — '
          'images and videos are all in one feed.',
    ),
    _TourStepData(
      icon: Icons.touch_app_rounded,
      title: 'Tap to play / pause',
      body: 'Tap the video once to play or pause it. The controls fade away '
          'automatically so the media stays in focus.',
    ),
    _TourStepData(
      icon: Icons.filter_center_focus_rounded,
      title: 'Double tap to rescue',
      body: 'Double tap any image or video to rescue a verified copy to your '
          'rescue destination — the original is never touched automatically.',
    ),
    _TourStepData(
      icon: Icons.speed_rounded,
      title: 'Hold the edge for 2×',
      body: 'Press and hold the left or right edge of the video to '
          'temporarily watch at 2× speed. Release to return to your speed.',
    ),
    _TourStepData(
      icon: Icons.fullscreen_rounded,
      title: 'Pinch for clean fullscreen',
      body: 'Pinch in with two fingers for a clean fullscreen view; pinch out '
          'to bring everything back. Images: pinch to zoom, pan to move.',
    ),
    _TourStepData(
      icon: Icons.more_horiz_rounded,
      title: 'Long press for actions',
      body: 'Long press for Rescue, Share, File information, Open file '
          'location and more. Use the seek bar to move through the video.',
    ),
  ];

  bool get _isTourActiveStepVideo => _items[_currentIndex].isVideo;

  /// Pauses playback while the tour overlay covers the screen.
  void _pauseForTour() {
    final c = _videoController;
    if (c != null && c.value.isPlaying) {
      _wasPlayingBeforeTour = true;
      try {
        c.pause();
      } catch (_) {}
    } else {
      _wasPlayingBeforeTour = false;
    }
  }

  void _resumeAfterTour() {
    if (_wasPlayingBeforeTour &&
        _isTourActiveStepVideo &&
        _videoInitialized &&
        !_edgeBoostActive) {
      try {
        _videoController?.play();
      } catch (_) {}
    }
    _wasPlayingBeforeTour = false;
  }

  Future<void> _maybeShowFirstTimeTour() async {
    if (_tourVisible || _tourPrefChecked || !_isTourActiveStepVideo) return;
    _tourPrefChecked = true;
    try {
      final seen = await ref
          .read(storageServiceProvider)
          .getAppPrefBool(_tourSeenPrefKey);
      if (!mounted || seen || _tourVisible) return;
      _openTour();
    } catch (_) {
      // Never block previewing because of the tour.
    }
  }

  void _openTour() {
    if (_tourVisible) return;
    _controlsTimer?.cancel();
    setState(() {
      _tourVisible = true;
      _tourStep = 0;
      _controlsVisible = false;
    });
    _pauseForTour();
  }

  Future<void> _closeTour() async {
    setState(() => _tourVisible = false);
    _resumeAfterTour();
    _scheduleControlsHide();
    try {
      await ref
          .read(storageServiceProvider)
          .setAppPrefBool(_tourSeenPrefKey, true);
    } catch (_) {}
  }

  void _nextTourStep() {
    if (_tourStep < _tourSteps.length - 1) {
      setState(() => _tourStep += 1);
    } else {
      _closeTour();
    }
  }

  Widget _buildPlayerTourOverlay() {
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    final step = _tourSteps[_tourStep];
    final isLast = _tourStep == _tourSteps.length - 1;
    return Positioned.fill(
      child: Material(
        color: Colors.black54,
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.only(top: 4, right: 8),
                  child: TextButton(
                    onPressed: _closeTour,
                    child: const Text(
                      'Skip',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),
                ),
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.primary.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          step.icon,
                          size: 34,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        step.title,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        step.body,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 18),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (var i = 0; i < _tourSteps.length; i++)
                            Container(
                              width: i == _tourStep ? 18 : 7,
                              height: 7,
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              decoration: BoxDecoration(
                                color: i == _tourStep
                                    ? Theme.of(context).colorScheme.primary
                                    : Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant.withValues(
                                        alpha: 0.35,
                                      ),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          if (_tourStep > 0)
                            TextButton(
                              onPressed: () => setState(() => _tourStep -= 1),
                              child: const Text('Back'),
                            ),
                          const Spacer(),
                          FilledButton(
                            onPressed: _nextTourStep,
                            child: Text(isLast ? 'Got it' : 'Next'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              SizedBox(height: safeBottom + 24),
            ],
          ),
        ),
      ),
    );
  }

// ═══════════════════════════════════════════════════════════════════════════
  //  ACTIONS MENU / SHARE / LOCATION / DELETE
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _onLongPress() async {
    // While the edge-hold (temporary 2× speed) gesture is active, the long
    // press must NOT open the actions menu — holding an edge only boosts the
    // playback speed until the finger is released.
    if (_edgeBoostActive) return;
    await _showMediaActions();
  }

  Future<void> _showMediaActions() async {
    final item = _items[_currentIndex];
    final action = await showModalBottomSheet<_MediaAction>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
              child: Text(
                _truncateFilename(item.name),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(ctx).textTheme.titleSmall,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.download_for_offline_outlined),
              title: const Text('Rescue'),
              subtitle: const Text('Copy to rescue destination'),
              onTap: () => Navigator.of(ctx).pop(_MediaAction.rescue),
            ),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('File Information'),
              onTap: () => Navigator.of(ctx).pop(_MediaAction.info),
            ),
            ListTile(
              leading: const Icon(Icons.share_outlined),
              title: const Text('Share'),
              onTap: () => Navigator.of(ctx).pop(_MediaAction.share),
            ),
            ListTile(
              leading: const Icon(Icons.folder_open),
              title: const Text('Open File Location'),
              onTap: () => Navigator.of(ctx).pop(_MediaAction.location),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Delete', style: TextStyle(color: Colors.red)),
              onTap: () => Navigator.of(ctx).pop(_MediaAction.delete),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    switch (action) {
      case _MediaAction.rescue:
        await _rescueCurrent();
      case _MediaAction.info:
        await _showInfo();
      case _MediaAction.share:
        await _shareCurrent();
      case _MediaAction.location:
        await _openLocationCurrent();
      case _MediaAction.delete:
        await _confirmDeleteCurrent();
      case null:
        break;
    }
  }
Future<void> _shareCurrent() async {
    final item = _items[_currentIndex];
    final ok = await ref.read(storageServiceProvider).shareFile(item.path);
    if (!ok && mounted) {
      showSnack('No app is available to share this file.');
    }
  }

  Future<void> _openLocationCurrent() async {
    final item = _items[_currentIndex];
    final ok =
        await ref.read(storageServiceProvider).openFileLocation(item.path);
    if (!ok && mounted) {
      showSnack('No app is available to open this file location.');
    }
  }

  Future<void> _confirmDeleteCurrent() async {
    final item = _items[_currentIndex];
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete file?'),
        content: Text('Delete "${item.name}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final storage = ref.read(storageServiceProvider);
    final ok = await storage.deleteFiles([item.path]);
    await storage.indexMedia([item.path]);
    if (ok) {
      if (mounted) showSnack('File deleted.');
      _removeCurrentItem();
    } else if (mounted) {
      showSnack('Delete failed.');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  FORMATTING HELPERS
  // ═══════════════════════════════════════════════════════════════════════════

  String _truncateFilename(String name, {int maxLen = 30}) {
    if (name.length <= maxLen) return name;
    final dot = name.lastIndexOf('.');
    final ext = dot > 0 ? name.substring(dot) : '';
    final base = dot > 0 ? name.substring(0, dot) : name;
    final available = maxLen - ext.length - 3;
    if (available < 3) return '${name.substring(0, maxLen - 3)}...';
    final keep = (available / 2).ceil();
    final start = base.substring(0, keep);
    final endPart = base.substring(base.length - (available - keep));
    return '$start...$endPart$ext';
  }

  String _formatModifiedDate(int ms) {
    if (ms <= 0) return 'Unknown';
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${_shortMonths[d.month - 1]} ${d.day}, ${d.year}';
  }

  String _formatPlaybackTime(int ms) {
    final d = Duration(milliseconds: ms);
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    String two(int v) => v.toString().padLeft(2, '0');
    return h > 0 ? '${two(h)}:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
  }

  String _relPath(String path) {
    final trimmed = path.trim();
    return trimmed.startsWith('/storage/emulated/0/')
        ? trimmed.substring('/storage/emulated/0/'.length)
        : trimmed;
  }

  bool _pathsEqual(String a, String b) {
    final na = a.replaceAll(RegExp(r'/+$'), '');
    final nb = b.replaceAll(RegExp(r'/+$'), '');
    return na == nb;
  }
}

enum _MediaAction { rescue, info, share, location, delete }

/// One step of the one-time player tour.
class _TourStepData {
  final IconData icon;
  final String title;
  final String body;
  const _TourStepData({
    required this.icon,
    required this.title,
    required this.body,
  });
}


class _RescueFlashState {
  final String text;
  final IconData icon;
  final Color color;

  const _RescueFlashState(this.text, this.icon, this.color);
}

class _UnsupportedPreview extends StatelessWidget {
  const _UnsupportedPreview();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.broken_image_outlined, color: Colors.white54, size: 56),
            SizedBox(height: 12),
            Text(
              'Unable to preview this file.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }
}
class _ImageMediaPage extends StatefulWidget {
  final FileItem item;
  final bool active;
  final VoidCallback onTap;
  final VoidCallback onDoubleTap;
  final VoidCallback onLongPress;
  final ValueChanged<bool> onZoomChanged;

  const _ImageMediaPage({
    required this.item,
    required this.active,
    required this.onTap,
    required this.onDoubleTap,
    required this.onLongPress,
    required this.onZoomChanged,
  });

  @override
  State<_ImageMediaPage> createState() => _ImageMediaPageState();
}

class _ImageMediaPageState extends State<_ImageMediaPage> {
  DateTime? _lastTapTime;
  Offset? _lastTapPos;
  bool _wasZoomed = false;

  /// Manual double-tap detection. PhotoView owns the gesture arena inside this
  /// page, so we observe raw pointer ups to trigger Rescue without fighting it.
  void _handlePointerUp(PointerUpEvent event) {
    final now = DateTime.now();
    final prevTime = _lastTapTime;
    final prevPos = _lastTapPos;
    _lastTapTime = now;
    _lastTapPos = event.position;
    if (prevTime != null &&
        now.difference(prevTime) < const Duration(milliseconds: 300) &&
        prevPos != null &&
        (event.position - prevPos).distance < 70) {
      widget.onDoubleTap();
      _lastTapTime = null;
      _lastTapPos = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active) {
      // Lightweight neighbour preview; the decoded image is cached by Flutter's
      // image cache so it becomes instant once this page becomes the active one.
      return GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        child: Container(
          color: Colors.black,
          child: Image.file(
            File(widget.item.path),
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => const _UnsupportedPreview(),
          ),
        ),
      );
    }

    return PhotoViewGestureDetectorScope(
      axis: Axis.vertical,
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerUp: _handlePointerUp,
        child: PhotoView(
          imageProvider: FileImage(File(widget.item.path)),
          backgroundDecoration: const BoxDecoration(color: Colors.black),
          minScale: PhotoViewComputedScale.contained,
          maxScale: PhotoViewComputedScale.covered * 3,
          initialScale: PhotoViewComputedScale.contained,
          // Double-tap means "Rescue" — disable PhotoView's double-tap zoom.
          scaleStateCycle: (state) => state,
          scaleStateChangedCallback: (state) {
            final zoomed = state != PhotoViewScaleState.initial;
            if (zoomed != _wasZoomed) {
              _wasZoomed = zoomed;
              widget.onZoomChanged(zoomed);
            }
          },
          onTapUp: (context, details, value) => widget.onTap(),
          errorBuilder: (context, error, stackTrace) => const _UnsupportedPreview(),
          loadingBuilder: (context, event) => const Center(
            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
          ),
        ),
      ),
    );
  }
}
class _VideoMediaPage extends StatelessWidget {
  final FileItem item;
  final bool active;
  final VideoPlayerController? controller;
  final bool initialized;
  final bool initializing;
  final bool failed;
  final VoidCallback onTap;
  final VoidCallback onDoubleTap;
  final VoidCallback onLongPress;
  final void Function(PointerDownEvent) onPointerDown;
  final void Function(PointerMoveEvent) onPointerMove;
  final void Function(PointerUpEvent) onPointerUp;
  final void Function(PointerCancelEvent) onPointerCancel;

  const _VideoMediaPage({
    required this.item,
    required this.active,
    required this.controller,
    required this.initialized,
    required this.initializing,
    required this.failed,
    required this.onTap,
    required this.onDoubleTap,
    required this.onLongPress,
    required this.onPointerDown,
    required this.onPointerMove,
    required this.onPointerUp,
    required this.onPointerCancel,
  });

  @override
  Widget build(BuildContext context) {
    Widget content;
    if (failed) {
      content = const _UnsupportedPreview();
    } else if (active && initialized && controller != null) {
      final aspect = controller!.value.aspectRatio > 0
          ? controller!.value.aspectRatio
          : 16 / 9;
      content = Center(
        child: AspectRatio(aspectRatio: aspect, child: VideoPlayer(controller!)),
      );
    } else {
      content = Stack(
        fit: StackFit.expand,
        children: [
          ThumbnailImage(
            item: item,
            width: double.infinity,
            height: double.infinity,
          ),
          if (active && initializing)
            const Center(
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
            ),
        ],
      );
    }

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: onTap,
      onDoubleTap: onDoubleTap,
      onLongPress: onLongPress,
      child: Container(
        color: Colors.black,
        child: Stack(
          fit: StackFit.expand,
          children: [
            content,
            // Raw pointer observer: edge hold → temporary 2× speed,
            // two-finger pinch → clean fullscreen toggle.
            Listener(
              behavior: HitTestBehavior.translucent,
              onPointerDown: onPointerDown,
              onPointerMove: onPointerMove,
              onPointerUp: onPointerUp,
              onPointerCancel: onPointerCancel,
            ),
          ],
        ),
      ),
    );
  }
}
