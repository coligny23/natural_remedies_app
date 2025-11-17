// lib/features/search/search_screen.dart
import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'search_history_providers.dart';
import '/features/qa/saved_answers_providers.dart';
import 'package:share_plus/share_plus.dart'; // if not already present

import 'search_providers.dart'; // <- includes fastSearchProvider + searchQueryProvider
import '../content/models/content_item.dart';
import '../../shared/ml/qa_providers.dart'; // qaInitProvider / qaAnswerProvider
import '../../shared/telemetry/telemetry_providers.dart'; // <-- telemetry

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

      // --- Telemetry: record debounced search (only if non-empty) ---
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
    // Core data dependencies
    final itemsAsync = ref.watch(contentListProvider);
    final isLoading = itemsAsync.isLoading;
    final total =
        itemsAsync.maybeWhen(data: (it) => it.length, orElse: () => null);

    // Query + fast results (ASYNC)
    final query = ref.watch(searchQueryProvider).trim();
    final resultsAsync = ref.watch(fastSearchProvider(query));
    final resultsCount = resultsAsync.maybeWhen(
      data: (list) => list.length,
      orElse: () => null,
    );
    // add this line with your other locals at the top of build()
    final history = ref.watch(searchHistoryProvider);
    // Synonym suggestions for current query
    final synsAsync = ref.watch(synonymsMapProvider);

    final suggestionChips = synsAsync.maybeWhen(
      data: (syns) {
        if (query.isEmpty) return const <String>[];
        final toks = _tokens(query);
        final out = <String>{};
        for (final t in toks) {
          final alts = syns[t] ?? const <String>[];
          for (final a in alts) {
            if (a.toLowerCase() != t.toLowerCase()) out.add(a);
          }
        }
        return out.take(6).toList(); // show up to 6
      },
      orElse: () => const <String>[],
    );

    // AI answer hook (stub now, TFLite later)
    final answerAsync =
        query.isEmpty ? null : ref.watch(qaAnswerProvider(query));
    final lang = ref.watch(languageCodeProvider); // 'en' or 'sw'

    return Scaffold(
      backgroundColor: Colors.transparent, // ✅ let global bg show
      appBar: AppBar(
        title: const Text('Search'),
        actions: [
          IconButton(
            icon: const Icon(Icons.bug_report_outlined),
            tooltip: 'Probe asset',
            onPressed: () async {
              try {
                // adjust path if you want to probe a different lang/file
                final s =
                    await rootBundle.loadString('assets/corpus/en/sample.json');
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content: Text('Loaded sample.json (${s.length} chars)')),
                );
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed to load asset: $e')),
                );
              }
            },
          ),
        ],
      ),
      body: AppBackground(
         // ✅ wrap whole page content
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Semantics(
                label: 'Search field for natural remedies',
                hint: 'Type an ingredient or condition, for example ginger',
                textField: true,
                child: TextField(
                  controller: _controller,
                  onChanged: _onChanged,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'Search (e.g., "ginger")',
                    prefixIcon:
                        const Icon(Icons.search, semanticLabel: 'Search'),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ),

            // History chips (last 6)
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

            // "Also try" synonym suggestion chips
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

                          // Optional telemetry
                          await ref.logEvent(
                              'search_synonym_chip', {'q': query, 'chip': s});
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
                  Text('Loaded: ${total ?? "…"}'),
                  Text('Results: ${resultsCount ?? "…"}'),
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
                      'Manifest sample: ${sample.isEmpty ? "(none)" : sample.join(", ")}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 4),

            // --- AI Answer card (optional, shows when there's a query) ---
            if (query.isNotEmpty && answerAsync != null) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: answerAsync.when(
                      loading: () => const Text('Thinking…'),
                      error: (e, _) => Text('Could not answer: $e'),
                      data: (ans) {
                        final hasText = ans.text.trim().isNotEmpty;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Answer',
                                    style:
                                        TextStyle(fontWeight: FontWeight.w600)),
                                Row(
                                  children: [
                                    IconButton(
                                      tooltip: 'Share answer',
                                      icon: const Icon(Icons.ios_share),
                                      onPressed: hasText
                                          ? () {
                                              final src = ans.source;
                                              final buffer = StringBuffer()
                                                ..writeln('Q: $query')
                                                ..writeln('A: ${ans.text}');
                                              if (src != null) {
                                                buffer.writeln(
                                                    'Source: ${src.title}');
                                              }
                                              Share.share(buffer.toString().trim());
                                            }
                                          : null,
                                    ),
                                    IconButton(
                                      tooltip: 'Save answer',
                                      icon: const Icon(Icons.star_border),
                                      onPressed: hasText
                                          ? () async {
                                              await ref
                                                  .read(savedQaListProvider.notifier)
                                                  .save(
                                                    question: query,
                                                    answerText: ans.text,
                                                    sourceId: ans.source?.id,
                                                    sourceTitle:
                                                        ans.source?.title,
                                                  );
                                              if (!context.mounted) return;
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                const SnackBar(
                                                    content:
                                                        Text('Saved to Answers')),
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
                              Text('Source: ${ans.source!.title}',
                                  style:
                                      Theme.of(context).textTheme.bodySmall),
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
            // --- end Answer card ---

            Expanded(
              child: resultsAsync.when(
                loading: () =>
                    const _LoadingOrEmpty(queryEmptyMessage: 'Type to search…'),
                error: (err, st) => Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('Search error: $err'),
                ),
                data: (results) {
                  if (results.isEmpty) {
                    return const _EmptyState();
                  }
                  return ListView.separated(
                    itemCount: results.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = results[index];

                      final bodyText = (lang == 'sw')
                          ? (item.contentSw ?? item.contentEn ?? '')
                          : (item.contentEn ?? item.contentSw ?? '');
                      final snippetSrc = bodyText.replaceAll('\n', ' ');
                      final snippet = snippetSrc.length <= 160
                          ? snippetSrc
                          : '${snippetSrc.substring(0, 160)} …';
                      final hasImage = (item.image ?? '').isNotEmpty;

                      return MergeSemantics(
                        child: Semantics(
                          excludeSemantics: true,
                          button: true,
                          label:
                              '${item.title}. ${snippet.isEmpty ? "Open details" : snippet}. Double tap to open details.',
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
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
                            onTap: () async {
                              await ref.logEvent('open_from_search', {
                                'id': item.id,
                                'title': item.title,
                                'lang': lang,
                              });
                              if (!context.mounted) return;
                              context.go('/article/${item.id}');
                            },
                          ),
                        ),
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'No results yet. Try another term—e.g., "ginger", "cayenne", "debility", "symptoms".',
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
    spans.add(TextSpan(
      text: text.substring(m.start, m.end),
      style: const TextStyle(fontWeight: FontWeight.w700),
    ));
    start = m.end;
  }
  if (start < text.length) {
    spans.add(TextSpan(text: text.substring(start)));
  }
  return spans;
}
