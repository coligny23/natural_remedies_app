import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'bookmarks_controller.dart';

final isBookmarkedProvider = Provider.family<bool, String>((ref, id) {
  final set = ref.watch(bookmarksProvider);
  return set.contains(id);
});
