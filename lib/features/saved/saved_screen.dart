import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../search/search_providers.dart';
import 'bookmarks_controller.dart';
import '../content/models/content_item.dart';

class SavedScreen extends ConsumerWidget {
  const SavedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ids = ref.watch(bookmarksProvider);
    final itemsAsync = ref.watch(contentListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Saved')),
      body: itemsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (all) {
          final saved = all.where((it) => ids.contains(it.id)).toList();
          if (saved.isEmpty) {
            return const _EmptySaved();
          }
          return ListView.separated(
            itemCount: saved.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final item = saved[i];
              final snippetSrc = (item.contentEn ?? item.contentSw ?? '').replaceAll('\n', ' ');
              final snippet = snippetSrc.length <= 160 ? snippetSrc : '${snippetSrc.substring(0, 160)} …';

              return ListTile(
                leading: const Icon(Icons.bookmark),
                title: Text(item.title),
                subtitle: Text(snippet),
                onTap: () => context.go('/article/${item.id}'),
                trailing: IconButton(
                  tooltip: 'Remove',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => ref.read(bookmarksProvider.notifier).toggle(item.id),
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
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'No bookmarks yet. Tap the bookmark icon on any article to save it here.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
