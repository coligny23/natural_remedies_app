import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/content_item.dart';
import 'content_repository.dart';
import 'content_repository_assets.dart' as assets;

/// Repository (use the interface type for flexibility)
final contentRepositoryProvider = Provider<ContentRepository>(
  (_) => const assets.AssetsContentRepository(),
);

/// If you already have a language provider elsewhere, prefer wiring to that.
/// Otherwise expose a family so callers pass 'en' or 'sw'.
final contentByLangProvider =
    FutureProvider.family<List<ContentItem>, String>((ref, lang) async {
  final repo = ref.watch(contentRepositoryProvider);
  return repo.getAll(lang: lang); // ⬅️ was `load(lang)` → now `getAll(lang: lang)`
});
