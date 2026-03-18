// lib/features/diseases/ui/diseases_hub_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_strings.dart';
import '../data/diseases_grouping.dart';

// ✅ Background wrapper
import '../../../widgets/app_background.dart';

class DiseasesHubScreen extends ConsumerWidget {
  const DiseasesHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppStrings.of(context);
    final grouped = ref.watch(diseasesByGroupProvider);
    final groups = DiseaseGroup.values
        .where((g) => (grouped[g]?.isNotEmpty ?? false))
        .toList();

    final s = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: Text(t.diseases)),
      body: AppBackground(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: MasonryGridView.count(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            itemCount: groups.length,
            itemBuilder: (context, i) {
              final g = groups[i];
              final items = grouped[g]!;
              final label = _groupLabelLocalized(context, g);

              final pattern = <double>[150, 190, 170, 210];
              final height = pattern[i % pattern.length];

              return _GroupCard(
                label: label,
                count: items.length,
                emoji: _groupEmoji(g),
                accent: _groupAccentColor(s, g),
                height: height,
                onTap: () => context.go('/diseases/${g.name}'),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Fun emoji per category
String _groupEmoji(DiseaseGroup g) {
  switch (g) {
    case DiseaseGroup.digestive:
      return '🍽️';
    case DiseaseGroup.respiratory:
      return '🌬️';
    case DiseaseGroup.musculoskeletal:
      return '🦴';
    case DiseaseGroup.skin:
      return '🧴';
    case DiseaseGroup.urinary:
      return '🚰';
    case DiseaseGroup.reproductive:
      return '🧬';
    case DiseaseGroup.head:
      return '🧠';
    case DiseaseGroup.general:
      return '🩺';
  }
}

String _groupLabelLocalized(BuildContext context, DiseaseGroup g) {
  final t = AppStrings.of(context);
  switch (g) {
    case DiseaseGroup.digestive:
      return t.digestive;
    case DiseaseGroup.respiratory:
      return t.respiratory;
    case DiseaseGroup.musculoskeletal:
      return t.musculoskeletal;
    case DiseaseGroup.skin:
      return t.skin;
    case DiseaseGroup.urinary:
      return t.urinary;
    case DiseaseGroup.reproductive:
      return t.reproductive;
    case DiseaseGroup.head:
      return t.head;
    case DiseaseGroup.general:
      return t.general;
  }
}

Color _groupAccentColor(ColorScheme s, DiseaseGroup g) {
  switch (g) {
    case DiseaseGroup.digestive:
      return s.primaryContainer;
    case DiseaseGroup.respiratory:
      return s.secondaryContainer;
    case DiseaseGroup.musculoskeletal:
      return s.tertiaryContainer;
    case DiseaseGroup.skin:
      return s.surfaceTint;
    case DiseaseGroup.urinary:
      return s.secondaryContainer;
    case DiseaseGroup.reproductive:
      return s.primaryContainer;
    case DiseaseGroup.head:
      return s.surfaceVariant;
    case DiseaseGroup.general:
      return s.primaryContainer;
  }
}

class _GroupCard extends StatelessWidget {
  final String label;
  final int count;
  final String emoji;
  final Color accent;
  final double height;
  final VoidCallback onTap;

  const _GroupCard({
    required this.label,
    required this.count,
    required this.emoji,
    required this.accent,
    required this.height,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppStrings.of(context);
    final s = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        height: height,
        decoration: BoxDecoration(
          color: s.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: s.outlineVariant),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.06),
              blurRadius: 14,
              offset: const Offset(0, 8),
            ),
          ],
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              accent.withOpacity(.55),
              s.surfaceContainerHighest,
            ],
          ),
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: s.onSurface.withOpacity(.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: s.outlineVariant.withOpacity(.7)),
              ),
              child: Text(emoji, style: const TextStyle(fontSize: 18)),
            ),
            const Spacer(),
            Text(
              label,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.15,
                  ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.folder_open,
                  size: 16,
                  color: s.onSurface.withOpacity(.65),
                ),
                const SizedBox(width: 6),
                Text(
                  t.topicsCount(count),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: s.onSurface.withOpacity(.7),
                      ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}