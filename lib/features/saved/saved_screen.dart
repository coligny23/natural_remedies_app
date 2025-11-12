// lib/features/saved/saved_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../content/models/content_item.dart';
import '../content/data/content_lookup_provider.dart'; // contentByIdProvider(id)
import '../search/search_providers.dart';              // contentListProvider, languageCodeProvider
import 'bookmarks_controller.dart';                    // bookmarksProvider

// ✅ Add the background wrapper
import '../../widgets/app_background.dart';

class SavedScreen extends ConsumerStatefulWidget {
  const SavedScreen({super.key});

  @override
  ConsumerState<SavedScreen> createState() => _SavedScreenState();
}

class _SavedScreenState extends ConsumerState<SavedScreen> {
  final _filterCtrl = TextEditingController();
  Timer? _debounce;
  String _filter = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _filterCtrl.dispose();
    super.dispose();
  }

  void _onFilterChanged(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 120), () {
      setState(() => _filter = text.trim().toLowerCase());
    });
  }

  @override
  Widget build(BuildContext context) {
    final bookmarks = ref.watch(bookmarksProvider);
    final itemsAsync = ref.watch(contentListProvider);
    final lang = ref.watch(languageCodeProvider);

    return Scaffold(
      backgroundColor: Colors.transparent, // ✅ let the global background show
      appBar: AppBar(title: const Text('Saved Remedies')),
      body: AppBackground(
        asset: 'assets/images/articles_jpg/imageone.jpg', // ✅ wrap the whole page body
        child: itemsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (_) {
            if (bookmarks.isEmpty) {
              return const _EmptySaved();
            }

            // Materialize saved items from in-memory content
            final savedItems = <ContentItem>[];
            for (final id in bookmarks) {
              final it = ref.watch(contentByIdProvider(id));
              if (it != null) savedItems.add(it);
            }

            // Filter (optional)
            List<ContentItem> filtered = savedItems;
            if (_filter.isNotEmpty) {
              filtered = savedItems.where((it) {
                final title = it.title.toLowerCase();
                final body = (lang == 'sw')
                    ? (it.contentSw ?? it.contentEn ?? '')
                    : (it.contentEn ?? it.contentSw ?? '');
                final snippet = body.toLowerCase();
                return title.contains(_filter) || snippet.contains(_filter);
              }).toList(growable: false);
            }

            if (filtered.isEmpty) {
              return Column(
                children: const [
                  _FilterBar(),
                  Expanded(child: _EmptyFiltered()),
                ],
              );
            }

            return Column(
              children: [
                const _FilterBar(), // comment out to remove search bar
                Expanded(
                  child: ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final it = filtered[i];
                      final bodyText = (lang == 'sw')
                          ? (it.contentSw ?? it.contentEn ?? '')
                          : (it.contentEn ?? it.contentSw ?? '');
                      final oneLine = bodyText.replaceAll('\n', ' ');
                      final snippet = oneLine.length <= 140
                          ? oneLine
                          : '${oneLine.substring(0, 140)} …';

                      return Dismissible(
                        key: ValueKey('saved_${it.id}'),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          color: Colors.red,
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        confirmDismiss: (_) async {
                          return await showDialog<bool>(
                                context: context,
                                builder: (_) => AlertDialog(
                                  title: const Text('Remove bookmark?'),
                                  content: Text('Remove “${it.title}” from Saved?'),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context, false),
                                      child: const Text('Cancel'),
                                    ),
                                    FilledButton(
                                      onPressed: () => Navigator.pop(context, true),
                                      child: const Text('Remove'),
                                    ),
                                  ],
                                ),
                              ) ??
                              false;
                        },
                        onDismissed: (_) {
                          ref.read(bookmarksProvider.notifier).toggle(it.id);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Removed ${it.title}')),
                          );
                        },
                        child: ListTile(
                          title: Text(it.title),
                          subtitle: Text(
                            snippet,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                          onTap: () => context.go('/article/${it.id}'),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // Small inline filter bar UI (TextField)—remove if you don’t want filtering
  Widget _buildFilterField() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: TextField(
        controller: _filterCtrl,
        onChanged: _onFilterChanged,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Filter saved remedies…',
          prefixIcon: const Icon(Icons.search),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          suffixIcon: _filter.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _filterCtrl.clear();
                    _onFilterChanged('');
                  },
                ),
        ),
      ),
    );
  }
}

class _FilterBar extends ConsumerWidget {
  const _FilterBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = context.findAncestorStateOfType<_SavedScreenState>();
    if (state == null) return const SizedBox.shrink();
    return state._buildFilterField();
  }
}

class _EmptySaved extends StatelessWidget {
  const _EmptySaved();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'No saved remedies yet.\nOpen any article and tap the bookmark icon.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
    );
  }
}

class _EmptyFiltered extends StatelessWidget {
  const _EmptyFiltered();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'No saved remedies match your filter.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
    );
  }
}
