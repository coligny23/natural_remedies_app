import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/content_item.dart';
import '../../search/search_providers.dart';

/// Look up a single ContentItem by id from the in-memory list.
/// Returns null if the item isn't found or content hasn't loaded yet.
final contentByIdProvider = Provider.family<ContentItem?, String>((ref, id) {
  final items = ref.watch(contentListProvider).maybeWhen(
    data: (list) => list,
    orElse: () => const <ContentItem>[],
  );

  // Avoid firstWhere/Null because orElse can't return null.
  final match = items.where((e) => e.id == id);
  return match.isEmpty ? null : match.first;
});
