// lib/features/home/home_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; // <-- add this
import 'package:go_router/go_router.dart';
import '../progress/continue_learning_card.dart';
import '../progress/streak_providers.dart';

class HomeScreen extends ConsumerWidget { // <-- was StatelessWidget
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) { // <-- accept WidgetRef
    final streak = ref.watch(streakProvider); // <-- read current streak count

    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        actions: [
          // 🔥 Streak badge (only if > 0)
          if (streak > 0)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Chip(
                avatar: const Icon(Icons.local_fire_department, size: 18),
                label: Text('${streak}d'),
              ),
            ),
          IconButton(
            tooltip: 'Saved Answers',
            icon: const Icon(Icons.star),
            onPressed: () => context.go('/saved-answers'),
          ),
        ],
      ),
      body: ListView(
        children: const [
          // ✅ Continue learning panel at the top
          ContinueLearningCard(),
          SizedBox(height: 8),

          // (Optional) placeholders for your other sections
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
