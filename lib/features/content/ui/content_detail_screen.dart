// lib/features/content/ui/content_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import '../../progress/progress_tracker.dart';
import '../../../app/theme/app_theme.dart'; // AppElevations, GlossyCardTheme




import '../../content/data/reading_progress_repository.dart'; // (ok if unused now)
import 'content_renderer.dart'; // parseSections, maybeBullets, linkifyParagraph, sectionSlug, buildToc
import '../../search/search_providers.dart'; // languageCodeProvider, contentListProvider
import '../data/content_lookup_provider.dart'; // contentByIdProvider(id)
import '../../saved/bookmarks_controller.dart'; // bookmarksProvider
import '../models/content_item.dart'; // for types in helpers

class ContentDetailScreen extends ConsumerStatefulWidget {
  final String id;
  final String? initialSection;
  const ContentDetailScreen({super.key, required this.id, this.initialSection});

  @override
  ConsumerState<ContentDetailScreen> createState() => _ContentDetailScreenState();
}

class _ContentDetailScreenState extends ConsumerState<ContentDetailScreen> {
  late final ScrollController _scroll = ScrollController();
  final Map<String, GlobalKey> _sectionKeys = {}; // slug -> key
  String? _lastSection;
  bool _restoredOnce = false;

  @override
  void initState() {
    super.initState();
    // Minimal “recently viewed” markers you already had
    final box = Hive.box('reading_progress');
    final now = DateTime.now();
    box
      ..put('last_id', widget.id)
      ..put('last_opened_at', now)
      ..put('time_${widget.id}', now);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final itemsAsync = ref.watch(contentListProvider);
    final lang = ref.watch(languageCodeProvider);
    final glossy = Theme.of(context).extension<GlossyCardTheme>()!;
    final elev   = Theme.of(context).extension<AppElevations>()!;


    return itemsAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
      // ⬇ name the loaded list `allItems` so we can compute "Related"
      data: (allItems) {
        final item = ref.watch(contentByIdProvider(widget.id));
        if (item == null) {
          return const Scaffold(body: Center(child: Text('Not found')));
        }

        final body = (lang == 'sw')
            ? (item.contentSw ?? item.contentEn ?? '')
            : (item.contentEn ?? item.contentSw ?? '');
        // Day 30 changes
        final hasImage = (item.image ?? '').isNotEmpty;
        final credit = item.imageMeta?['credit'] as String?;

        // --- Day 24: English fallback badge helpers ---
        final isSwSelected = (lang == 'sw');
        final hasSw = (item.contentSw != null && item.contentSw!.trim().isNotEmpty);
        final isFallback = isSwSelected && !hasSw;


        final isSaved = ref.watch(bookmarksProvider).contains(item.id);
        final toc = buildToc(body); // [{title, slug}, ...]

        // Kick a one-time restore after first layout (keys must be registered)
        WidgetsBinding.instance.addPostFrameCallback((_) => _maybeRestore(body));

        return Scaffold(
          appBar: AppBar(
            title: Text(item.title),
            actions: [
              IconButton(
                tooltip: isSaved ? 'Remove bookmark' : 'Add bookmark',
                icon: Icon(isSaved ? Icons.bookmark : Icons.bookmark_border),
                onPressed: () {
                  ref.read(bookmarksProvider.notifier).toggle(item.id);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(isSaved ? 'Removed from Saved' : 'Saved for later'),
                      behavior: SnackBarBehavior.floating,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
              ),
              IconButton(
                tooltip: 'Copy',
                icon: const Icon(Icons.copy),
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: '${item.title}\n\n$body'));
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Copied to clipboard')),
                  );
                },
              ),
              IconButton(
                tooltip: 'Share',
                icon: const Icon(Icons.ios_share),
                onPressed: () {
                  final shareSection = _lastSection;
                  final deepPath = shareSection == null
                      ? '/article/${item.id}'
                      : '/article/${item.id}?section=$shareSection';
                  SharePlus.instance.share(
                    ShareParams(
                      text: '${item.title}\n$deepPath\n\n$body',
                      subject: item.title,
                    ),
                  );
                },
              ),
            ],
          ),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ProgressTracker(
                  articleId: widget.id,               // <-- use the current article id
                  sectionId: _lastSection,            // <-- optional: current visible section (your field)
                  child: NotificationListener<ScrollNotification>(
                    onNotification: (n) {
                      if (n is ScrollUpdateNotification) {
                        _saveProgress(widget.id, section: _lastSection, offset: _scroll.offset);
                      }
                      return false;
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // --- HERO IMAGE (big banner) ---
                        if (hasImage) ...[
                          Hero(
                            tag: 'article-image-${item.id}', // MUST match the tag from the Search thumbnail
                            child: ClipRRect(
                                borderRadius: glossy.borderRadius,
                                child: Image.asset(
                                  item.image!,
                                  height: 220,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      const SizedBox(height: 220, child: Center(child: Icon(Icons.image_not_supported))),
                                ),
                              ),

                          ),
                          const SizedBox(height: 8),
                          if (credit != null && credit.trim().isNotEmpty)
                            Text(
                              credit,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context).hintColor,
                                  ),
                            ),
                          const SizedBox(height: 16),
                        ],

                        if (toc.length > 1) ...[
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final e in toc)
                                ActionChip(
                                  label: Text(e.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                                  onPressed: () => _scrollTo(e.slug),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                        ],
                        // --- Day 24: show fallback badge when SW selected but article lacks contentSw ---
                        if (isFallback)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Card(
                              color: Colors.amber.shade50,
                              child: const ListTile(
                                dense: true,
                                leading: Icon(Icons.translate),
                                title: Text('English content shown'),
                                subtitle: Text('Swahili translation for this article is coming soon.'),
                              ),
                            ),
                        ),

// ================== ACCORDION (Treatment / Causes / Symptoms / Overview) ==================
                          Builder(builder: (context) {
                            // Prefer labeled-headings split from the raw body:
                            Map<_Bucket, List<String>> buckets = _extractBucketsFromRaw(body);

                            // If that failed (no labeled headings), fall back to parsed sections:
                            if (buckets.isEmpty) {
                              final secs = parseSections(body);
                              buckets = _categorizeSections(secs);
                            }

                            final ordered = <_Bucket>[
                              if (buckets[_Bucket.treatment]?.isNotEmpty == true) _Bucket.treatment,
                              if (buckets[_Bucket.causes]?.isNotEmpty == true) _Bucket.causes,
                              if (buckets[_Bucket.symptoms]?.isNotEmpty == true) _Bucket.symptoms,
                              if (buckets[_Bucket.overview]?.isNotEmpty == true) _Bucket.overview,
                            ];

                            if (ordered.isEmpty) {
                              // show nothing here; fallback renderer below will handle it
                              return const SizedBox.shrink();
                            }

                            return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                decoration: glossy.bodyDecoration().copyWith(
                                  // give it a smidge more lift using your elevation scale
                                  boxShadow: glossy.shadows.map((s) => s.copyWith(blurRadius: s.blurRadius + elev.base)).toList(),
                                ),
                                child: Theme(
                                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                                  child: ExpansionPanelList.radio(
                                    animationDuration: const Duration(milliseconds: 220),
                                    expandedHeaderPadding: EdgeInsets.zero,
                                    elevation: 0,
                                    initialOpenPanelValue: ordered.contains(_Bucket.treatment)
                                        ? 'bucket-${_Bucket.treatment}'
                                        : 'bucket-${ordered.first}',
                                    children: [
                                      for (final b in ordered)
                                        ExpansionPanelRadio(
                                          value: 'bucket-$b',
                                          canTapOnHeader: true,
                                          headerBuilder: (ctx, isOpen) {
                                            final on = _onHeader(context);
                                            // Use glossy gradient for panel header
                                            return ClipRRect(
                                              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)), // safe top rounding
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                                decoration: glossy.headerDecoration(),
                                                child: Row(
                                                  children: [
                                                    Container(
                                                      decoration: BoxDecoration(
                                                        color: on.withOpacity(0.12),
                                                        borderRadius: BorderRadius.circular(10),
                                                      ),
                                                      padding: const EdgeInsets.all(8),
                                                      child: Icon(_bucketIcon(b), color: on, size: 20),
                                                    ),
                                                    const SizedBox(width: 12),
                                                    Expanded(
                                                      child: Text(
                                                        _bucketTitleLocalized(b, lang),
                                                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                                              color: on,
                                                              fontWeight: FontWeight.w700,
                                                              letterSpacing: 0.2,
                                                            ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            );
                                          },
                                          // glossy body
                                          body: AnimatedContainer(
                                            duration: const Duration(milliseconds: 180),
                                            curve: Curves.easeOut,
                                            decoration: glossy.bodyDecoration().copyWith(
                                              // keep only a gentle inner lift
                                              boxShadow: glossy.shadows.map((s) => s.copyWith(blurRadius: s.blurRadius + elev.small)).toList(),
                                              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
                                            ),
                                            child: Padding(
                                              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                                              child: _FancyBody(
                                                paragraphs: buckets[b]!,
                                                accent: _bucketGradient(context, b).first,
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              );

                          }),
                          const SizedBox(height: 16),


                        // If accordion was empty, render your original long article as a fallback:
                        Builder(builder: (context) {
                          final secs = parseSections(body);
                          final buckets = _categorizeSections(secs);
                          final ordered = <_Bucket>[
                            if (buckets[_Bucket.treatment]?.isNotEmpty == true) _Bucket.treatment,
                            if (buckets[_Bucket.causes]?.isNotEmpty == true) _Bucket.causes,
                            if (buckets[_Bucket.symptoms]?.isNotEmpty == true) _Bucket.symptoms,
                            if (buckets[_Bucket.overview]?.isNotEmpty == true) _Bucket.overview,
                          ];
                          if (ordered.isNotEmpty) {
                            return const SizedBox.shrink(); // we already showed accordion
                          }

                          // ---------- ORIGINAL LONG ARTICLE (fallback) ----------
                          return SizedBox(
                            height: 400, // placeholder height so Expanded below takes it
                            child: const SizedBox.shrink(),
                          );
                        }),
                        // =====================================================================

                        // Keep your scrollable long article only when accordion is empty:
                        Expanded(
                          child: Builder(builder: (context) {
                            final secs = parseSections(body);
                            final buckets = _categorizeSections(secs);
                            final ordered = <_Bucket>[
                              if (buckets[_Bucket.treatment]?.isNotEmpty == true) _Bucket.treatment,
                              if (buckets[_Bucket.causes]?.isNotEmpty == true) _Bucket.causes,
                              if (buckets[_Bucket.symptoms]?.isNotEmpty == true) _Bucket.symptoms,
                              if (buckets[_Bucket.overview]?.isNotEmpty == true) _Bucket.overview,
                            ];
                            if (ordered.isNotEmpty) {
                              // Accordion path: nothing else to render below
                              return const SizedBox.shrink();
                            }

                            // Fallback to your existing renderer with keys/sections
                            return SingleChildScrollView(
                              controller: _scroll,
                              child: _ArticleWithKeys(
                                rawText: body,
                                registerKey: (slug, key) => _sectionKeys[slug] = key,
                                onVisibleSection: (slug) => _lastSection = slug,
                                onTapLink: (id) {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(builder: (_) => ContentDetailScreen(id: id)),
                                  );
                                },
                              ),
                            );
                          }),
                        ),


                        // Related block unchanged
                        const SizedBox(height: 16),
                        Builder(builder: (context) {
                          final related = _relatedFor(item, allItems, lang, k: 3);
                          if (related.isEmpty) return const SizedBox.shrink();
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Related', style: Theme.of(context).textTheme.titleMedium),
                              const SizedBox(height: 8),
                              ...related.map(
                                (r) => ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(r.title),
                                  subtitle: Text(_familyPrefix(r.id)),
                                  onTap: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(builder: (_) => ContentDetailScreen(id: r.id)),
                                    );
                                  },
                                ),
                              ),
                            ],
                          );
                        }),
                      ],
                    ),
                  ),
                ),
              )

            ),
          ),
        );
      },
    );
  }

  // --- Related helpers (local; no repo dependency) ---

  String _familyPrefix(String id) => id.split('-').first; // herb-*, disease-*, principle-*

  Set<String> _wordsOf(String s) {
    final lower = s.toLowerCase();
    final re = RegExp(r'[a-z0-9]+');
    return re.allMatches(lower).map((m) => m.group(0)!).toSet();
  }

  List<ContentItem> _relatedFor(
    ContentItem it,
    List<ContentItem> all,
    String lang, {
    int k = 3,
  }) {
    final family = _familyPrefix(it.id);
    final baseWords = _wordsOf(it.title);

    final scored = <MapEntry<ContentItem, int>>[];
    for (final other in all) {
      if (other.id == it.id) continue;
      int score = 0;

      // Same family bonus
      if (_familyPrefix(other.id) == family) score += 2;

      // Title word overlap
      final overlap = baseWords.intersection(_wordsOf(other.title)).length;
      if (overlap > 0) score += overlap;

      if (score > 0) scored.add(MapEntry(other, score));
    }

    scored.sort((a, b) {
      final byScore = b.value.compareTo(a.value);
      if (byScore != 0) return byScore;
      return a.key.title.compareTo(b.key.title);
    });

    return [for (final e in scored.take(k)) e.key];
  }

  // --- Scroll/restore/progress as you had ---

  void _scrollTo(String slug) {
    final key = _sectionKeys[slug];
    final ctx = key?.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
      alignment: 0.06,
    );
  }

  Future<void> _maybeRestore(String body) async {
    if (_restoredOnce) return;
    // If we have a deep-linked section, prefer it
    if (widget.initialSection != null && widget.initialSection!.isNotEmpty) {
      if (_sectionKeys.containsKey(widget.initialSection)) {
        _scrollTo(widget.initialSection!);
        _restoredOnce = true;
        return;
      }
    }
    // Else try saved progress (section first, fallback to offset)
    final box = Hive.box('reading_progress');
    final savedSection = box.get('pos_${widget.id}_section') as String?;
    final savedOffset = (box.get('pos_${widget.id}_offset') as num?)?.toDouble();

    if (savedSection != null && _sectionKeys.containsKey(savedSection)) {
      _scrollTo(savedSection);
      _restoredOnce = true;
      return;
    }
    if (savedOffset != null && savedOffset > 0 && _scroll.hasClients) {
      _scroll.jumpTo(savedOffset.clamp(0, _scroll.position.maxScrollExtent));
      _restoredOnce = true;
    }
  }

  Future<void> _saveProgress(String id, {String? section, double? offset}) async {
    final box = Hive.box('reading_progress');
    await box.put('pos_${id}_section', section);
    if (offset != null) await box.put('pos_${id}_offset', offset);
  }
}

