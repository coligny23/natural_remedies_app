import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../../search/search_providers.dart'; // for title lookup
import '../models/content_item.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';


// Add near the top of the file (outside classes)

/// Create a stable fragment id from section title (e.g., "Symptoms & Causes" -> "symptoms-causes")
String sectionSlug(String title) {
  final t = title.trim().toLowerCase();
  final s = t
      .replaceAll(RegExp(r'[^a-z0-9\s-]'), '')  // remove punctuation
      .replaceAll(RegExp(r'\s+'), '-')          // spaces -> dashes
      .replaceAll(RegExp(r'-{2,}'), '-')
      .replaceAll(RegExp(r'^-|-$'), '');
  return s.isEmpty ? 'section' : s;
}

/// Build a TOC from raw text using parseSections()
List<({String title, String slug})> buildToc(String rawText) {
  final secs = parseSections(rawText);
  return [
    for (final s in secs) (title: s.title, slug: sectionSlug(s.title)),
  ];
}

/// A parsed section of the article (e.g., SYMPTOMS:, CAUSES:, TREATMENT:)
class ArticleSection {
  final String title; // e.g., "Symptoms"
  final String body;  // raw text for the section
  ArticleSection(this.title, this.body);
}

/// Parse plain text into sections.
/// Heuristic: a line in ALL CAPS (or Title Case) ending with ":" starts a section.
List<ArticleSection> parseSections(String text) {
  final lines = text.split('\n');
  final sections = <ArticleSection>[];
  String currentTitle = 'Overview';
  final buf = StringBuffer();

  final isHeader = RegExp(r'^\s*([A-Z][A-Z\s/()-]{2,}|[A-Z][a-z]+(?:\s+[A-Z][a-z]+)*)\s*:\s*$');

  void flush() {
    final b = buf.toString().trim();
    if (b.isNotEmpty) sections.add(ArticleSection(_normalizeTitle(currentTitle), b));
    buf.clear();
  }

  for (final raw in lines) {
    final m = isHeader.firstMatch(raw);
    if (m != null) {
      flush();
      currentTitle = m.group(1)!;
    } else {
      buf.writeln(raw);
    }
  }
  flush();

  // If there was exactly one nameless chunk, normalize as Overview
  if (sections.isEmpty) {
    sections.add(ArticleSection('Overview', text.trim()));
  }
  return sections;
}

String _normalizeTitle(String t) {
  t = t.trim().replaceAll(RegExp(r'\s+'), ' ');
  // "SYMPTOMS" -> "Symptoms"
  if (t.toUpperCase() == t) {
    t = t.toLowerCase().split(' ').map((w) => w.isEmpty ? w : (w[0].toUpperCase() + w.substring(1))).join(' ');
  }
  return t;
}

/// Split paragraph into bullet list items if it contains leading markers.
List<String> maybeBullets(String body) {
  final lines = body.split('\n').map((l) => l.trimRight()).toList();
  final bulletLike = lines.where((l) => l.startsWith('• ') || l.startsWith('- ') || l.startsWith('– ')).length;
  if (bulletLike >= (lines.length / 2)) {
    // Treat as bullets (strip markers)
    return lines
        .where((l) => l.trim().isNotEmpty)
        .map((l) => l.replaceFirst(RegExp(r'^[•\-–]\s*'), ''))
        .toList();
  }
  return const [];
}

/// Build a RichText with clickable cross-links of the form [[id]],
/// where id matches ContentItem.id (e.g., [[herb-ginger]]).
InlineSpan _linkSpan(BuildContext context, String title, VoidCallback onTap) {
  final theme = Theme.of(context);
  return TextSpan(
    text: title,
    style: theme.textTheme.bodyLarge?.copyWith(
      color: theme.colorScheme.primary,
      decoration: TextDecoration.underline,
    ),
    recognizer: TapGestureRecognizer()..onTap = onTap,
  );
}

List<InlineSpan> linkifyParagraph(
  BuildContext context, {
  required String text,
  required String? Function(String id) resolveTitle,
  required void Function(String id) onTapId,
}) {
  final spans = <InlineSpan>[];
  final re = RegExp(r'\[\[([a-z0-9-]+)\]\]');
  int last = 0;
  for (final m in re.allMatches(text)) {
    if (m.start > last) {
      spans.add(TextSpan(text: text.substring(last, m.start)));
    }
    final id = m.group(1)!;
    final title = resolveTitle(id) ?? id;
    spans.add(_linkSpan(context, title, () => onTapId(id)));
    last = m.end;
  }
  if (last < text.length) spans.add(TextSpan(text: text.substring(last)));
  return spans;
}

/// Render the full article body as a list of widgets (headings, paragraphs, bullets).
/// Uses Riverpod to look up titles for cross-links.
class ArticleBody extends ConsumerWidget {
  final String rawText;
  final void Function(String id) onTapLink;
  const ArticleBody({super.key, required this.rawText, required this.onTapLink});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Build a local title resolver from current content list
    final itemsAsync = ref.watch(contentListProvider);
    final resolveTitle = (String id) {
      return itemsAsync.maybeWhen(
        data: (items) => items.firstWhere(
          (e) => e.id == id,
          orElse: () => ContentItem(id: id, title: id, contentEn: '', contentSw: ''),
        ).title,
        orElse: () => null,
      );
    };

    final sections = parseSections(rawText);
    final widgets = <Widget>[];

    for (final s in sections) {
      // Section heading
      widgets.add(Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 6),
        child: Text(
          s.title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
      ));

      // Bullets vs paragraphs
      final bullets = maybeBullets(s.body);
      if (bullets.isNotEmpty) {
        widgets.addAll(
          bullets.map((b) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('•  '),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: Theme.of(context).textTheme.bodyLarge,
                      children: linkifyParagraph(
                        context,
                        text: b,
                        resolveTitle: resolveTitle,
                        onTapId: onTapLink,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          )),
        );
      } else {
        // Normal paragraph(s)
        for (final para in s.body.split('\n\n')) {
          if (para.trim().isEmpty) continue;
          widgets.add(
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: RichText(
                text: TextSpan(
                  style: Theme.of(context).textTheme.bodyLarge,
                  children: linkifyParagraph(
                    context,
                    text: para.trim(),
                    resolveTitle: resolveTitle,
                    onTapId: onTapLink,
                  ),
                ),
              ),
            ),
          );
        }
      }
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: widgets);
  }
}
