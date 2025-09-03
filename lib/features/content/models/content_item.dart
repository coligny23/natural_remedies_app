import 'dart:convert';

class ContentItem {
  final String id;
  final String type; // "herb" | "condition" | "principle" | "chunk"
  final String title;
  final String? section; // optional (e.g., "condition")
  final String? facet; // optional (e.g., "symptoms")
  final String? contentEn;
  final String? contentSw;

  const ContentItem({
    required this.id,
    required this.type,
    required this.title,
    this.section,
    this.facet,
    this.contentEn,
    this.contentSw,
  });

  factory ContentItem.fromJson(Map<String, dynamic> j) => ContentItem(
        id: j['id'] as String,
        type: j['type'] as String? ?? 'chunk',
        title: j['title'] as String? ?? '',
        section: j['section'] as String?,
        facet: j['facet'] as String?,
        contentEn: j['content_en'] as String?,
        contentSw: j['content_sw'] as String?,
      );

  static List<ContentItem> listFromJsonString(String jsonStr) {
    final raw = json.decode(jsonStr) as List;
    return raw
        .map((e) => ContentItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Aggregate text for simple search (title + both languages).
  String get combinedText => [
        title,
        contentEn ?? '',
        contentSw ?? '',
      ].where((s) => s.isNotEmpty).join(' ').toLowerCase();
}
