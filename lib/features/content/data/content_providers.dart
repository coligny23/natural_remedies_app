import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/content_item.dart';
import 'content_repository_assets.dart';

final assetsRepositoryProvider = Provider<AssetsContentRepository>(
  (_) => const AssetsContentRepository(),
);

final contentByLangProvider = FutureProvider.family<List<ContentItem>, String>((ref, lang) async {
  final repo = ref.watch(assetsRepositoryProvider);
  return repo.load(lang);
});
