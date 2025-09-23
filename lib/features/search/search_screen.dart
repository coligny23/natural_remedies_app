import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'search_providers.dart';
import '../content/models/content_item.dart';
import '../../shared/ml/qa_providers.dart'; // qaInitProvider / qaAnswerProvider
import '../../shared/telemetry/telemetry_providers.dart'; // <-- telemetry

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

      // --- Telemetry: record debounced search (only if non-empty) ---
      if (q.isNotEmpty) {
        await ref.logEvent('search', {
          'q': q,
          'chars': q.length,
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final results = ref.watch(searchResultsProvider);
    final isLoading = ref.watch(contentListProvider).isLoading;

    final itemsAsync = ref.watch(contentListProvider);
    final total = itemsAsync.maybeWhen(data: (it) => it.length, orElse: () => null);

    // AI answer hook (stub now, TFLite later)
    final query = ref.watch(searchQueryProvider).trim();
    // Only ask when the user typed something
    final answerAsync = query.isEmpty ? null : ref.watch(qaAnswerProvider(query));
    final lang = ref.watch(languageCodeProvider); // 'en' or 'sw'

    return Scaffold(
      appBar: AppBar(
        title: const Text('Search'),
        actions: [
          IconButton(
            icon: const Icon(Icons.bug_report_outlined),
            tooltip: 'Probe asset',
            onPressed: () async {
              try {
                // adjust path if you want to probe a different lang/file
                final s = await rootBundle.loadString('assets/corpus/en/sample.json');
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Loaded sample.json (${s.length} chars)')),
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

      body: Column(
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
                  prefixIcon: const Icon(Icons.search, semanticLabel: 'Search'),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
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
                Text('Results: ${results.length}'),
              ],
            ),
          ),
          const SizedBox(height: 8),

          FutureBuilder<String>(
            future: rootBundle.loadString('AssetManifest.json'),
            builder: (context, snap) {
              if (!snap.hasData) return const SizedBox.shrink();
              final keys = (json.decode(snap.data!) as Map<String, dynamic>).keys.toList();
              final sample = keys.where((k) => k.contains('assets/corpus')).take(5).toList();
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
                  child: answerAsync!.when(
                    loading: () => const Text('Thinking…'),
                    error: (e, _) => Text('Could not answer: $e'),
                    data: (ans) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Answer', style: TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 6),
                        Text(ans.text),
                        if (ans.source != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Source: ${ans.source!.title}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
          // --- end Answer card ---

          Expanded(
            child: results.isEmpty
                ? const _EmptyState()
                : ListView.separated(
                    itemCount: results.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = results[index];

                      // Use current language for snippet
                      final bodyText = (lang == 'sw')
                          ? (item.contentSw ?? item.contentEn ?? '')
                          : (item.contentEn ?? item.contentSw ?? '');
                      final snippetSrc = bodyText.replaceAll('\n', ' ');
                      final snippet = snippetSrc.length <= 160
                          ? snippetSrc
                          : '${snippetSrc.substring(0, 160)} …';

                      // MergeSemantics + exclude child semantics => SR reads our concise label once.
                      return MergeSemantics(
                        child: Semantics(
                          excludeSemantics: true,
                          button: true,
                          label:
                              '${item.title}. ${snippet.isEmpty ? "Open details" : snippet}. Double tap to open details.',
                          child: ListTile(
                            title: Text(item.title),
                            // 🔎 Highlight query matches in the snippet
                            subtitle: RichText(
                              text: TextSpan(
                                style: Theme.of(context).textTheme.bodyMedium,
                                children: _highlight(snippet, query),
                              ),
                            ),
                            onTap: () async {
                              // --- Telemetry: open_from_search ---
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
                  ),
          ),
        ],
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
          'Type to search. Example: "ginger", "cayenne", "debility", "symptoms".',
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
    final short = snippet.length <= 160 ? snippet : '${snippet.substring(0, 160)} …';
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