/// Render article with section anchors (keys) so we can scroll to them and
/// detect which one is visible (for progress persistence).
class _ArticleWithKeys extends ConsumerStatefulWidget {
  final String rawText;
  final void Function(String slug, GlobalKey key) registerKey;
  final void Function(String slug) onVisibleSection;
  final void Function(String id) onTapLink;

  const _ArticleWithKeys({
    required this.rawText,
    required this.registerKey,
    required this.onVisibleSection,
    required this.onTapLink,
  });

  @override
  ConsumerState<_ArticleWithKeys> createState() => _ArticleWithKeysState();
}

class _ArticleWithKeysState extends ConsumerState<_ArticleWithKeys> {
  @override
  Widget build(BuildContext context) {
    final secs = parseSections(widget.rawText);
    final children = <Widget>[];

    for (final s in secs) {
      final slug = sectionSlug(s.title);
      final key = GlobalKey();
      widget.registerKey(slug, key);
      children.add(
        KeyedSubtree(
          key: key,
          child: _SectionBlock(
            title: s.title,
            body: s.body,
            onTapLink: widget.onTapLink,
            onBecameVisible: () => widget.onVisibleSection(slug),
          ),
        ),
      );
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: children);
  }
}

class _SectionBlock extends StatefulWidget {
  final String title;
  final String body;
  final void Function(String id) onTapLink;
  final VoidCallback onBecameVisible;

