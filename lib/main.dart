import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'package:google_fonts/google_fonts.dart';
import 'app/routing/app_router.dart';
import 'app/theme/app_theme.dart';
import 'features/search/search_providers.dart'; // <-- for languageCodeProvider
import 'features/progress/streak_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await Hive.openBox('bookmarks');
  await Hive.openBox('reading_progress');
  await Hive.openBox('legal');
  await Hive.openBox('ml_profile');
  runApp(const ProviderScope(child: App()));
}

class App extends ConsumerStatefulWidget {
  const App({super.key});

  @override
  ConsumerState<App> createState() => _AppState();
}

class _AppState extends ConsumerState<App> {
  @override
  void initState() {
    super.initState();
    // Mark streak on first app open each day (once, after first frame)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(streakProvider.notifier).markActiveToday();

      // ⬇️ Also pre-cache background images from the theme extension
      _precacheBackgrounds();
    });
  }

  // Pre-cache both light & dark background assets if provided by the theme.
  void _precacheBackgrounds() {
    final ctx = context;
    final bg = Theme.of(ctx).extension<BackgroundImages>();
    if (bg == null) return;

    // Fire-and-forget; no need to await inside the frame callback
    if (bg.lightAsset != null && bg.lightAsset!.isNotEmpty) {
      precacheImage(AssetImage(bg.lightAsset!), ctx);
    }
    if (bg.darkAsset != null && bg.darkAsset!.isNotEmpty) {
      precacheImage(AssetImage(bg.darkAsset!), ctx);
    }
  }

  @override
  Widget build(BuildContext context) {
    final contentLang = ref.watch(languageCodeProvider);
    final uiLocale =
        (contentLang == 'sw') ? const Locale('en') : const Locale('en');

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system,
      theme:
          AppTheme.light(), // <- make sure BackgroundImages is registered here
      darkTheme: AppTheme.dark(), // <- and here
      routerConfig: appRouter,

      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'),
        Locale('sw'),
      ],
      locale: uiLocale,
    );
  }
}
