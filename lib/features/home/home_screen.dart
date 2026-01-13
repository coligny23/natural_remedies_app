// lib/features/home/home_screen.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../widgets/app_background.dart';

// keep your existing imports
import '../progress/continue_learning_card.dart';
import '../progress/streak_providers.dart';

// pull content + language from your existing providers
import '../content/models/content_item.dart';
import '../search/search_providers.dart'; // contentListProvider, languageCodeProvider
import '../content/data/content_lookup_provider.dart'; // contentByIdProvider

// theme extensions (gloss, elevation)
import '../../app/theme/app_theme.dart';

// ✅ ML personalization (For You)
import '../../shared/ml/ml_providers.dart'; // forYouIdsProvider
import '../settings/feature_flags.dart'; // useTfliteProvider

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final streak = ref.watch(streakProvider); // 🔥 keep your streak badge
    final lang = ref.watch(languageCodeProvider);
    final itemsAsync = ref.watch(contentListProvider);

    // ✅ ML toggle + candidates for "For You"
    final useTfl = ref.watch(useTfliteProvider);
    final forYouIdsAsync = ref.watch(forYouIdsProvider);

    return itemsAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
      data: (_) {
        final remedy = ref.watch(remedyOfDayProvider);
        final principle = ref.watch(principleOfDayProvider);
        final quiz = ref.watch(quizModelProvider);

        return Scaffold(
          backgroundColor: Colors.transparent, // let the background show through
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

          // ✅ Only change: wrap your existing ListView in AppBackground
          body: AppBackground(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              children: [
                _HeroHeader(
                  onSearch: () => context.go('/search'),
                  onOpenDiseases: () => context.go('/diseases'),
                  onOpenRemedies: () => context.go('/remedies'),
                ),
                const SizedBox(height: 12),

                const ContinueLearningCard(),
                const SizedBox(height: 12),

                // ✅ NEW: "For You" rail (optional; shows only when toggle ON and we have profile-based IDs)
                if (useTfl)
                  forYouIdsAsync.when(
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                    data: (ids) {
                      // Map IDs to items (skip any that aren't loaded)
                      final items = <ContentItem>[];
                      for (final id in ids) {
                        final it = ref.watch(contentByIdProvider(id));
                        if (it != null) items.add(it);
                      }
                      if (items.isEmpty) return const SizedBox.shrink();

                      return _ForYouRail(
                        title: lang == 'sw' ? 'Kwa Ajili Yako' : 'For You',
                        items: items,
                        onOpen: (id) => context.go('/article/$id'),
                      );
                    },
                  ),

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

                const SizedBox(height: 24),
              ],
            ),
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

/* -------------------- UI: Hero Header -------------------- */

class _HeroHeader extends StatelessWidget {
  final VoidCallback onSearch;
  final VoidCallback onOpenDiseases;
  final VoidCallback onOpenRemedies;

  const _HeroHeader({
    required this.onSearch,
    required this.onOpenDiseases,
    required this.onOpenRemedies,
  });

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    final glossy = Theme.of(context).extension<GlossyCardTheme>()!;
    final elev = Theme.of(context).extension<AppElevations>()!;

    return Container(
      decoration: glossy.headerDecoration().copyWith(
        boxShadow: glossy.shadows
            .map((sh) => sh.copyWith(blurRadius: sh.blurRadius + elev.high))
            .toList(),
      ),
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title + supporting line
          Text(
            'Your daily natural health companion',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            'Remedies • Principles • Guided learning',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: s.onSurface.withOpacity(.75),
                ),
          ),
          const SizedBox(height: 12),
          // Quick actions
          Row(
            children: [
              _PillButton(
                icon: Icons.search,
                label: 'Search',
                onTap: onSearch,
              ),
              const SizedBox(width: 10),
              _PillButton(
                icon: Icons.medication,
                label: 'Diseases',
                onTap: onOpenDiseases,
              ),
              const SizedBox(width: 10),
              _PillButton(
                icon: Icons.spa,
                label: 'Remedies',
                onTap: onOpenRemedies,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PillButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _PillButton({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    return Material(
      color: s.secondaryContainer.withOpacity(.6),
      shape: const StadiumBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              Icon(icon, size: 18, color: s.onSecondaryContainer),
              const SizedBox(width: 8),
              Text(label, style: TextStyle(color: s.onSecondaryContainer, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}

/* -------------------- UI Cards (Glass + Motion) -------------------- */

class _HomeCard extends StatefulWidget {
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
  State<_HomeCard> createState() => _HomeCardState();
}

class _HomeCardState extends State<_HomeCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final glossy = Theme.of(context).extension<GlossyCardTheme>()!;
    final elev = Theme.of(context).extension<AppElevations>()!;
    final scheme = Theme.of(context).colorScheme;

    return AnimatedScale(
      duration: AppTokens.short,
      scale: _pressed ? 0.985 : 1.0,
      child: InkWell(
        onTap: widget.onTap,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) => setState(() => _pressed = false),
        borderRadius: glossy.borderRadius,
        child: AnimatedContainer(
          duration: AppTokens.medium,
          decoration: glossy.bodyDecoration().copyWith(
            // add a slim accent spine
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                widget.color.withOpacity(.35),
                glossy.surface.withOpacity(.90),
              ],
            ),
            boxShadow: glossy.shadows
                .map((sh) => sh.copyWith(
                      blurRadius: (_pressed ? elev.small : elev.base) + sh.blurRadius,
                    ))
                .toList(),
          ),
          child: Stack(
            children: [
              // Optional subtle image shimmer/clip
              if ((widget.image ?? '').isNotEmpty)
                Positioned(
                  right: 10,
                  top: 10,
                  bottom: 10,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.asset(
                      widget.image!,
                      width: 92,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          const SizedBox(width: 92, child: Icon(Icons.image_not_supported)),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                child: Row(
                  children: [
                    // Leading accent chip
                    Container(
                      width: 10,
                      height: 48,
                      decoration: BoxDecoration(
                        color: widget.color.withOpacity(.85),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Titles
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.title,
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(letterSpacing: 0.2)),
                          const SizedBox(height: 6),
                          Text(
                            widget.subtitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -.1,
                                ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.arrow_forward_ios, size: 16, color: scheme.onSurface.withOpacity(.6)),
                  ],
                ),
              ),
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
    final glossy = Theme.of(context).extension<GlossyCardTheme>()!;
    final elev = Theme.of(context).extension<AppElevations>()!;

    return Container(
      decoration: glossy.bodyDecoration().copyWith(
        boxShadow: glossy.shadows
            .map((s) => s.copyWith(blurRadius: s.blurRadius + elev.base))
            .toList(),
      ),
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

/* -------------------- NEW: For You rail -------------------- */

class _ForYouRail extends StatelessWidget {
  final String title;
  final List<ContentItem> items;
  final void Function(String id) onOpen;

  const _ForYouRail({
    required this.title,
    required this.items,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              Icon(Icons.auto_awesome, size: 18, color: s.primary),
            ],
          ),
        ),
        SizedBox(
          height: 148,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, i) {
              final it = items[i];
              return _ForYouCard(
                title: it.title,
                image: it.image,
                onTap: () => onOpen(it.id),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _ForYouCard extends StatelessWidget {
  final String title;
  final String? image;
  final VoidCallback onTap;
  const _ForYouCard({required this.title, this.image, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final glossy = Theme.of(context).extension<GlossyCardTheme>();
    final elevation = Theme.of(context).extension<AppElevations>()?.base ?? 8;
    final deco = (glossy?.bodyDecoration().copyWith(
          boxShadow: glossy?.shadows
              .map((s) => s.copyWith(blurRadius: s.blurRadius + elevation))
              .toList(),
        )) ??
        BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Theme.of(context).dividerColor.withOpacity(.35)),
        );

    return InkWell(
      onTap: onTap,
      borderRadius: glossy?.borderRadius ?? BorderRadius.circular(16),
      child: Container(
        width: 220,
        decoration: deco,
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // thumbnail
            if ((image ?? '').isNotEmpty)
              AspectRatio(
                aspectRatio: 16 / 9,
                child: Image.asset(
                  image!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const ColoredBox(
                    color: Colors.black26,
                    child: Center(child: Icon(Icons.image_not_supported)),
                  ),
                ),
              )
            else
              const AspectRatio(
                aspectRatio: 16 / 9,
                child: ColoredBox(
                  color: Colors.black12,
                  child: Center(child: Icon(Icons.eco)),
                ),
              ),
            // title
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/* -------------------- Design tokens used in animations -------------------- */

class AppTokens {
  static const short = Duration(milliseconds: 150);
  static const medium = Duration(milliseconds: 220);
}