  const _SectionBlock({
    required this.title,
    required this.body,
    required this.onTapLink,
    required this.onBecameVisible,
  });

  @override
  State<_SectionBlock> createState() => _SectionBlockState();
}

class _SectionBlockState extends State<_SectionBlock> {
  bool _notified = false;

  @override
  Widget build(BuildContext context) {
    final bullets = maybeBullets(widget.body);

    // Notify "visible" once after first layout
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_notified && mounted) {
        _notified = true;
        widget.onBecameVisible();
      }
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 6),
          child: Text(
            widget.title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        if (bullets.isNotEmpty)
          ...bullets.map(
            (b) => Padding(
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
                          resolveTitle: (_) => null, // title lookups already in ArticleBody
                          onTapId: widget.onTapLink,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (bullets.isEmpty)
          ...widget.body
              .split('\n\n')
              .where((p) => p.trim().isNotEmpty)
              .map(
                (p) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: RichText(
                    text: TextSpan(
                      style: Theme.of(context).textTheme.bodyLarge,
                      children: linkifyParagraph(
                        context,
                        text: p.trim(),
                        resolveTitle: (_) => null,
                        onTapId: widget.onTapLink,
                      ),
                    ),
                  ),
                ),
              ),
      ],
    );
  }
}

enum _Bucket { treatment, causes, symptoms, overview }

