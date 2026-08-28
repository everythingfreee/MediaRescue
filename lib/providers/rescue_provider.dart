import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/file_item.dart';
import 'storage_provider.dart';

const String defaultStorageRoot = '/storage/emulated/0';

/// The destination folders used by the Rescue feature, configurable per media
/// type (or a single folder for everything).
class RescueDestinationSettings {
  final bool singleDestination;
  final String singlePath;
  final String imagesPath;
  final String videosPath;
  final String audioPath;
  final String otherPath;

  const RescueDestinationSettings({
    this.singleDestination = false,
    required this.singlePath,
    required this.imagesPath,
    required this.videosPath,
    required this.audioPath,
    required this.otherPath,
  });

  factory RescueDestinationSettings.defaults() {
    return const RescueDestinationSettings(
      singlePath: '$defaultStorageRoot/Pictures/MediaRescue',
      imagesPath: '$defaultStorageRoot/Pictures/MediaRescue',
      videosPath: '$defaultStorageRoot/Movies/MediaRescue',
      audioPath: '$defaultStorageRoot/Music/MediaRescue',
      otherPath: '$defaultStorageRoot/Documents/MediaRescue',
    );
  }

  factory RescueDestinationSettings.fromMap(Map<Object?, Object?> map) {
    final def = RescueDestinationSettings.defaults();
    String valueOr(Object? value, String fallback) {
      final s = value is String ? value.trim() : '';
      return s.isNotEmpty ? s : fallback;
    }

    return RescueDestinationSettings(
      singleDestination: map['singleDestination'] as bool? ?? false,
      singlePath: valueOr(map['singlePath'], def.singlePath),
      imagesPath: valueOr(map['images'], def.imagesPath),
      videosPath: valueOr(map['videos'], def.videosPath),
      audioPath: valueOr(map['audio'], def.audioPath),
      otherPath: valueOr(map['other'], def.otherPath),
    );
  }

  /// Determines the destination folder for [item] according to the settings.
  String destinationFor(FileItem item) {
    if (singleDestination) return singlePath;
    if (item.isImage) return imagesPath;
    if (item.isVideo) return videosPath;
    if (item.isAudio) return audioPath;
    return otherPath;
  }

  Map<String, Object> toMap() => {
        'singleDestination': singleDestination,
        'singlePath': singlePath,
        'images': imagesPath,
        'videos': videosPath,
        'audio': audioPath,
        'other': otherPath,
      };

  RescueDestinationSettings copyWith({
    bool? singleDestination,
    String? singlePath,
    String? imagesPath,
    String? videosPath,
    String? audioPath,
    String? otherPath,
  }) {
    return RescueDestinationSettings(
      singleDestination: singleDestination ?? this.singleDestination,
      singlePath: singlePath ?? this.singlePath,
      imagesPath: imagesPath ?? this.imagesPath,
      videosPath: videosPath ?? this.videosPath,
      audioPath: audioPath ?? this.audioPath,
      otherPath: otherPath ?? this.otherPath,
    );
  }
}

/// Loads and persists the Rescue destination settings (stored natively in the
/// app's private files).
class RescueSettingsNotifier extends Notifier<RescueDestinationSettings> {
  bool _loading = false;

  @override
  RescueDestinationSettings build() {
    if (!_loading) {
      _loading = true;
      _load();
    }
    return RescueDestinationSettings.defaults();
  }

  Future<void> _load() async {
    final settings = RescueDestinationSettings.fromMap(
      await ref.read(storageServiceProvider).getRescueSettings(),
    );
    state = settings;
  }

  Future<void> _persist(RescueDestinationSettings settings) async {
    state = settings;
    await ref
        .read(storageServiceProvider)
        .saveRescueSettings(settings.toMap());
  }

  void setSingleDestination(bool value) {
    _persist(state.copyWith(singleDestination: value));
  }

  void setSinglePath(String path) {
    _persist(state.copyWith(singlePath: path));
  }

  void setImagesPath(String path) {
    _persist(state.copyWith(imagesPath: path));
  }

  void setVideosPath(String path) {
    _persist(state.copyWith(videosPath: path));
  }

  void setAudioPath(String path) {
    _persist(state.copyWith(audioPath: path));
  }

  void setOtherPath(String path) {
    _persist(state.copyWith(otherPath: path));
  }

  void resetToDefaults() {
    _persist(RescueDestinationSettings.defaults());
  }
}

final rescueSettingsProvider =
    NotifierProvider<RescueSettingsNotifier, RescueDestinationSettings>(
  RescueSettingsNotifier.new,
);