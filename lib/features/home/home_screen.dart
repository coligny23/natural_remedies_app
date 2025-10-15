// lib/features/home/home_screen.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

// keep your existing imports
import '../progress/continue_learning_card.dart';
import '../progress/streak_providers.dart';

// pull content + language from your existing providers
import '../content/models/content_item.dart';
import '../search/search_providers.dart'; // contentListProvider, languageCodeProvider

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final streak = ref.watch(streakProvider); // 🔥 keep your streak badge
    final lang = ref.watch(languageCodeProvider);
    final itemsAsync = ref.watch(contentListProvider);

    return itemsAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
      data: (_) {
        final remedy = ref.watch(remedyOfDayProvider);
        final principle = ref.watch(principleOfDayProvider);
        final quiz = ref.watch(quizModelProvider);

        return Scaffold(
          appBar: AppBar(
            title: const Text('Home'),
            actions: [
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
            padding: const EdgeInsets.all(16),
            children: [
              // ✅ Continue learning panel stays on top
              const ContinueLearningCard(),
              const SizedBox(height: 12),

              // 🌿 Remedy of the Day
              if (remedy != null)
                _HomeCard(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  title: lang == 'sw' ? 'Dawa ya Mimea ya Leo' : 'Remedy of the Day',
                  subtitle: remedy.title,
                  image: remedy.image,
                  onTap: () => context.go('/article/${remedy.id}'),
                ),
              if (remedy != null) const SizedBox(height: 12),

              // 🧩 Quick quiz
              if (quiz.herb != null)
                _QuizCard(
                  state: quiz,
                  onSelect: (i) => ref.read(quizModelProvider.notifier).select(i),
                  onNext: () => ref.read(quizModelProvider.notifier).next(),
                  title: lang == 'sw' ? 'Mfahamu mmea' : 'Get to know a remedy',
                ),
              if (quiz.herb != null) const SizedBox(height: 12),

              // ❤️ Principle of Health of the Day
              if (principle != null)
                _HomeCard(
                  color: Theme.of(context).colorScheme.tertiaryContainer,
                  title: lang == 'sw' ? 'Kanuni ya Afya ya Leo' : 'Principle of Health',
                  subtitle: principle.title,
                  image: principle.image,
                  onTap: () => context.go('/article/${principle.id}'),
                ),

              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }
}

/* -------------------- Providers / Helpers -------------------- */

final _todaySeedProvider = Provider<int>((ref) {
  final now = DateTime.now();
  // deterministic daily seed (changes at midnight)
  final day0 = DateTime(now.year, now.month, now.day);
  return day0.millisecondsSinceEpoch ~/ (24 * 3600 * 1000);
});

final remedyOfDayProvider = Provider<ContentItem?>((ref) {
  final items = ref.watch(contentListProvider).maybeWhen(data: (l) => l, orElse: () => <ContentItem>[]);
  final herbs = items.where((it) => it.id.startsWith('herb-')).toList();
  if (herbs.isEmpty) return null;
  final seed = ref.watch(_todaySeedProvider);
  return herbs[seed % herbs.length];
});

final principleOfDayProvider = Provider<ContentItem?>((ref) {
  final items = ref.watch(contentListProvider).maybeWhen(data: (l) => l, orElse: () => <ContentItem>[]);
  final principles = items.where((it) => it.id.startsWith('principle-')).toList();
  if (principles.isEmpty) return null;
  final seed = ref.watch(_todaySeedProvider) + 17; // offset so it differs from remedy
  return principles[seed % principles.length];
});

/* -------------------- Quiz -------------------- */

final quizModelProvider = StateNotifierProvider<_QuizController, _QuizState>((ref) {
  final items = ref.watch(contentListProvider).maybeWhen(data: (l) => l, orElse: () => <ContentItem>[]);
  final herbs = items.where((it) => it.id.startsWith('herb-')).toList();
  return _QuizController(herbs);
});

class _QuizState {
  final ContentItem? herb;
  final List<String> options; // 4 options
  final int? selected;        // tapped index
  final int correct;          // index of correct answer
  const _QuizState({this.herb, this.options = const [], this.selected, this.correct = 0});
}

class _QuizController extends StateNotifier<_QuizState> {
  _QuizController(this.herbs) : super(const _QuizState()) { next(); }

  final List<ContentItem> herbs;
  final _rand = Random();

  String _firstSentence(ContentItem it) {
    final text = (it.contentEn ?? it.contentSw ?? '').replaceAll('\n', ' ').trim();
    if (text.isEmpty) return '—';
    final m = RegExp(r'[\.!?]').firstMatch(text);
    final cutoff = m != null ? m.end : (text.length > 120 ? 120 : text.length);
    final s = text.substring(0, cutoff);
    return s.length < text.length ? '$s…' : s;
  }

  void next() {
    if (herbs.length < 4) { state = const _QuizState(); return; }
    final correctHerb = herbs[_rand.nextInt(herbs.length)];
    final distractors = <ContentItem>{};
    while (distractors.length < 3) {
      final pick = herbs[_rand.nextInt(herbs.length)];
      if (pick.id != correctHerb.id) distractors.add(pick);
    }
    final opts = [correctHerb, ...distractors.toList()]..shuffle(_rand);
    final correctIndex = opts.indexWhere((x) => x.id == correctHerb.id);
    state = _QuizState(
      herb: correctHerb,
      options: opts.map(_firstSentence).toList(),
      selected: null,
      correct: correctIndex,
    );
  }

  void select(int i) {
    state = _QuizState(
      herb: state.herb,
      options: state.options,
      selected: i,
      correct: state.correct,
    );
  }
}

/* -------------------- UI Cards -------------------- */

class _HomeCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? image;
  final VoidCallback onTap;
  final Color color;

  const _HomeCard({
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.color,
    this.image,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      color: color,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              if ((image ?? '').isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.asset(
                    image!,
                    width: 72,
                    height: 72,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox(
                      width: 72, height: 72, child: Icon(Icons.image_not_supported),
                    ),
                  ),
                ),
              if ((image ?? '').isNotEmpty) const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 6),
                    Text(subtitle, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuizCard extends StatelessWidget {
  final _QuizState state;
  final void Function(int index) onSelect;
  final VoidCallback onNext;
  final String title;

  const _QuizCard({
    required this.state,
    required this.onSelect,
    required this.onNext,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    final herbTitle = state.herb?.title ?? '';
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              'Which short description best matches "$herbTitle"?',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            for (int i = 0; i < state.options.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: ChoiceChip(
                  label: Text(state.options[i]),
                  selected: state.selected == i,
                  onSelected: (_) => onSelect(i),
                ),
              ),
            if (state.selected != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    state.selected == state.correct ? Icons.check_circle : Icons.cancel,
                    color: state.selected == state.correct ? Colors.green : Colors.red,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      state.selected == state.correct
                        ? 'Correct!'
                        : 'Not quite. The correct answer is highlighted above.',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.refresh),
                  label: const Text('Next'),
                  onPressed: onNext,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