String _bucketTitle(_Bucket b) {
  switch (b) {
    case _Bucket.treatment: return 'Treatment';
    case _Bucket.causes:    return 'Causes';
    case _Bucket.symptoms:  return 'Symptoms';
    case _Bucket.overview:  return 'Overview';
  }
}

String _bucketTitleLocalized(_Bucket b, String lang) {
  final isSw = (lang.toLowerCase() == 'sw');
  if (isSw) {
    switch (b) {
      case _Bucket.treatment: return 'Matibabu';
      case _Bucket.causes:    return 'Sababu';
      case _Bucket.symptoms:  return 'Dalili';
      case _Bucket.overview:  return 'Muhtasari';
    }
  } else {
    switch (b) {
      case _Bucket.treatment: return 'Treatment';
      case _Bucket.causes:    return 'Causes';
      case _Bucket.symptoms:  return 'Symptoms';
      case _Bucket.overview:  return 'Overview';
    }
  }
}

// Soft, theme-aware colors for headers/bodies
Color _bucketHeaderColor(BuildContext c, _Bucket b) {
  final s = Theme.of(c).colorScheme;
  switch (b) {
    case _Bucket.treatment: return s.primaryContainer;
    case _Bucket.causes:    return s.tertiaryContainer;
    case _Bucket.symptoms:  return s.secondaryContainer;
    case _Bucket.overview:  return s.surfaceVariant;
  }
}

