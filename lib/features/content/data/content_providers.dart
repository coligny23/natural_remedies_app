import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'content_repository.dart';
import 'content_repository_assets.dart';
import '../models/content_item.dart';

/// App language (toggle in Settings): 'en' or 'sw'
final appLangProvider = StateProvider<String>((_) => 'en');

final contentRepoProvider = Provider<ContentRepository>((_) => AssetsContentRepository());

final allContentProvider = FutureProvider<List<ContentItem>>((ref) {
  final lang = ref.watch(appLangProvider);
  return ref.watch(contentRepoProvider).getAll(lang: lang);
});

final searchProvider = FutureProvider.family<List<ContentItem>, String>((ref, query) {
  final lang = ref.watch(appLangProvider);
  return ref.watch(contentRepoProvider).search(query, lang: lang);
});
