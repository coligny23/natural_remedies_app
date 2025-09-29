// lib/features/search/search_history_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

const _boxName = 'search_history_v1';

final searchHistoryProvider =
    StateNotifierProvider<SearchHistoryNotifier, List<String>>((ref) {
  return SearchHistoryNotifier();
});

class SearchHistoryNotifier extends StateNotifier<List<String>> {
  SearchHistoryNotifier() : super([]) {
    _load();
  }

  Future<void> _load() async {
    final box = await Hive.openBox<String>(_boxName);
    state = box.values.toList().reversed.toList();
  }

  Future<void> add(String query) async {
    final q = query.trim();
    if (q.isEmpty) return;
    final box = await Hive.openBox<String>(_boxName);

    // de-dup: remove old, then add so it's the newest entry
    await box.delete(q);
    await box.put(q, q);

    state = box.values.toList().reversed.toList();
  }

  Future<void> clear() async {
    final box = await Hive.openBox<String>(_boxName);
    await box.clear();
    state = [];
  }
}
