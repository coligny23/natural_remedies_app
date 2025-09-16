import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

const _box = 'bookmarks';
const _key = 'ids';

class BookmarksNotifier extends StateNotifier<Set<String>> {
  BookmarksNotifier() : super(_read());

  static Set<String> _read() {
    final box = Hive.box(_box);
    final list = (box.get(_key) as List?)?.cast<String>() ?? const <String>[];
    return Set<String>.from(list);
  }

  void _persist() => Hive.box(_box).put(_key, state.toList(growable: false));

  bool contains(String id) => state.contains(id);

  void toggle(String id) {
    final next = Set<String>.from(state);
    next.contains(id) ? next.remove(id) : next.add(id);
    state = next;
    _persist();
  }

  void clear() {
    state = <String>{};
    _persist();
  }
}

final bookmarksProvider =
    StateNotifierProvider<BookmarksNotifier, Set<String>>(
  (_) => BookmarksNotifier(),
);
