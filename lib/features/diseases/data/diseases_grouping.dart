// lib/features/diseases/data/disease_grouping.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../content/models/content_item.dart';
import '../../search/search_providers.dart';

enum DiseaseGroup {
  digestive, respiratory, musculoskeletal, reproductive, head, skin, general, urinary
}

String groupLabel(DiseaseGroup g) {
  switch (g) {
    case DiseaseGroup.digestive: return 'Digestive';
    case DiseaseGroup.respiratory: return 'Respiratory';
    case DiseaseGroup.musculoskeletal: return 'Musculoskeletal';
    case DiseaseGroup.reproductive: return 'Reproductive';
    case DiseaseGroup.head: return 'Head';
    case DiseaseGroup.skin: return 'Skin';
    case DiseaseGroup.general: return 'General';
    case DiseaseGroup.urinary: return 'Urinary';
  }
}

DiseaseGroup inferGroup(ContentItem it) {
  final id = (it.id).toLowerCase();
  final t  = (it.title).toLowerCase();

  bool any(Iterable<String> keys) =>
      keys.any((k) => id.contains(k) || t.contains(k));

  if (any(['digest', 'stomach', 'ulcer', 'diarr', 'constipat', 'liver', 'bile'])) {
    return DiseaseGroup.digestive;
  }
  if (any(['cough', 'asthma', 'bronch', 'pneum', 'respir', 'flu', 'cold'])) {
    return DiseaseGroup.respiratory;
  }
  if (any(['muscle', 'joint', 'arthritis', 'bone', 'back pain', 'sprain'])) {
    return DiseaseGroup.musculoskeletal;
  }
  if (any(['reproduct', 'fertility', 'menstr', 'pregnan', 'uter', 'ovary', 'prostat'])) {
    return DiseaseGroup.reproductive;
  }
  if (any(['headache', 'migraine', 'neuro', 'brain', 'ear', 'eye', 'tooth'])) {
    return DiseaseGroup.head;
  }
  if (any(['skin', 'rash', 'eczema', 'acne', 'ringworm', 'dermat'])) {
    return DiseaseGroup.skin;
  }
  return DiseaseGroup.general;
}

final diseasesByGroupProvider =
    Provider<Map<DiseaseGroup, List<ContentItem>>>((ref) {
  final items = ref.watch(contentListProvider).maybeWhen(
    data: (l) => l,
    orElse: () => <ContentItem>[],
  );

  final diseases = items.where((it) => it.id.startsWith('disease-')).toList();
  final map = <DiseaseGroup, List<ContentItem>>{
    for (final g in DiseaseGroup.values) g: <ContentItem>[],
  };

  for (final d in diseases) {
    map[inferGroup(d)]!.add(d);
  }

  // sort each bucket alphabetically for consistent UI
  for (final g in map.keys) {
    map[g]!.sort((a, b) => a.title.compareTo(b.title));
  }
  return map;
});
