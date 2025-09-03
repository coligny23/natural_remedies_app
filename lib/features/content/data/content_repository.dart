import '../models/content_item.dart'; // <- if your file lives under .../model/ change this import

abstract class ContentRepository {
  /// Return all items for a language (fall back handled by implementation).
  Future<List<ContentItem>> getAll({required String lang});

  /// Simple offline search over title + content (en/sw).
  Future<List<ContentItem>> search(String query, {required String lang});
}
