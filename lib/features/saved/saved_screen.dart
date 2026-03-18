// lib/features/saved/saved_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_strings.dart';
import '../content/models/content_item.dart';
import '../content/data/content_lookup_provider.dart';
import '../search/search_providers.dart';
import 'bookmarks_controller.dart';

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
    final t = AppStrings.of(context);
    final bookmarks = ref.watch(bookmarksProvider);
    final itemsAsync = ref.watch(contentListProvider);
    final lang = ref.watch(languageCodeProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(t.savedRemedies),
      ),
      body: AppBackground(
        child: itemsAsync.when(
          loading: () => Center(
            child: Text(t.loading),
          ),
          error: (e, _) => Center(
            child: Text('${t.errorOccurred}: $e'),
          ),
          data: (_) {
            if (bookmarks.isEmpty) {
              return const _EmptySaved();
            }

            final savedItems = <ContentItem>[];
            for (final id in bookmarks) {
              final it = ref.watch(contentByIdProvider(id));
              if (it != null) savedItems.add(it);
            }

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
                const _FilterBar(),
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
                                  title: Text(t.removeBookmarkTitle),
                                  content:
                                      Text(t.removeFromSavedMessage(it.title)),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, false),
                                      child: Text(t.cancel),
                                    ),
                                    FilledButton(
                                      onPressed: () =>
                                          Navigator.pop(context, true),
                                      child: Text(t.remove),
                                    ),
                                  ],
                                ),
                              ) ??
                              false;
                        },
                        onDismissed: (_) {
                          ref.read(bookmarksProvider.notifier).toggle(it.id);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(t.removedItem(it.title)),
                            ),
                          );
                        },
                        child: ListTile(
                          title: Text(it.title),
                          subtitle: Text(
                            snippet,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing:
                              const Icon(Icons.arrow_forward_ios, size: 16),
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

  Widget _buildFilterField() {
    final t = AppStrings.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: TextField(
        controller: _filterCtrl,
        onChanged: _onFilterChanged,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: t.filterSavedRemedies,
          prefixIcon: Icon(
            Icons.search,
            semanticLabel: t.search,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          suffixIcon: _filter.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.clear),
                  tooltip: t.clear,
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
    final t = AppStrings.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          t.noSavedRemediesYet,
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
    final t = AppStrings.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          t.noSavedRemediesMatchFilter,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
    );
  }
}