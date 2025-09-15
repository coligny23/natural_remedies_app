import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../content/data/content_repository_assets.dart';
import '../content/models/content_item.dart';

/// App language (en/sw)
final languageCodeProvider = StateProvider<String>((_) => 'en');

/// Use the concrete assets repo (auto-discovers all assets/corpus/<lang>/*.json)
final contentRepositoryProvider = Provider<AssetsContentRepository>(
  (_) => const AssetsContentRepository(),
);

/// Load all content for the current language
final contentListProvider = FutureProvider<List<ContentItem>>((ref) async {
  final repo = ref.watch(contentRepositoryProvider);
  final lang = ref.watch(languageCodeProvider);
  return repo.load(lang);
});

/// Search UI state
final searchQueryProvider = StateProvider<String>((_) => '');

/// Instant in-memory filtering over loaded items
final searchResultsProvider = Provider<List<ContentItem>>((ref) {
  final q = ref.watch(searchQueryProvider).trim().toLowerCase();
  final itemsAsync = ref.watch(contentListProvider);
  final lang = ref.watch(languageCodeProvider);

  return itemsAsync.maybeWhen(
    data: (items) {
      if (q.isEmpty) return <ContentItem>[];
      return items.where((it) {
        final body = (lang == 'sw')
            ? (it.contentSw ?? it.contentEn ?? '')
            : (it.contentEn ?? it.contentSw ?? '');
        return it.title.toLowerCase().contains(q) ||
               body.toLowerCase().contains(q);
      }).toList(growable: false);
    },
    orElse: () => <ContentItem>[],
  );
});
