import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/file_item.dart';

class SelectionNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() => {};

  void toggle(FileItem item) {
    final current = Set<String>.from(state);
    if (current.contains(item.uri)) {
      current.remove(item.uri);
    } else {
      current.add(item.uri);
    }
    state = current;
  }

  void selectAll(List<FileItem> items) {
    state = items.map((e) => e.uri).toSet();
  }

  void clear() {
    state = {};
  }

  bool isSelected(String uri) => state.contains(uri);
}

final selectionProvider = NotifierProvider<SelectionNotifier, Set<String>>(() {
  return SelectionNotifier();
});

final isSelectionModeProvider = Provider<bool>((ref) {
  return ref.watch(selectionProvider).isNotEmpty;
});
