import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/file_item.dart';
import 'storage_provider.dart';

/// The root of shared internal storage.
const String storageRoot = '/storage/emulated/0';

/// Holds the current navigation path as a list of folder names.
/// Empty list = root (/storage/emulated/0).
class CurrentPathNotifier extends Notifier<List<String>> {
  @override
  List<String> build() {
    return [];
  }

  void navigateTo(String folderName) {
    state = [...state, folderName];
  }

  void goBack() {
    if (state.isNotEmpty) {
      state = List.from(state)..removeLast();
    }
  }

  void goToRoot() {
    state = [];
  }

  /// Jumps directly to an absolute directory (used by "Open Location").
  /// [segments] are the folder names below the storage root.
  void resetTo(List<String> segments) {
    state = List<String>.from(segments);
  }

  /// Builds the absolute path for the current navigation state.
  String get currentAbsolutePath {
    if (state.isEmpty) return storageRoot;
    return '$storageRoot/${state.join('/')}';
  }
}

final currentPathProvider = NotifierProvider<CurrentPathNotifier, List<String>>(
  () {
    return CurrentPathNotifier();
  },
);

/// The absolute path of the current directory.
final currentAbsolutePathProvider = Provider<String>((ref) {
  final path = ref.watch(currentPathProvider);
  if (path.isEmpty) return storageRoot;
  return '$storageRoot/${path.join('/')}';
});

/// Lists the contents of the current directory.
/// Watches the actual path state so it rebuilds when navigation changes.
final currentDirectoryProvider = FutureProvider<List<FileItem>>((ref) async {
  final storageService = ref.watch(storageServiceProvider);
  final path = ref.watch(currentAbsolutePathProvider);
  return await storageService.listDirectory(path);
});
