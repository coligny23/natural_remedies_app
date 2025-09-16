import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../search/search_providers.dart';     // contentListProvider
import '../content/models/content_item.dart';
import '../content/ui/content_detail_screen.dart';
import 'bookmarks_controller.dart';

class SavedScreen extends ConsumerWidget {
  const SavedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final savedIds = ref.watch(bookmarksProvider);
    final itemsAsync = ref.watch(contentListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved'),
        actions: [
          if (savedIds.isNotEmpty)
            IconButton(
              tooltip: 'Clear all',
              icon: const Icon(Icons.delete_outline),
              onPressed: () {
                ref.read(bookmarksProvider.notifier).clear();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Cleared all saved items')),
                );
              },
            ),
        ],
      ),
      body: itemsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (all) {
          final set = savedIds;
          final progress = Hive.box('reading_progress');

          // Filter
          final saved = all.where((it) => set.contains(it.id)).toList();

          // Sort (most recently opened first; fallback = very old)
          DateTime _ts(ContentItem it) =>
              (progress.get('time_${it.id}') as DateTime?) ??
              DateTime.fromMillisecondsSinceEpoch(0);

          saved.sort((a, b) => _ts(b).compareTo(_ts(a)));

          if (saved.isEmpty) {
            return const _EmptySaved();
          }

          return ListView.separated(
            itemCount: saved.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final it = saved[i];
              final last = _ts(it);
              return Semantics(
                button: true,
                label: '${it.title}. Last opened ${_relative(last)}. Double tap to open.',
                child: ListTile(
                  title: Text(it.title),
                  subtitle: Text('Last opened ${_relative(last)}'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => ContentDetailScreen(id: it.id),
                    ));
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _EmptySaved extends StatelessWidget {
  const _EmptySaved();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'Nothing saved yet.\nTap the bookmark icon on an article to save it here.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
    );
  }
}

// Simple relative time ("2h ago", "3d ago")
String _relative(DateTime t) {
  final d = DateTime.now().difference(t);
  if (d.inDays >= 7) return '${(d.inDays / 7).floor()}w ago';
  if (d.inDays >= 1) return '${d.inDays}d ago';
  if (d.inHours >= 1) return '${d.inHours}h ago';
  if (d.inMinutes >= 1) return '${d.inMinutes}m ago';
  return 'just now';
}
