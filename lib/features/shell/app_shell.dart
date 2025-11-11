import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AppShell extends StatelessWidget {
  final Widget child;
  const AppShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: child,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/search'),
        icon: const Icon(Icons.search),
        label: const Text('Search'),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: NavigationBar(
        height: 66,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.medication_outlined), selectedIcon: Icon(Icons.medication), label: 'Diseases'),
          NavigationDestination(icon: Icon(Icons.spa_outlined), selectedIcon: Icon(Icons.spa), label: 'Remedies'),
          NavigationDestination(icon: Icon(Icons.bookmark_border), selectedIcon: Icon(Icons.bookmark), label: 'Saved'),
        ],
        onDestinationSelected: (i) {
          switch (i) {
            case 0: context.go('/'); break;
            case 1: context.go('/diseases'); break;
            case 2: context.go('/remedies'); break;
            case 3: context.go('/saved'); break;
          }
        },
        selectedIndex: _indexFromPath(GoRouterState.of(context).uri.path),
        surfaceTintColor: scheme.surfaceTint,
      ),
    );
  }

  int _indexFromPath(String path) {
    if (path.startsWith('/diseases')) return 1;
    if (path.startsWith('/remedies')) return 2;
    if (path.startsWith('/saved')) return 3;
    return 0;
  }
}
