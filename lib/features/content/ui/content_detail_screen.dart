// lib/features/content/ui/content_detail_screen.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;

import '../../progress/progress_tracker.dart';
import '../../../app/theme/app_theme.dart'; // AppElevations, GlossyCardTheme (ThemeExtensions)

// content/render + data
import '../../content/data/reading_progress_repository.dart'; // ok if unused
import 'content_renderer.dart'; // parseSections, maybeBullets, linkifyParagraph, sectionSlug
import '../../search/search_providers.dart'; // languageCodeProvider, contentListProvider
import '../data/content_lookup_provider.dart'; // contentByIdProvider(id)
import '../../saved/bookmarks_controller.dart'; // bookmarksProvider
import '../models/content_item.dart';

class ContentDetailScreen extends ConsumerStatefulWidget {
  final String id;
  final String? initialSection;
  const ContentDetailScreen({super.key, required this.id, this.initialSection});

  @override
  ConsumerState<ContentDetailScreen> createState() => _ContentDetailScreenState();
}

class _ContentDetailScreenState extends ConsumerState<ContentDetailScreen>
    with SingleTickerProviderStateMixin {
  late final ScrollController _scroll = ScrollController();
  late TabController _tab;
  String? _lastSection;
  bool _restoredOnce = false;

  // cache built tabs per article id
  List<_TabSpec> _tabs = const [];

  @override
  void initState() {
    super.initState();
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
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final itemsAsync = ref.watch(contentListProvider);
    final lang = ref.watch(languageCodeProvider);
    final glossy = Theme.of(context).extension<GlossyCardTheme>();
    final elev = Theme.of(context).extension<AppElevations>();

    return itemsAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
      data: (allItems) {
        final item = ref.watch(contentByIdProvider(widget.id));
        if (item == null) {
          return const Scaffold(body: Center(child: Text('Not found')));
        }

        final isSw = (lang == 'sw');
        final body = isSw
            ? (item.contentSw ?? item.contentEn ?? '')
            : (item.contentEn ?? item.contentSw ?? '');
        final hasImage = (item.image ?? '').isNotEmpty;
        final credit = item.imageMeta?['credit'] as String?;
        final isSaved = ref.watch(bookmarksProvider).contains(item.id);

        // Build buckets → tabs (Overview/Treatment/Causes/Symptoms)
        _tabs = _buildTabs(context, body, lang);

        // Ensure at least one tab exists (fallback to Overview with whole body)
        if (_tabs.isEmpty) {
          _tabs = [
            _TabSpec(
              key: 'overview',
              title: isSw ? 'Muhtasari' : 'Overview',
              icon: Icons.menu_book,
              paragraphs: [body],
            ),
          ];
        }

        // Create TabController once per build (or when tab count changes)
        _tab = TabController(length: _tabs.length, vsync: this);

        // If user deep-linked a specific tab via query (optional future),
        // you can set _tab.index here.

        // One-time restore scroll after layout
        WidgetsBinding.instance.addPostFrameCallback((_) => _maybeRestore(body));

        return Scaffold(
          body: ProgressTracker(
            articleId: widget.id,
            sectionId: _lastSection,
            child: NestedScrollView(
              controller: _scroll,
              headerSliverBuilder: (context, innerBoxIsScrolled) {
                return [
                  SliverAppBar(
                    title: Text(item.title),
                    pinned: true,
                    floating: false,
                    snap: false,
                    stretch: true,
                    expandedHeight: hasImage ? 260 : 0,
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
                        tooltip: isSw ? 'Nakili' : 'Copy',
                        icon: const Icon(Icons.copy),
                        onPressed: () async {
                          await Clipboard.setData(
                            ClipboardData(text: '${item.title}\n\n$body'),
                          );
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(isSw ? 'Imenakiliwa' : 'Copied to clipboard'),
                            ),
                          );
                        },
                      ),
                      IconButton(
                        tooltip: isSw ? 'Shiriki' : 'Share',
                        icon: const Icon(Icons.ios_share),
                        onPressed: () {
                          final deepPath = '/article/${item.id}';
                          SharePlus.instance.share(
                            ShareParams(text: '${item.title}\n$deepPath\n\n$body', subject: item.title),
                          );
                        },
                      ),
                    ],
                    flexibleSpace: hasImage
                        ? FlexibleSpaceBar(
                            stretchModes: const [
                              StretchMode.zoomBackground,
                              StretchMode.fadeTitle,
                            ],
                            background: Stack(
                              fit: StackFit.expand,
                              children: [
                                Hero(
                                  tag: 'article-image-${item.id}',
                                  child: Image.asset(
                                    item.image!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const ColoredBox(
                                      color: Colors.black26,
                                      child: Center(child: Icon(Icons.image_not_supported, size: 48)),
                                    ),
                                  ),
                                ),
                                // subtle gradient overlay for legibility
                                Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.black.withOpacity(0.05),
                                        Colors.black.withOpacity(0.35),
                                      ],
                                    ),
                                  ),
                                ),
                                if (credit != null && credit.trim().isNotEmpty)
                                  Positioned(
                                    left: 12,
                                    bottom: 12,
                                    child: Text(
                                      credit,
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                            color: Colors.white.withOpacity(.9),
                                            shadows: const [Shadow(blurRadius: 2, color: Colors.black)],
                                          ),
                                    ),
                                  ),
                              ],
                            ),
                          )
                        : null,
                  ),

                  // Sticky TabBar
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _TabBarHeaderDelegate(
                      TabBar(
                        controller: _tab,
                        isScrollable: true,
                        tabAlignment: TabAlignment.start,
                        tabs: [
                          for (final t in _tabs)
                            Tab(
                              icon: Icon(t.icon, size: 18),
                              text: t.title,
                            ),
                        ],
                      ),
                    ),
                  ),
                ];
              },

              // Tab views
              body: TabBarView(
                controller: _tab,
                children: [
                  for (final t in _tabs)
                    _TabBody(
                      paragraphs: t.paragraphs,
                      heroAccent: _tabAccent(context, t.key),
                      glossy: glossy,
                      elev: elev,
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // --- Build tab specs from raw text using your existing heuristics ---
  List<_TabSpec> _buildTabs(BuildContext context, String raw, String lang) {
    // Prefer labeled blocks from raw → else parsed headings
    Map<_Bucket, List<String>> buckets = _extractBucketsFromRaw(raw);
    if (buckets.isEmpty) {
      final secs = parseSections(raw);
      buckets = _categorizeSections(secs);
    }

    // If everything landed in Overview, we’ll create a single tab in build()
    if (buckets.isEmpty) return [];

    final isSw = lang.toLowerCase() == 'sw';

    final order = <_Bucket>[
      _Bucket.overview,
      _Bucket.treatment,
      _Bucket.causes,
      _Bucket.symptoms,
    ];

    final titleOf = (_Bucket b) => _bucketTitleLocalized(b, lang);
    final iconOf = (_Bucket b) {
      switch (b) {
        case _Bucket.overview: return Icons.menu_book;
        case _Bucket.treatment: return Icons.healing;
        case _Bucket.causes: return Icons.biotech;
        case _Bucket.symptoms: return Icons.monitor_heart;
      }
    };

    final tabs = <_TabSpec>[];
    for (final b in order) {
      final ps = buckets[b];
      if (ps == null || ps.isEmpty) continue;
      tabs.add(_TabSpec(
        key: b.name,
        title: titleOf(b),
        icon: iconOf(b),
        paragraphs: ps,
      ));
    }

    return tabs;
  }

  // Optional: themed accent per tab for bullets
  Color _tabAccent(BuildContext c, String key) {
    final s = Theme.of(c).colorScheme;
    switch (key) {
      case 'treatment': return s.primary;
      case 'causes': return s.tertiary;
      case 'symptoms': return s.secondary;
      default: return s.surfaceTint;
    }
  }

  Future<void> _maybeRestore(String body) async {
    if (_restoredOnce) return;
    final box = Hive.box('reading_progress');
    final savedOffset = (box.get('pos_${widget.id}_offset') as num?)?.toDouble();
    if (savedOffset != null && savedOffset > 0 && _scroll.hasClients) {
      _scroll.jumpTo(savedOffset.clamp(0, _scroll.position.maxScrollExtent));
    }
    _restoredOnce = true;
  }
}

/// Small sticky header delegate for TabBar
class _TabBarHeaderDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  _TabBarHeaderDelegate(this.tabBar);

  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(context, shrinkOffset, overlapsContent) {
    final s = Theme.of(context).colorScheme;
    return Material(
      color: s.surface,
      elevation: overlapsContent ? 1 : 0,
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(covariant _TabBarHeaderDelegate oldDelegate) => false;
}

/// One tab page; respects your linkify/bullets and adds a soft glossy card body
class _TabBody extends StatelessWidget {
  final List<String> paragraphs;
  final Color heroAccent;
  final GlossyCardTheme? glossy;
  final AppElevations? elev;

  const _TabBody({
    required this.paragraphs,
    required this.heroAccent,
    required this.glossy,
    required this.elev,
  });

  @override
  Widget build(BuildContext context) {
    final cardDeco = (glossy?.bodyDecoration().copyWith(
          boxShadow: glossy?.shadows
              .map((s) => s.copyWith(blurRadius: s.blurRadius + (elev?.small ?? 1)))
              .toList(),
        )) ??
        BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Theme.of(context).dividerColor.withOpacity(.35)),
        );

    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n is ScrollUpdateNotification) {
          // You can persist per-tab offsets if you want; for now, save main scroll
          final box = Hive.box('reading_progress');
          box.put('pos_tab_offset', n.metrics.pixels);
        }
        return false;
      },
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Container(
          decoration: cardDeco,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: _FancyBody(paragraphs: paragraphs, accent: heroAccent),
        ),
      ),
    );
  }
}

