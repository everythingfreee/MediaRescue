import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:video_player/video_player.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../models/file_item.dart';
import '../../widgets/app_card.dart';

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
                padding: AppSpacing.pagePadding,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AppCard(
                      width: 200,
                      height: 200,
                      color: AppColors.audio.withOpacity(0.15),
                      borderColor: AppColors.audio.withOpacity(0.3),
                      child: Center(
                        child: HugeIcon(
                          icon: HugeIcons.strokeRoundedMusicNote01,
                          size: 96,
                          color: AppColors.audio,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    Text(
                      currentItem.name,
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      currentItem.mimeType ?? 'Audio Track',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxl),
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
                              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(_formatDuration(position), style: theme.textTheme.bodySmall),
                                  Text(_formatDuration(duration), style: theme.textTheme.bodySmall),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          iconSize: 40,
                          icon: const HugeIcon(icon: HugeIcons.strokeRoundedPrevious, size: 36),
                          onPressed: _playPrevious,
                        ),
                        const SizedBox(width: AppSpacing.lg),
                        IconButton.filled(
                          iconSize: 56,
                          style: IconButton.styleFrom(
                            backgroundColor: theme.colorScheme.primary,
                            foregroundColor: theme.colorScheme.onPrimary,
                          ),
                          icon: HugeIcon(
                            icon: controller.value.isPlaying
                                ? HugeIcons.strokeRoundedPause
                                : HugeIcons.strokeRoundedPlay,
                            color: Colors.white,
                            size: 32,
                          ),
                          onPressed: _togglePlay,
                        ),
                        const SizedBox(width: AppSpacing.lg),
                        IconButton(
                          iconSize: 40,
                          icon: const HugeIcon(icon: HugeIcons.strokeRoundedNext, size: 36),
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