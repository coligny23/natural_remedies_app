// lib/features/search/search_screen.dart
import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../l10n/app_strings.dart';
import 'search_history_providers.dart';
import '/features/qa/saved_answers_providers.dart';
import 'search_providers.dart';
import '../content/models/content_item.dart';
import '../../shared/ml/qa_providers.dart';
import '../../shared/telemetry/telemetry_providers.dart';

// ✅ ML (semantic blending)
import '../../shared/ml/ml_providers.dart';

// ✅ Background wrapper
import '../../widgets/app_background.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});
  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 150), () async {
      final q = text.trim();
      ref.read(searchQueryProvider.notifier).state = q;

      if (q.isNotEmpty) {
        await ref.read(searchHistoryProvider.notifier).add(q);
      }

      if (q.isNotEmpty) {
        await ref.logEvent('search', {
          'q': q,
          'chars': q.length,
        });
      }
    });
  }

  List<String> _tokens(String q) => q
      .toLowerCase()
      .split(RegExp(r'[^a-z0-9]+'))
      .where((s) => s.isNotEmpty)
      .toList();

  @override
  Widget build(BuildContext context) {
    final t = AppStrings.of(context);

    // Core data dependencies
    final itemsAsync = ref.watch(contentListProvider);
    final isLoading = itemsAsync.isLoading;
    final total =
        itemsAsync.maybeWhen(data: (it) => it.length, orElse: () => null);

    // Query + fast results
    final query = ref.watch(searchQueryProvider).trim();
    final resultsAsync = ref.watch(fastSearchProvider(query));
    final resultsCount = resultsAsync.maybeWhen(
      data: (list) => list.length,
      orElse: () => null,
    );

    // History
    final history = ref.watch(searchHistoryProvider);

    // Synonym suggestions
    final synsAsync = ref.watch(synonymsMapProvider);

    final suggestionChips = synsAsync.maybeWhen(
      data: (syns) {
        if (query.isEmpty) return const <String>[];
        final toks = _tokens(query);
        final out = <String>{};
        for (final token in toks) {
          final alts = syns[token] ?? const <String>[];
          for (final alt in alts) {
            if (alt.toLowerCase() != token.toLowerCase()) {
              out.add(alt);
            }
          }
        }
        return out.take(6).toList();
      },
      orElse: () => const <String>[],
    );

    // AI answer hook
    final answerAsync =
        query.isEmpty ? null : ref.watch(qaAnswerProvider(query));
    final lang = ref.watch(languageCodeProvider);

    // Semantic scores
    final semScoresAsync = ref.watch(semanticScoresProvider(query));

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(t.search),
        actions: [
          IconButton(
            icon: const Icon(Icons.bug_report_outlined),
            tooltip: t.probeAsset,
            onPressed: () async {
              try {
                final s =
                    await rootBundle.loadString('assets/corpus/en/sample.json');
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(t.loadedSampleJson(s.length)),
                  ),
                );
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(t.failedToLoadAsset(e.toString())),
                  ),
                );
              }
            },
          ),
        ],
      ),
      body: AppBackground(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Semantics(
                label: t.searchFieldLabel,
                hint: t.searchFieldHint,
                textField: true,
                child: TextField(
                  controller: _controller,
                  onChanged: _onChanged,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: t.searchExampleHint,
                    prefixIcon: Icon(
                      Icons.search,
                      semanticLabel: t.search,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),

            if (history.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: history.take(6).map((q) {
                      return ActionChip(
                        label: Text(q),
                        onPressed: () {
                          _controller.text = q;
                          _controller.selection = TextSelection.fromPosition(
                            TextPosition(offset: q.length),
                          );
                          ref.read(searchQueryProvider.notifier).state = q;
                        },
                      );
                    }).toList(),
                  ),
                ),
              ),

            if (suggestionChips.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: suggestionChips.map((s) {
                      return InputChip(
                        label: Text(s),
                        onPressed: () async {
                          final base = query.trim();
                          final newQ = base.isEmpty ? s : '$base $s';
                          _controller.text = newQ;
                          _controller.selection = TextSelection.fromPosition(
                            TextPosition(offset: newQ.length),
                          );
                          ref.read(searchQueryProvider.notifier).state = newQ;

                          await ref.logEvent('search_synonym_chip', {
                            'q': query,
                            'chip': s,
                          });
                        },
                      );
                    }).toList(),
                  ),
                ),
              ),

            if (isLoading) const LinearProgressIndicator(),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(t.loadedCount(total)),
                  Text(t.resultsCount(resultsCount)),
                ],
              ),
            ),
            const SizedBox(height: 8),

            FutureBuilder<String>(
              future: rootBundle.loadString('AssetManifest.json'),
              builder: (context, snap) {
                if (!snap.hasData) return const SizedBox.shrink();
                final keys =
                    (json.decode(snap.data!) as Map<String, dynamic>).keys.toList();
                final sample = keys
                    .where((k) => k.contains('assets/corpus'))
                    .take(5)
                    .toList();

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      t.manifestSample(
                        sample.isEmpty ? t.none : sample.join(', '),
                      ),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 4),

            if (query.isNotEmpty && answerAsync != null) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: answerAsync.when(
                      loading: () => Text(t.thinking),
                      error: (e, _) => Text(t.couldNotAnswer(e.toString())),
                      data: (ans) {
                        final hasText = ans.text.trim().isNotEmpty;

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  t.answer,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Row(
                                  children: [
                                    IconButton(
                                      tooltip: t.shareAnswer,
                                      icon: const Icon(Icons.ios_share),
                                      onPressed: hasText
                                          ? () {
                                              final src = ans.source;
                                              final buffer = StringBuffer()
                                                ..writeln('Q: $query')
                                                ..writeln('A: ${ans.text}');
                                              if (src != null) {
                                                buffer.writeln(
                                                  '${t.source}: ${src.title}',
                                                );
                                              }
                                              Share.share(
                                                buffer.toString().trim(),
                                              );
                                            }
                                          : null,
                                    ),
                                    IconButton(
                                      tooltip: t.saveAnswer,
                                      icon: const Icon(Icons.star_border),
                                      onPressed: hasText
                                          ? () async {
                                              await ref
                                                  .read(savedQaListProvider.notifier)
                                                  .save(
                                                    question: query,
                                                    answerText: ans.text,
                                                    sourceId: ans.source?.id,
                                                    sourceTitle: ans.source?.title,
                                                  );

                                              if (!context.mounted) return;
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                SnackBar(
                                                  content: Text(t.savedToAnswers),
                                                ),
                                              );

                                              await ref.logEvent('qa_saved', {
                                                'has_source': ans.source != null,
                                                'q_len': query.length,
                                                'a_len': ans.text.length,
                                              });
                                            }
                                          : null,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(ans.text),
                            if (ans.source != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                '${t.source}: ${ans.source!.title}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],

            Expanded(
              child: resultsAsync.when(
                loading: () => _LoadingOrEmpty(
                  queryEmptyMessage: t.typeToSearch,
                ),
                error: (err, st) => Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('${t.searchError}: $err'),
                ),
                data: (keywordResults) {
                  if (keywordResults.isEmpty) {
                    return const _EmptyState();
                  }

                  return semScoresAsync.when(
                    loading: () {
                      return _ResultsList(
                        items: keywordResults,
                        lang: lang,
                        query: query,
                        onTapLabel: t.openDetails,
                        onTapAction: t.doubleTapToOpenDetails,
                        blendedBadge: null,
                        onTap: (it) async {
                          await ref.logEvent('open_from_search', {
                            'id': it.id,
                            'title': it.title,
                            'lang': lang,
                          });
                          if (!context.mounted) return;
                          context.go('/article/${it.id}');
                        },
                      );
                    },
                    error: (_, __) {
                      return _ResultsList(
                        items: keywordResults,
                        lang: lang,
                        query: query,
                        onTapLabel: t.openDetails,
                        onTapAction: t.doubleTapToOpenDetails,
                        blendedBadge: null,
                        onTap: (it) async {
                          await ref.logEvent('open_from_search', {
                            'id': it.id,
                            'title': it.title,
                            'lang': lang,
                          });
                          if (!context.mounted) return;
                          context.go('/article/${it.id}');
                        },
                      );
                    },
                    data: (semScores) {
                      final n = keywordResults.length.toDouble();
                      final blended =
                          <({ContentItem item, double finalScore, double k, double s})>[];

                      for (var i = 0; i < keywordResults.length; i++) {
                        final it = keywordResults[i];
                        final k = (n - i) / n;
                        final s = (semScores[it.id] ?? 0.0).clamp(0.0, 1.0);
                        final score = 0.6 * k + 0.4 * s;
                        blended.add((
                          item: it,
                          finalScore: score,
                          k: k,
                          s: s,
                        ));
                      }

                      blended.sort((a, b) => b.finalScore.compareTo(a.finalScore));
                      final ordered = blended.map((e) => e.item).toList();

                      String badgeOf(ContentItem it) {
                        final b = blended.firstWhere((e) => e.item.id == it.id);
                        return '★ ${b.finalScore.toStringAsFixed(2)}  k:${b.k.toStringAsFixed(2)} s:${b.s.toStringAsFixed(2)}';
                      }

                      return _ResultsList(
                        items: ordered,
                        lang: lang,
                        query: query,
                        onTapLabel: t.openDetails,
                        onTapAction: t.doubleTapToOpenDetails,
                        blendedBadge: badgeOf,
                        onTap: (it) async {
                          await ref.logEvent('open_from_search', {
                            'id': it.id,
                            'title': it.title,
                            'lang': lang,
                          });
                          if (!context.mounted) return;
                          context.go('/article/${it.id}');
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultsList extends StatelessWidget {
  final List<ContentItem> items;
  final String lang;
  final String query;
  final void Function(ContentItem) onTap;
  final String Function(ContentItem)? blendedBadge;
  final String onTapLabel;
  final String onTapAction;

  const _ResultsList({
    required this.items,
    required this.lang,
    required this.query,
    required this.onTap,
    required this.onTapLabel,
    required this.onTapAction,
    this.blendedBadge,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final item = items[index];

        final bodyText = (lang == 'sw')
            ? (item.contentSw ?? item.contentEn ?? '')
            : (item.contentEn ?? item.contentSw ?? '');
        final snippetSrc = bodyText.replaceAll('\n', ' ');
        final snippet = snippetSrc.length <= 160
            ? snippetSrc
            : '${snippetSrc.substring(0, 160)} …';
        final hasImage = (item.image ?? '').isNotEmpty;

        final badge = blendedBadge?.call(item);

        return MergeSemantics(
          child: Semantics(
            excludeSemantics: true,
            button: true,
            label:
                '${item.title}. ${snippet.isEmpty ? onTapLabel : snippet}. $onTapAction.',
            child: ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              leading: hasImage
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.asset(
                        item.image!,
                        width: 56,
                        height: 56,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            const Icon(Icons.image_not_supported),
                      ),
                    )
                  : const CircleAvatar(
                      radius: 28,
                      child: Icon(Icons.eco),
                    ),
              title: Text(item.title),
              subtitle: RichText(
                text: TextSpan(
                  style: Theme.of(context).textTheme.bodyMedium,
                  children: _highlight(snippet, query),
                ),
              ),
              trailing: badge == null
                  ? null
                  : Text(
                      badge,
                      style: Theme.of(context)
                          .textTheme
                          .labelSmall
                          ?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                          ),
                    ),
              onTap: () => onTap(item),
            ),
          ),
        );
      },
    );
  }
}

class _LoadingOrEmpty extends StatelessWidget {
  final String queryEmptyMessage;
  const _LoadingOrEmpty({required this.queryEmptyMessage});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          queryEmptyMessage,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final t = AppStrings.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          t.noResultsTryAnother,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
    );
  }
}

/// Show the first 160 chars as a snippet.
class _Snippet extends StatelessWidget {
  final String text;
  const _Snippet({required this.text});

  @override
  Widget build(BuildContext context) {
    final snippet = text.replaceAll('\n', ' ');
    final short =
        snippet.length <= 160 ? snippet : '${snippet.substring(0, 160)} …';
    return Text(short);
  }
}

List<InlineSpan> _highlight(String text, String query) {
  if (query.trim().isEmpty) return [TextSpan(text: text)];
  final q = RegExp(RegExp.escape(query.trim()), caseSensitive: false);
  final spans = <InlineSpan>[];
  int start = 0;
  for (final m in q.allMatches(text)) {
    if (m.start > start) {
      spans.add(TextSpan(text: text.substring(start, m.start)));
    }
    spans.add(
      TextSpan(
        text: text.substring(m.start, m.end),
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
    );
    start = m.end;
  }
  if (start < text.length) {
    spans.add(TextSpan(text: text.substring(start)));
  }
  return spans;
}