Color _bucketBodyColor(BuildContext c, _Bucket b) {
  final s = Theme.of(c).colorScheme;
  // a lighter tint for the body
  switch (b) {
    case _Bucket.treatment: return s.primaryContainer.withOpacity(0.25);
    case _Bucket.causes:    return s.tertiaryContainer.withOpacity(0.25);
    case _Bucket.symptoms:  return s.secondaryContainer.withOpacity(0.25);
    case _Bucket.overview:  return s.surfaceVariant.withOpacity(0.20);
  }
}

// Icon per bucket
IconData _bucketIcon(_Bucket b) {
  switch (b) {
    case _Bucket.treatment: return Icons.healing;          // or medical_services
    case _Bucket.causes:    return Icons.biotech;          // or psychology_alt
    case _Bucket.symptoms:  return Icons.monitor_heart;    // or emergency
    case _Bucket.overview:  return Icons.menu_book;
  }
}

// Gradient colors per bucket (theme-aware)
List<Color> _bucketGradient(BuildContext c, _Bucket b) {
  final s = Theme.of(c).colorScheme;
  switch (b) {
    case _Bucket.treatment: return [s.primary, s.primaryContainer];
    case _Bucket.causes:    return [s.tertiary, s.tertiaryContainer];
    case _Bucket.symptoms:  return [s.secondary, s.secondaryContainer];
    case _Bucket.overview:  return [s.surfaceTint, s.surfaceVariant];
  }
}

// Text color that contrasts with header gradient
Color _onHeader(BuildContext c) =>
    Theme.of(c).brightness == Brightness.dark ? Colors.white : Colors.black.withOpacity(0.9);


