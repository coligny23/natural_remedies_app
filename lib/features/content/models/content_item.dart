import 'dart:convert';

class ContentItem {
  final String id;
  final String title;
  final String? contentEn;
  final String? contentSw;

  ContentItem({
    required this.id,
    required this.title,
    this.contentEn,
    this.contentSw,
  });

  factory ContentItem.fromJson(Map<String, dynamic> j) {
    final en = (j['contentEn'] ?? j['content_en']) as String?;
    final sw = (j['contentSw'] ?? j['content_sw']) as String?;
    return ContentItem(
      id: j['id'] as String,
      title: j['title'] as String,
      contentEn: en,
      contentSw: sw,
    );
  }

  static List<ContentItem> listFromJsonString(String s) {
    final data = jsonDecode(s) as List;
    return data
        .map((e) => ContentItem.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  // Convenience for search
  String get combinedText =>
      [title, contentEn ?? '', contentSw ?? ''].join(' ');
}
