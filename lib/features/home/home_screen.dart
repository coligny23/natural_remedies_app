// lib/features/home/home_screen.dart
import 'package:flutter/material.dart';
import '../progress/continue_learning_card.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Home')),
      body: ListView(
        children: const [
          // ✅ Continue learning panel at the top (from progress/continue_learning_card.dart)
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
