// lib/features/content/ui/content_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import '../../progress/progress_tracker.dart';



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

                        Expanded(
                          child: SingleChildScrollView(
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
                          ),
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
