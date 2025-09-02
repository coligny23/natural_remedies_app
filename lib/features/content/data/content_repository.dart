import '../models/content_item.dart';

abstract class ContentRepository {
  Future<List<ContentItem>> getAll({String lang = 'en'});
  Future<ContentItem?> getById(String id, {String lang = 'en'});
  Future<List<ContentItem>> search(String query, {String lang = 'en', int limit = 50});
}
