// lib/app/routing/app_router.dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/home/home_screen.dart';
import '../../features/learn/learn_screen.dart';
import '../../features/search/search_screen.dart';
import '../../features/saved/saved_screen.dart';
import '../../features/settings/settings_screen.dart';

final appRouter = GoRouter(
  routes: [
    GoRoute(
      path: '/',
      builder: (_, __) => const RootTabs(),
      routes: [
        // Example deep-link route for details (e.g., /article/ginger)
        GoRoute(
          path: 'article/:id',
          builder: (_, state) {
            final id = state.pathParameters['id']!;
            return ArticleScreen(id: id);
          },
        ),
      ],
    ),
  ],
);

class RootTabs extends StatefulWidget {
  const RootTabs({super.key});
  @override
  State<RootTabs> createState() => _RootTabsState();
}

class _RootTabsState extends State<RootTabs> {
  final _pages = const [
    HomeScreen(), LearnScreen(), SearchScreen(), SavedScreen(), SettingsScreen()
  ];

  @override
  Widget build(BuildContext context) {
    return CupertinoTabScaffold(
      tabBar: CupertinoTabBar(
  items: const [
    BottomNavigationBarItem(icon: Icon(CupertinoIcons.house), label: 'Home'),
    BottomNavigationBarItem(icon: Icon(CupertinoIcons.square_list), label: 'Learn'),
    BottomNavigationBarItem(icon: Icon(CupertinoIcons.search), label: 'Search'),
    BottomNavigationBarItem(icon: Icon(CupertinoIcons.bookmark), label: 'Saved'),
    BottomNavigationBarItem(icon: Icon(CupertinoIcons.gear), label: 'Settings'),
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
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(middle: Text('Article')),
      child: Center(child: Text('Article: $id')),
    );
  }
}
