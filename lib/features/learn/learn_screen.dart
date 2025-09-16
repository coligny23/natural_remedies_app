import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../search/search_providers.dart';
import '../content/models/content_item.dart';

class LearnScreen extends ConsumerWidget {
  const LearnScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(contentListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Learn')),
      body: itemsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (items) {
          // Group by coarse section via id prefix
          List<ContentItem> by(String prefix) =>
              items.where((it) => it.id.startsWith(prefix)).toList();

          final principles = by('principle-');
          final herbs      = by('herb-');
          final diseases   = by('disease-');

          Widget section(String title, List<ContentItem> list) {
            if (list.isEmpty) return const SizedBox.shrink();
            list = List.of(list)..sort((a, b) => a.title.compareTo(b.title));
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('$title • ${list.length}', style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 8),
                      ...list.map((it) => ListTile(
                            dense: true,
                            title: Text(it.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => context.go('/article/${it.id}'),
                          )),
                    ],
                  ),
                ),
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              section('Basic Principles', principles),
              section('Important Herbs', herbs),
              section('Diseases & Conditions', diseases),
            ],
          );
        },
      ),
    );
  }
}

