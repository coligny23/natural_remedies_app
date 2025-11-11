import 'package:flutter/material.dart';

class EmptyState extends StatelessWidget {
  final String title, message;
  final IconData icon;
  final VoidCallback? onAction;
  final String? actionLabel;
  const EmptyState({super.key, required this.title, required this.message, required this.icon, this.onAction, this.actionLabel});

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: s.primary),
            const SizedBox(height: 12),
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(message, textAlign: TextAlign.center),
            if (onAction != null) ...[
              const SizedBox(height: 12),
              FilledButton(onPressed: onAction, child: Text(actionLabel ?? 'Retry')),
            ]
          ],
        ),
      ),
    );
  }
}
