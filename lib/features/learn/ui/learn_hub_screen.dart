// lib/features/learn/ui/learn_hub_screen.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../l10n/app_strings.dart';
import '../../../app/theme/app_theme.dart';
import '../../../widgets/app_background.dart';

class LearnHubScreen extends StatelessWidget {
  const LearnHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = AppStrings.of(context);
    final s = Theme.of(context).colorScheme;
    final glossy = Theme.of(context).extension<GlossyCardTheme>()!;
    final elev = Theme.of(context).extension<AppElevations>()!;

    Widget tile({
      required IconData icon,
      required String title,
      required String subtitle,
      required VoidCallback onTap,
      List<Color>? grad,
      String? semanticsLabel,
    }) {
      final header = Container(
        decoration: glossy.headerDecoration().copyWith(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors:
                grad ??
                [s.primary.withOpacity(.14), s.tertiary.withOpacity(.10)],
          ),
        ),
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white
                    : Colors.black87,
                size: 22,
                semanticLabel: semanticsLabel ?? title,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(
                      context,
                    ).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: s.onSurface.withOpacity(.7),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

      final body = Container(
        decoration: glossy.bodyDecoration().copyWith(
          boxShadow: glossy.shadows
              .map((b) => b.copyWith(blurRadius: b.blurRadius + elev.base))
              .toList(),
          borderRadius: const BorderRadius.vertical(
            bottom: Radius.circular(20),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: onTap,
            icon: const Icon(Icons.arrow_forward),
            label: Text(t.open),
          ),
        ),
      );

      return ClipRRect(
        borderRadius: const BorderRadius.all(Radius.circular(20)),
        child: Stack(
          children: [
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(
                  sigmaX: glossy.blurSigma,
                  sigmaY: glossy.blurSigma,
                ),
                child: const SizedBox(),
              ),
            ),
            Container(decoration: glossy.bodyDecoration()),
            Column(children: [header, body]),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(t.learn),
      ),
      body: AppBackground(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            tile(
              icon: Icons.menu_book_outlined,
              title: t.principlesOfHealth,
              subtitle: t.principlesOfHealthSubtitle,
              onTap: () => context.push('/principles'),
              grad: [s.tertiary, s.tertiaryContainer],
            ),
            const SizedBox(height: 12),
            tile(
              icon: Icons.spa_outlined,
              title: t.importantHerbs,
              subtitle: t.importantHerbsSubtitle,
              onTap: () => context.push('/remedies'),
              grad: [s.primary, s.primaryContainer],
            ),
            const SizedBox(height: 12),
            tile(
              icon: Icons.medical_services_outlined,
              title: t.diseasesConditions,
              subtitle: t.diseasesConditionsSubtitle,
              onTap: () => context.push('/diseases'),
              grad: [s.secondary, s.secondaryContainer],
            ),
            const SizedBox(height: 12),
            tile(
              icon: Icons.sort_by_alpha,
              title: t.browseEverything,
              subtitle: t.browseEverythingSubtitle,
              onTap: () => context.push('/learn/all'),
              grad: [s.surfaceTint, s.surfaceVariant],
            ),
          ],
        ),
      ),
    );
  }
}