/// Map parsed sections (title/body) into our 4 buckets.
/// If nothing useful is found, returns {} so the caller can fall back.
Map<_Bucket, List<String>> _categorizeSections(List<dynamic> sections) {
  final map = <_Bucket, List<String>>{
    _Bucket.treatment: <String>[],
    _Bucket.causes: <String>[],
    _Bucket.symptoms: <String>[],
    _Bucket.overview: <String>[],
  };

  bool hasAny = false;

  for (final s in sections) {
    final title = (s.title ?? '').toString();
    final body  = (s.body  ?? '').toString().trim();
    if (body.isEmpty) continue;

    final t = title.toLowerCase();

    // Same synonyms we used for the raw-text extractor
    if (t.contains('treatment') ||
        t.contains('treatments') ||
        t.contains('management') ||
        t.contains('therapy') ||
        t.contains('care') ||
        t.contains('remedy') ||
        t.contains('remedies') ||
        t.contains('matibabu') ||
        t.contains('tiba') ||
        t.contains('huduma') ||
        t.contains('utunzaji')) {
      map[_Bucket.treatment]!.add(body);
      hasAny = true;
      continue;
    }

    if (t.contains('cause') ||
        t.contains('causes') ||
        t.contains('etiology') ||
        t.contains('risk factor') ||
        t.contains('risk factors') ||
        t.contains('visababishi') ||
        t.contains('kisababishi') ||
        t.contains('sababu') ||
        t.contains('vyanzo')) {
      map[_Bucket.causes]!.add(body);
      hasAny = true;
      continue;
    }

    if (t.contains('symptom') ||
        t.contains('symptoms') ||
        t.contains('sign') ||
        t.contains('signs') ||
        t.contains('presentation') ||
        t.contains('dalili') ||
        t.contains('viashiria') ||
        t.contains('ishara')) {
      map[_Bucket.symptoms]!.add(body);
      hasAny = true;
      continue;
    }

    // Everything else → overview
    map[_Bucket.overview]!.add(body);
    hasAny = true;
  }

  if (!hasAny) return {};

  // Return only non-empty buckets (preserve order)
  return {
    for (final b in [
      _Bucket.treatment,
      _Bucket.causes,
      _Bucket.symptoms,
      _Bucket.overview,
    ])
      if (map[b]!.isNotEmpty) b: map[b]!,
  };
}


/// Heuristic: split a *single raw article string* into labeled sections by scanning for
/// headings like "Treatment", "Causes", "Symptoms" in EN/SW (with or without colon).
/// Returns a map of bucket -> list of paragraph blocks. Empty map if nothing found.
Map<_Bucket, List<String>> _extractBucketsFromRaw(String raw) {
  final lines = raw.replaceAll('\r\n', '\n').split('\n');

  // EN + SW synonyms (lowercased)
  final treatmentSyns = <String>{
    'treatment','treatments','management','therapy','care','remedy','remedies',
    'matibabu','tiba','huduma','utunzaji'
  };
  final causesSyns = <String>{
    'cause','causes','etiology','risk factor','risk factors',
    'visababishi','kisababishi','sababu','vyanzo'
  };
  final symptomsSyns = <String>{
    'symptom','symptoms','sign','signs','presentation',
    'dalili','viashiria','ishara'
  };

  // Build a detector that tolerates: numbering, punctuation, case, emojis, etc.
  bool _isHeading(String line, Set<String> syns) {
    final l = line.trim().toLowerCase();
    // strip simple numbering & bullets (e.g., "1. Treatment", "- Causes —")
    final stripped = l.replaceFirst(RegExp(r'^(?:\d+[\).\s-]+|[-–—•]\s*)'), '');
    // match "word(s)" optionally ending with : - — or nothing, and maybe extra spaces
    for (final s in syns) {
      if (RegExp('^$s\\b\\s*[:\\-–—]?\$').hasMatch(stripped)) return true;
      // also allow "s: ..." on the same line (e.g., "Treatment: give ORS")
      if (RegExp('^$s\\b\\s*[:\\-–—]').hasMatch(stripped)) return true;
    }
    return false;
  }

  _Bucket? _bucketFor(String line) {
    if (_isHeading(line, treatmentSyns)) return _Bucket.treatment;
    if (_isHeading(line, causesSyns))    return _Bucket.causes;
    if (_isHeading(line, symptomsSyns))  return _Bucket.symptoms;
    return null;
  }

  // Scan and collect blocks under current bucket. Default to overview until a heading appears.
  final out = <_Bucket, List<String>>{
    _Bucket.treatment: <String>[],
    _Bucket.causes: <String>[],
    _Bucket.symptoms: <String>[],
    _Bucket.overview: <String>[],
  };
  _Bucket current = _Bucket.overview;
  final buffer = StringBuffer();

  void _flush() {
    final text = buffer.toString().trim();
    if (text.isNotEmpty) out[current]!.add(text);
    buffer.clear();
  }

  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];

    // Heading on its own line? Flush previous and switch.
    final maybe = _bucketFor(line);
    if (maybe != null) {
      _flush();
      current = maybe;

      // If heading is like "Treatment: do X" on the SAME line, keep the "after colon" part
      final m = RegExp(r'[:\-–—]\s*(.+)$').firstMatch(line.trim());
      if (m != null) {
        buffer.writeln(m.group(1));
      }
      continue;
    }

    buffer.writeln(line);
  }
  _flush();

  // Decide if we actually found labeled sections (≥ 2 non-empty buckets preferred)
  final nonEmpty = out.entries.where((e) => e.value.isNotEmpty).map((e) => e.key).toList();
  // If only overview has content, return {} to signal "not found"
  if (nonEmpty.isEmpty || (nonEmpty.length == 1 && nonEmpty.first == _Bucket.overview)) {
    return {};
  }

  // Trim empty buckets at the end (keep only those with text)
  return {
    for (final b in [_Bucket.treatment, _Bucket.causes, _Bucket.symptoms, _Bucket.overview])
      if (out[b]!.isNotEmpty) b: out[b]!,
  };
}

