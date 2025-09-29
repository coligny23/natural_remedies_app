import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../content/models/content_item.dart';
import 'saved_answers_providers.dart';
import 'package:go_router/go_router.dart';

class SavedAnswersScreen extends ConsumerWidget {
  const SavedAnswersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saved = ref.watch(savedQaListProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved Answers'),
        actions: [
          if (saved.isNotEmpty)
            IconButton(
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Clear all?'),
                    content: const Text('Remove all saved answers?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                      TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Clear')),
                    ],
                  ),
                );
                if (ok == true) {
                  await ref.read(savedQaListProvider.notifier).clear();
                }
              },
              icon: const Icon(Icons.delete_sweep),
              tooltip: 'Clear all',
            ),
        ],
      ),
      body: saved.isEmpty
          ? const _Empty()
          : ListView.separated(
              itemCount: saved.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (ctx, i) {
                final it = saved[i];
                return ListTile(
                  title: Text(it.answerText, maxLines: 3, overflow: TextOverflow.ellipsis),
                  subtitle: Text('Q: ${it.question}\n${it.sourceTitle ?? "—"}',
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                  onTap: () {
                    // If you want to deep-link to the article:
                    if (it.sourceId != null) {
                      context.go('/article/${it.sourceId}');
                    }
                  },
                  trailing: IconButton(
                    tooltip: 'Remove',
                    icon: const Icon(Icons.close),
                    onPressed: () => ref.read(savedQaListProvider.notifier).remove(it.id),
                  ),
                );
              },
            ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'No saved answers yet.\nUse the ⭐ on the answer card to save one.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
    );
  }
}
