import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_localizations/flutter_localizations.dart';


import 'app/routing/app_router.dart';
import 'app/theme/app_theme.dart';
import 'features/search/search_providers.dart'; // <-- for languageCodeProvider
import 'features/progress/streak_providers.dart'; // <-- ADD THIS

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await Hive.openBox('bookmarks');
  await Hive.openBox('reading_progress');
  await Hive.openBox('legal');
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
    });
  }

  @override
  Widget build(BuildContext context) {
    // inside build()
    final contentLang = ref.watch(languageCodeProvider);
    final uiLocale = (contentLang == 'sw') ? const Locale('en') : const Locale('en');

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      routerConfig: appRouter,

      // ✅ add these:
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'),
        Locale('sw'), // your content language; UI will fall back to en
      ],
      locale: uiLocale,
    );
  }
}
