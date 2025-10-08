// lib/app/routing/app_router.dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/qa/saved_answers_screen.dart'; // add import
import '../../features/content/ui/content_detail_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/learn/learn_screen.dart';
import '../../features/legal/terms_screen.dart';
import 'package:hive_flutter/hive_flutter.dart';


// Use the file/class you actually have:
import '../../features/search/search_screen.dart'; // <- was search_screen.dart
import '../../features/saved/saved_screen.dart';
import '../../features/settings/settings_screen.dart';

final appRouter = GoRouter(
    routes: [
    GoRoute(
        path: '/',
        name: 'root',

        // ✅ Gate on Terms acceptance
        redirect: (context, state) {
          final box = Hive.box('legal');              // box is opened in main.dart
          final accepted = box.get('tosAccepted') == true;

          final here = state.matchedLocation;         // e.g. '/', '/legal', '/article/...'
          final onLegal = here == '/legal' || here.endsWith('/legal');

          if (!accepted && !onLegal) return '/legal'; // force Terms until accepted
          if (accepted && onLegal) return '/';        // once accepted, go back to root
          return null;                                // no change
        },

        // Allow selecting a tab via query: /?tab=2
        builder: (context, state) {
          final tabStr = state.uri.queryParameters['tab'] ?? '0';
          final initialIndex = int.tryParse(tabStr) ?? 0;
          return RootTabs(initialIndex: initialIndex);
        },

        routes: [
          // Friendly deep links to switch tabs
          GoRoute(path: 'home', redirect: (_, __) => '/?tab=0'),
          GoRoute(path: 'learn', redirect: (_, __) => '/?tab=1'),
          GoRoute(path: 'search', redirect: (_, __) => '/?tab=2'),
          GoRoute(path: 'saved', redirect: (_, __) => '/?tab=3'),
          GoRoute(path: 'settings', redirect: (_, __) => '/?tab=4'),

          // Example deep-link: /article/ginger
          GoRoute(
            path: 'article/:id',
            name: 'article',
            builder: (_, state) {
              final id = state.pathParameters['id']!;
              final section = state.uri.queryParameters['section'];
              return ContentDetailScreen(id: id, initialSection: section);
            },
          ),

          GoRoute(
            path: 'saved-answers',
            name: 'saved-answers',
            builder: (_, __) => const SavedAnswersScreen(),
          ),
          GoRoute(
            path: 'legal',
            name: 'legal',
            builder: (_, __) => const TermsScreen(),
          ),
        ],
      ),
  
  ],
);


class RootTabs extends StatefulWidget {
  final int initialIndex;
  const RootTabs({super.key, this.initialIndex = 0});

  @override
  State<RootTabs> createState() => _RootTabsState();
}

class _RootTabsState extends State<RootTabs> {
  late final CupertinoTabController _controller;

  final _pages = const [
    HomeScreen(),
    LearnScreen(),
    // Use SearchPage (or change to SearchScreen if that's your class name)
    SearchScreen(),
    SavedScreen(),
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _controller = CupertinoTabController(
      initialIndex: widget.initialIndex.clamp(0, _pages.length - 1),
    );
  }

  @override
  void didUpdateWidget(covariant RootTabs oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialIndex != oldWidget.initialIndex) {
      _controller.index = widget.initialIndex.clamp(0, _pages.length - 1);
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoTabScaffold(
      controller: _controller,
      tabBar: CupertinoTabBar(
        currentIndex: _controller.index,
        onTap: (i) => setState(() => _controller.index = i),
        items: const [
          BottomNavigationBarItem(
              icon: Icon(CupertinoIcons.house), label: 'Home'),
          BottomNavigationBarItem(
              icon: Icon(CupertinoIcons.square_list), label: 'Learn'),
          BottomNavigationBarItem(
              icon: Icon(CupertinoIcons.search), label: 'Search'),
          BottomNavigationBarItem(
              icon: Icon(CupertinoIcons.bookmark), label: 'Saved'),
          BottomNavigationBarItem(
              icon: Icon(CupertinoIcons.gear), label: 'Settings'),
        ],
      ),
      tabBuilder: (_, i) => CupertinoTabView(builder: (_) => _pages[i]),
    );
  }
}

class ArticleScreen extends StatelessWidget {
  final String id;
  const ArticleScreen({super.key, required this.id});

  @override
  Widget build(BuildContext context) {
    return const CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(middle: Text('Article')),
      child: Center(child: Text('Article detail goes here')),
    );
  }
}
