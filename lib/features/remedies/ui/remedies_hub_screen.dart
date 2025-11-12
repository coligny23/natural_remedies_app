import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../content/models/content_item.dart';
import '../../search/search_providers.dart'; // contentListProvider
import 'package:go_router/go_router.dart';

class RemediesHubScreen extends ConsumerWidget {
  const RemediesHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(contentListProvider);
    return itemsAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
      data: (all) {
        final herbs = all.where((it) => it.id.startsWith('herb-')).toList()
          ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
        final grouped = _groupByInitial(herbs);

        return Scaffold(
          appBar: AppBar(title: const Text('Remedies (A–Z)')),
          body: ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
            itemCount: grouped.length,
            itemBuilder: (_, i) {
              final letter = grouped.keys.elementAt(i);
              final list = grouped[letter]!;
              return _LetterSection(letter: letter, items: list);
            },
          ),
        );
      },
    );
  }

  Map<String, List<ContentItem>> _groupByInitial(List<ContentItem> src) {
    final map = <String, List<ContentItem>>{};
    for (final it in src) {
      final ch = it.title.trim().isEmpty ? '#' : it.title.trim()[0].toUpperCase();
      final key = RegExp(r'[A-Z]').hasMatch(ch) ? ch : '#';
      map.putIfAbsent(key, () => []).add(it);
    }
    final sortedKeys = map.keys.toList()..sort();
    return {for (final k in sortedKeys) k: map[k]!};
  }
}

class _LetterSection extends StatelessWidget {
  final String letter;
  final List<ContentItem> items;
  const _LetterSection({required this.letter, required this.items});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(letter, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            ...items.map((it) => ListTile(
                  title: Text(it.title),
                  subtitle: (it.image ?? '').isNotEmpty ? Text(' ') : null,
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/article/${it.id}'),
                )),
          ],
        ),
      ),
    );
  }
}
