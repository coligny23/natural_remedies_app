import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Internal key inside the 'bookmarks' box
const _kBookmarkIds = 'ids';

/// Expose the set of bookmarked content IDs.
final bookmarksProvider = StateNotifierProvider<BookmarksController, Set<String>>(
  (ref) => BookmarksController()..load(),
);

class BookmarksController extends StateNotifier<Set<String>> {
  BookmarksController() : super(<String>{});

  Box get _box => Hive.box('bookmarks');

  void load() {
    final raw = _box.get(_kBookmarkIds, defaultValue: const <String>[]) as List;
    state = raw.cast<String>().toSet();
  }

  bool isBookmarked(String id) => state.contains(id);

  void toggle(String id) {
    final next = Set<String>.from(state);
    if (!next.remove(id)) next.add(id);
    state = next;
    // Persist as a List
    _box.put(_kBookmarkIds, next.toList(growable: false));
    if (kDebugMode) {
      // ignore: avoid_print
      print('Bookmarks: ${next.length} items');
    }
  }
}
