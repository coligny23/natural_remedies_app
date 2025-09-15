import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'app/routing/app_router.dart';
import 'app/theme/app_theme.dart';
import 'features/search/search_providers.dart'; // <-- for languageCodeProvider

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await Hive.openBox('bookmarks');
  await Hive.openBox('reading_progress');
  runApp(const ProviderScope(child: App()));
}

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(languageCodeProvider); // 'en' or 'sw'

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      routerConfig: appRouter,

      // Day 8 additions:
      locale: Locale(lang),
      supportedLocales: const [Locale('en'), Locale('sw')],
    );
  }
}
