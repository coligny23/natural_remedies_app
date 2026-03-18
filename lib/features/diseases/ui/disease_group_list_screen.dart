// lib/features/diseases/ui/disease_group_list_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../l10n/app_strings.dart';
import '../../content/models/content_item.dart';
import '../data/diseases_grouping.dart';

class DiseaseGroupListScreen extends ConsumerWidget {
  final String groupName; // e.g., "digestive"
  const DiseaseGroupListScreen({super.key, required this.groupName});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final g = DiseaseGroup.values.firstWhere(
      (e) => e.name == groupName,
      orElse: () => DiseaseGroup.general,
    );
    final map = ref.watch(diseasesByGroupProvider);
    final items = map[g] ?? const <ContentItem>[];

    return Scaffold(
      appBar: AppBar(
        title: Text(_groupLabelLocalized(context, g)),
      ),
      body: ListView.separated(
        itemCount: items.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, i) {
          final it = items[i];
          return ListTile(
            title: Text(it.title),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => context.push('/article/${it.id}'),
          );
        },
      ),
    );
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