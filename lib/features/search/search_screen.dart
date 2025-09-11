import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'search_providers.dart';
import '../content/models/content_item.dart';

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
    _debounce = Timer(const Duration(milliseconds: 150), () {
      ref.read(searchQueryProvider.notifier).state = text;
    });
  }

  @override
  Widget build(BuildContext context) {
    final results = ref.watch(searchResultsProvider);
    final isLoading = ref.watch(contentListProvider).isLoading;

    final itemsAsync = ref.watch(contentListProvider);
    final total =
        itemsAsync.maybeWhen(data: (it) => it.length, orElse: () => null);

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
                  child: Text('Manifest sample: ${sample.isEmpty ? "(none)" : sample.join(", ")}',
                      style: Theme.of(context).textTheme.bodySmall),
                ),
              );
            },
          ),
          const SizedBox(height: 4),

          
          Expanded(
            child: results.isEmpty
                ? const _EmptyState()
                : ListView.separated(
                    itemCount: results.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = results[index];
final snippetSrc = (item.contentEn ?? item.contentSw ?? '').replaceAll('\n', ' ');
final snippet = snippetSrc.length <= 160 ? snippetSrc : '${snippetSrc.substring(0, 160)} …';

// MergeSemantics + exclude child semantics => SR reads our concise label once.
return MergeSemantics(
  child: Semantics(
    excludeSemantics: true,          // replace children semantics with our label
    button: true,                    // announces as tappable item
    label: '${item.title}. $snippet. Double tap to open details.',
    child: ListTile(
      title: Text(item.title),
      subtitle: Text(snippet),
      onTap: () {
        // TODO: navigate to detail (e.g., context.go('/article/${item.id}'))
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
    final short =
        snippet.length <= 160 ? snippet : '${snippet.substring(0, 160)} …';
    return Text(short);
  }
}
