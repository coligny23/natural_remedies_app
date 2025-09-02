import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../app/theme/tokens.dart';

class TopicCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String id;
  const TopicCard({super.key, required this.title, required this.subtitle, required this.id});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTokens.rXl),
        onTap: () => context.push('/article/$id'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            const Icon(Icons.book_outlined, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 4),
                Text(subtitle, style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.black54)),
              ]),
            ),
            const Icon(Icons.chevron_right),
          ]),
        ),
      ),
    );
  }
}
