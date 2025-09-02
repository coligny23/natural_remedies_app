import 'dart:convert';

class ContentItem {
  final String id;
  final String type;               // article | chunk | faq
  final String title;
  final String section;
  final String? contentEn;
  final String? contentSw;
  final String langOriginal;       // en | sw
  final String translationStatus;  // original | machine | human
  final List<String> tags;
  final String? source;
  final List<int>? pageRange;

  const ContentItem({
    required this.id,
    required this.type,
    required this.title,
    required this.section,
    required this.contentEn,
    required this.contentSw,
    required this.langOriginal,
    required this.translationStatus,
    required this.tags,
    required this.source,
    required this.pageRange,
  });

  factory ContentItem.fromJson(Map<String, dynamic> j) => ContentItem(
    id: j['id'] as String,
    type: j['type'] as String,
    title: j['title'] as String,
    section: j['section'] as String? ?? '',
    contentEn: j['content_en'] as String?,
    contentSw: j['content_sw'] as String?,
    langOriginal: j['lang_original'] as String? ?? 'en',
    translationStatus: j['translation_status'] as String? ?? 'original',
    tags: (j['tags'] as List?)?.map((e) => e.toString()).toList() ?? const [],
    source: j['source'] as String?,
    pageRange: (j['page_range'] as List?)?.map((e) => int.tryParse('$e') ?? 0).toList(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'title': title,
    'section': section,
    'content_en': contentEn,
    'content_sw': contentSw,
    'lang_original': langOriginal,
    'translation_status': translationStatus,
    'tags': tags,
    'source': source,
    'page_range': pageRange,
  };

  /// Preferred language with fallback (sw → en, en → sw).
  String? textFor(String lang) {
    if (lang == 'sw') return contentSw ?? contentEn;
    return contentEn ?? contentSw;
  }

  static List<ContentItem> listFromJsonString(String jsonStr) {
    final data = json.decode(jsonStr) as List;
    return data.map((e) => ContentItem.fromJson(e)).toList();
  }
}
