import 'dart:convert';

class ContentItem {
  final String id;
  final String title;
  final String? contentEn;
  final String? contentSw;
  final List<String>? tags;

  // NEW
  final String? image; // e.g., assets/images/articles/ginger-root.jpg
  final Map<String, dynamic>? imageMeta; // optional: author, license, credit, etc.

  const ContentItem({
    required this.id,
    required this.title,
    this.contentEn,
    this.contentSw,
    this.tags,
    this.image,
    this.imageMeta,
  });

  /// Flexible JSON factory:
  /// - Accepts camelCase (contentEn/contentSw) or snake_case (content_en/content_sw)
  /// - Accepts optional tags (list of strings)
  /// - Accepts optional image and imageMeta
  factory ContentItem.fromJson(Map<String, dynamic> j) {
    final en = (j['contentEn'] ?? j['content_en']) as String?;
    final sw = (j['contentSw'] ?? j['content_sw']) as String?;

    // tags can be a List<dynamic> -> List<String>
    final rawTags = j['tags'];
    List<String>? parsedTags;
    if (rawTags is List) {
      parsedTags = rawTags.map((e) => e.toString()).toList(growable: false);
    }

    // image is a simple string path (optional)
    final img = j['image'] as String?;

    // imageMeta is an optional Map<String, dynamic>
    final im = j['imageMeta'];
    final Map<String, dynamic>? parsedImageMeta =
        (im is Map<String, dynamic>) ? im : null;

    return ContentItem(
      id: j['id'] as String,
      title: j['title'] as String,
      contentEn: en,
      contentSw: sw,
      tags: parsedTags,
      image: img,
      imageMeta: parsedImageMeta,
    );
  }

  /// Optional: serialize back to JSON (handy for tests/exports).
  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        if (contentEn != null) 'contentEn': contentEn,
        if (contentSw != null) 'contentSw': contentSw,
        if (tags != null) 'tags': tags,
        if (image != null) 'image': image,
        if (imageMeta != null) 'imageMeta': imageMeta,
      };

  /// Accepts either:
  /// - a JSON array: `[ {...}, {...} ]`
  /// - or an object wrapper: `{ "items": [ {...}, ... ] }`
  static List<ContentItem> listFromJsonString(String s) {
    final decoded = jsonDecode(s);

    // If { "items": [...] }
    if (decoded is Map<String, dynamic> && decoded['items'] is List) {
      final list = decoded['items'] as List;
      return list
          .map((e) => ContentItem.fromJson(e as Map<String, dynamic>))
          .toList(growable: false);
    }

    // If [ {...}, {...} ]
    if (decoded is List) {
      return decoded
          .map((e) => ContentItem.fromJson(e as Map<String, dynamic>))
          .toList(growable: false);
    }

    throw const FormatException(
      'Expected a JSON array or an object with an "items" array.',
    );
  }

  /// Convenience for search
  String get combinedText => [
        title,
        contentEn ?? '',
        contentSw ?? '',
        if (tags != null) tags!.join(' '),
      ].join(' ');
}
