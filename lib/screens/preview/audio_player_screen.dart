import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../../models/file_item.dart';

class AudioPlayerScreen extends StatefulWidget {
  final FileItem item;
  final List<dynamic> allFiles;

  const AudioPlayerScreen({
    super.key,
    required this.item,
    this.allFiles = const [],
  });

  @override
  State<AudioPlayerScreen> createState() => _AudioPlayerScreenState();
}

class _AudioPlayerScreenState extends State<AudioPlayerScreen> {
  VideoPlayerController? _controller;
  late int _currentIndex;
  bool _initialized = false;

  List<FileItem> get _audios {
    final files = widget.allFiles.cast<FileItem>();
    if (files.isEmpty) return [widget.item];
    return files.where((f) => f.isAudio).toList();
  }

  @override
  void initState() {
    super.initState();
    final audios = _audios;
    _currentIndex = audios.indexOf(widget.item);
    if (_currentIndex < 0) _currentIndex = 0;
    _initController(audios[_currentIndex]);
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
      debugPrint('Audio init error: $error');
      if (_controller == newController) {
        setState(() {
          _initialized = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    _controller = null;
    super.dispose();
  }

  void _togglePlay() {
    final controller = _controller;
    if (controller == null) return;
    if (controller.value.isPlaying) {
      controller.pause();
    } else {
      controller.play();
    }
    setState(() {});
  }

  void _playNext() {
    final audios = _audios;
    if (audios.isEmpty) return;
    _currentIndex = (_currentIndex + 1) % audios.length;
    setState(() {});
    _initController(audios[_currentIndex]);
  }

  void _playPrevious() {
    final audios = _audios;
    if (audios.isEmpty) return;
    _currentIndex = (_currentIndex - 1 + audios.length) % audios.length;
    setState(() {});
    _initController(audios[_currentIndex]);
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.toString().padLeft(2, '0');
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final audios = _audios;
    final currentItem = audios[_currentIndex];
    final controller = _controller;

    return Scaffold(
      appBar: AppBar(
        title: Text(currentItem.name,
            maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: Center(
        child: _initialized && controller != null
            ? Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Icon(
                        Icons.audiotrack,
                        size: 64,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      currentItem.name,
                      style: theme.textTheme.titleLarge,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      currentItem.mimeType ?? 'Audio',
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 32),
                    // Progress
                    ValueListenableBuilder(
                      valueListenable: controller,
                      builder: (context, value, _) {
                        final position = value.position;
                        final duration = value.duration;
                        return Column(
                          children: [
                            Slider(
                              value: position.inMilliseconds
                                  .clamp(0, duration.inMilliseconds)
                                  .toDouble(),
                              max: duration.inMilliseconds > 0
                                  ? duration.inMilliseconds.toDouble()
                                  : 1,
                              onChanged: (v) {
                                controller
                                    .seekTo(Duration(milliseconds: v.toInt()));
                              },
                            ),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(_formatDuration(position)),
                                  Text(_formatDuration(duration)),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    // Controls
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          iconSize: 48,
                          icon: const Icon(Icons.skip_previous),
                          onPressed: _playPrevious,
                        ),
                        const SizedBox(width: 16),
                        IconButton.filled(
                          iconSize: 64,
                          icon: Icon(
                            controller.value.isPlaying
                                ? Icons.pause_circle_filled
                                : Icons.play_circle_filled,
                          ),
                          onPressed: _togglePlay,
                        ),
                        const SizedBox(width: 16),
                        IconButton(
                          iconSize: 48,
                          icon: const Icon(Icons.skip_next),
                          onPressed: _playNext,
                        ),
                      ],
                    ),
                  ],
                ),
              )
            : const CircularProgressIndicator(),
      ),
    );
  }
}