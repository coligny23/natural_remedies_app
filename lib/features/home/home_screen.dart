// lib/features/home/home_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; // for ConsumerWidget, WidgetRef
import 'package:hive_flutter/hive_flutter.dart';         // for Hive.box(...)
import 'package:go_router/go_router.dart';               // for context.go()

import '../search/search_providers.dart';                // contentListProvider
import '../content/data/content_lookup_provider.dart';   // contentByIdProvider

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Home')),
      body: ListView(
        children: const [
          // ✅ Continue learning panel at the top
          ContinueLearningCard(),
          SizedBox(height: 8),

          // (Optional) placeholders for your other sections
          // You can replace these with your real content later
          _PlaceholderSection(title: 'Featured'),
          SizedBox(height: 8),
          _PlaceholderSection(title: 'Popular Herbs'),
          SizedBox(height: 16),
        ],
      ),
    );
  }
}

/// Small placeholder card you can remove later.
class _PlaceholderSection extends StatelessWidget {
  final String title;
  const _PlaceholderSection({required this.title});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: ListTile(
        title: Text(title),
        subtitle: const Text('Coming soon…'),
      ),
    );
  }
}

/// Reads the last opened article id from Hive ('reading_progress'),
/// fetches the item from in-memory content, and shows a quick resume card.
class ContinueLearningCard extends ConsumerWidget {
  const ContinueLearningCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lastId = Hive.box('reading_progress').get('last_id') as String?;
    if (lastId == null) return const SizedBox.shrink(); // nothing to continue

    final itemsAsync = ref.watch(contentListProvider);
    return itemsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (_) {
        final item = ref.watch(contentByIdProvider(lastId));
        if (item == null) return const SizedBox.shrink();

        final snippetSrc = (item.contentEn ?? item.contentSw ?? '').replaceAll('\n', ' ');
        final snippet = snippetSrc.length <= 120 ? snippetSrc : '${snippetSrc.substring(0, 120)} …';

        return Card(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: ListTile(
            leading: const Icon(Icons.play_circle_outline),
            title: const Text('Continue learning'),
            subtitle: Text(item.title),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => context.go('/article/${item.id}'),
          ),
        );
      },
    );
  }
}