class _FancyBody extends StatelessWidget {
  final List<String> paragraphs;
  final Color accent;
  const _FancyBody({required this.paragraphs, required this.accent});

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];

    for (final raw in paragraphs) {
      final bullets = maybeBullets(raw);
      if (bullets.isNotEmpty) {
        for (final b in bullets) {
          children.add(Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 8, height: 8,
                  margin: const EdgeInsets.only(top: 7, right: 8),
                  decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
                ),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: Theme.of(context).textTheme.bodyLarge,
                      children: linkifyParagraph(
                        context,
                        text: b,
                        resolveTitle: (_) => null,
                        onTapId: (id) {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => ContentDetailScreen(id: id)),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ));
        }
      } else {
        final paras = raw.split('\n\n').where((p) => p.trim().isNotEmpty);
        for (final p in paras) {
          children.add(Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: RichText(
              text: TextSpan(
                style: Theme.of(context).textTheme.bodyLarge,
                children: linkifyParagraph(
                  context,
                  text: p.trim(),
                  resolveTitle: (_) => null,
                  onTapId: (id) {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => ContentDetailScreen(id: id)),
                    );
                  },
                ),
              ),
            ),
          ));
        }
      }

      // soft divider between blocks
      children.add(
        Divider(
          height: 16,
          thickness: 0.6,
          color: Theme.of(context).dividerColor.withOpacity(0.3),
        ),
      );
    }

    if (children.isNotEmpty) children.removeLast(); // drop last divider
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: children);
  }
}


/// Renders a list of paragraphs, respecting your bullets & auto-linking
class _AccordionBody extends StatelessWidget {
  final List<String> paragraphs;
  const _AccordionBody({required this.paragraphs});

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];

    for (final raw in paragraphs) {
      final bullets = maybeBullets(raw);
      if (bullets.isNotEmpty) {
        children.addAll(bullets.map((b) => Padding(
          padding: const EdgeInsets.only(bottom: 6),
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
                      resolveTitle: (_) => null,
                      onTapId: (id) {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => ContentDetailScreen(id: id)),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        )));
      } else {
        // split into paragraphs
        final paras = raw.split('\n\n').where((p) => p.trim().isNotEmpty);
        for (final p in paras) {
          children.add(Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: RichText(
              text: TextSpan(
                style: Theme.of(context).textTheme.bodyLarge,
                children: linkifyParagraph(
                  context,
                  text: p.trim(),
                  resolveTitle: (_) => null,
                  onTapId: (id) {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => ContentDetailScreen(id: id)),
                    );
                  },
                ),
              ),
            ),
          ));
        }
      }
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: children);
  }
}
