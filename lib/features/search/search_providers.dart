import 'package:flutter_riverpod/flutter_riverpod.dart';

// ✅ import the interface AND the implementation (aliased)
import '../content/data/content_repository.dart';
import '../content/data/content_repository_assets.dart' as assets;

// If your file is .../model/content_item.dart change this path accordingly
import '../content/models/content_item.dart';

// Language (keep simple for Day 4)
final languageCodeProvider = StateProvider<String>((_) => 'en');

// Repository (typed to the interface)
final contentRepositoryProvider = Provider<ContentRepository>(
  (_) => const assets.AssetsContentRepository(),
);

// Load all content once per language
final contentListProvider = FutureProvider<List<ContentItem>>((ref) async {
  final repo = ref.watch(contentRepositoryProvider);
  final lang = ref.watch(languageCodeProvider);
  return repo.getAll(lang: lang); // ✅ use interface method
});

// Search query
final searchQueryProvider = StateProvider<String>((_) => '');

// Instant in-memory filtering
final searchResultsProvider = Provider<List<ContentItem>>((ref) {
  final q = ref.watch(searchQueryProvider).trim().toLowerCase();
  final itemsAsync = ref.watch(contentListProvider);

  return itemsAsync.when(
    data: (items) =>
        q.isEmpty ? <ContentItem>[] : items.where((it) => it.combinedText.contains(q)).toList(growable: false),
    loading: () => <ContentItem>[],
    error: (_, __) => <ContentItem>[],
  );
});
