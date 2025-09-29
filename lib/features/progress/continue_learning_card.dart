import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'progress_providers.dart';
import '../content/models/content_item.dart';
import '../search/search_providers.dart';

class ContinueLearningCard extends ConsumerWidget {
  const ContinueLearningCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(progressProvider);
    if (progress.isEmpty) return const SizedBox.shrink();

    // Pick the most recently updated entry
    String? latestId;
    Map? latestData;
    int latestTs = -1;
    progress.forEach((id, data) {
      final ts = (data['updatedAt'] ?? 0) as int;
      if (ts > latestTs) {
        latestTs = ts; latestId = id; latestData = data;
      }
    });
    if (latestId == null) return const SizedBox.shrink();

    final itemsAsync = ref.watch(contentListProvider);
    return itemsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (items) {
        final item = items.firstWhere(
          (it) => it.id == latestId,
          orElse: () => ContentItem(id: latestId!, title: latestId!, contentEn: '', contentSw: '',),
        );
        final pct = (((latestData?['percent'] ?? 0.0) as double) * 100).clamp(0, 100).round();
        final section = latestData?['lastSection'] as String?;

        return Padding(
          padding: const EdgeInsets.all(16),
          child: Card(
            child: ListTile(
              leading: const Icon(Icons.play_arrow),
              title: const Text('Continue learning'),
              subtitle: Text('${item.title}  •  $pct% read'),
              onTap: () => context.go('/article/${item.id}${section != null ? '?section=$section' : ''}'),
            ),
          ),
        );
      },
    );
  }
}
