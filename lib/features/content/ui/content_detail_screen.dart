import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../search/search_providers.dart';
import '../../saved/bookmarks_controller.dart';
import '../data/content_lookup_provider.dart';

class ContentDetailScreen extends ConsumerStatefulWidget {
  final String id;
  const ContentDetailScreen({super.key, required this.id});

  @override
  ConsumerState<ContentDetailScreen> createState() => _ContentDetailScreenState();
}

class _ContentDetailScreenState extends ConsumerState<ContentDetailScreen> {
  @override
  void initState() {
    super.initState();
    // Track "continue learning"
    final box = Hive.box('reading_progress');
    box.put('last_id', widget.id);
    box.put('last_opened_at', DateTime.now());
  }

  @override
  Widget build(BuildContext context) {
    final itemsAsync = ref.watch(contentListProvider);
    return itemsAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
      data: (_) {
        final item = ref.watch(contentByIdProvider(widget.id));
        if (item == null) {
          return const Scaffold(body: Center(child: Text('Not found')));
        }
        final body = item.contentEn ?? item.contentSw ?? '';
        final isSaved = ref.watch(bookmarksProvider).contains(item.id);

        return Scaffold(
          appBar: AppBar(
            title: Text(item.title),
            actions: [
              IconButton(
                tooltip: isSaved ? 'Remove bookmark' : 'Add bookmark',
                icon: Icon(isSaved ? Icons.bookmark : Icons.bookmark_border),
                onPressed: () => ref.read(bookmarksProvider.notifier).toggle(item.id),
              ),
            ],
          ),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: SelectableText(body),
          ),
        );
      },
    );
  }
}