/* ===================== Helpers reused from your file ===================== */

enum _Bucket { treatment, causes, symptoms, overview }

String _bucketTitleLocalized(_Bucket b, String lang) {
  final isSw = (lang.toLowerCase() == 'sw');
  if (isSw) {
    switch (b) {
      case _Bucket.treatment: return 'Matibabu';
      case _Bucket.causes: return 'Sababu';
      case _Bucket.symptoms: return 'Dalili';
      case _Bucket.overview: return 'Muhtasari';
    }
  } else {
    switch (b) {
      case _Bucket.treatment: return 'Treatment';
      case _Bucket.causes: return 'Causes';
      case _Bucket.symptoms: return 'Symptoms';
      case _Bucket.overview: return 'Overview';
    }
  }
}

// Parse-section → buckets
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
    final body = (s.body ?? '').toString().trim();
    if (body.isEmpty) continue;
    final t = title.toLowerCase();

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

    map[_Bucket.overview]!.add(body);
    hasAny = true;
  }

  if (!hasAny) return {};
  return {
    for (final b in [_Bucket.overview, _Bucket.treatment, _Bucket.causes, _Bucket.symptoms])
      if (map[b]!.isNotEmpty) b: map[b]!,
  };
}

// Raw → buckets by scanning headings in EN/SW
Map<_Bucket, List<String>> _extractBucketsFromRaw(String raw) {
  final lines = raw.replaceAll('\r\n', '\n').split('\n');
  final treatmentSyns = <String>{
    'treatment','treatments','management','therapy','care','remedy','remedies',
    'matibabu','tiba','huduma','utunzaji'
  };
  final causesSyns = <String>{
    'cause','causes','etiology','risk factor','risk factors',
    'visababishi','kisababishi','sababu','vyanzo'
  };
  final symptomsSyns = <String>{
    'symptom','symptoms','sign','signs','presentation','dalili','viashiria','ishara'
  };

  bool _isHeading(String line, Set<String> syns) {
    final l = line.trim().toLowerCase();
    final stripped = l.replaceFirst(RegExp(r'^(?:\d+[\).\s-]+|[-–—•]\s*)'), '');
    for (final s in syns) {
      if (RegExp('^$s\\b\\s*[:\\-–—]?\$').hasMatch(stripped)) return true;
      if (RegExp('^$s\\b\\s*[:\\-–—]').hasMatch(stripped)) return true;
    }
    return false;
  }

  _Bucket? _bucketFor(String line) {
    if (_isHeading(line, treatmentSyns)) return _Bucket.treatment;
    if (_isHeading(line, causesSyns)) return _Bucket.causes;
    if (_isHeading(line, symptomsSyns)) return _Bucket.symptoms;
    return null;
  }

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

  for (final line in lines) {
    final maybe = _bucketFor(line);
    if (maybe != null) {
      _flush();
      current = maybe;
      final m = RegExp(r'[:\-–—]\s*(.+)$').firstMatch(line.trim());
      if (m != null) buffer.writeln(m.group(1));
      continue;
    }
    buffer.writeln(line);
  }
  _flush();

  final nonEmptyKeys = out.entries.where((e) => e.value.isNotEmpty).map((e) => e.key).toList();
  if (nonEmptyKeys.isEmpty || (nonEmptyKeys.length == 1 && nonEmptyKeys.first == _Bucket.overview)) {
    return {};
  }
  return {
    for (final b in [_Bucket.overview, _Bucket.treatment, _Bucket.causes, _Bucket.symptoms])
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
                  width: 8,
                  height: 8,
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
      children.add(Divider(
        height: 16,
        thickness: 0.6,
        color: Theme.of(context).dividerColor.withOpacity(0.3),
      ));
    }
    if (children.isNotEmpty) children.removeLast();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: children);
  }
}

class _TabSpec {
  final String key;
  final String title;
  final IconData icon;
  final List<String> paragraphs;
  const _TabSpec({
    required this.key,
    required this.title,
    required this.icon,
    required this.paragraphs,
  });
}
