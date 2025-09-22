import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'content_renderer.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;

import '../../search/search_providers.dart'; // languageCodeProvider, contentListProvider
import '../data/content_lookup_provider.dart'; // contentByIdProvider(id)
import '../../saved/bookmarks_controller.dart'; // bookmarksProvider

class ContentDetailScreen extends ConsumerStatefulWidget {
  final String id;
  const ContentDetailScreen({super.key, required this.id});

  @override
  ConsumerState<ContentDetailScreen> createState() =>
      _ContentDetailScreenState();
}

class _ContentDetailScreenState extends ConsumerState<ContentDetailScreen> {
  @override
  void initState() {
    super.initState();
    // Track "continue learning" & recency
    final box = Hive.box('reading_progress');
    final now = DateTime.now();
    box
      ..put('last_id', widget.id)
      ..put('last_opened_at', now)
      ..put('time_${widget.id}', now);
  }

  @override
  Widget build(BuildContext context) {
    // Wait for content to load once
    final itemsAsync = ref.watch(contentListProvider);
    final lang = ref.watch(languageCodeProvider);

    return itemsAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
      data: (_) {
        final item = ref.watch(contentByIdProvider(widget.id));
        if (item == null) {
          return const Scaffold(body: Center(child: Text('Not found')));
        }

        final body = (lang == 'sw')
            ? (item.contentSw ?? item.contentEn ?? '')
            : (item.contentEn ?? item.contentSw ?? '');
        final isSaved = ref.watch(bookmarksProvider).contains(item.id);

        return Scaffold(
          appBar: AppBar(
            title: Text(item.title),
            actions: [
              IconButton(
                tooltip: isSaved ? 'Remove bookmark' : 'Add bookmark',
                icon: Icon(isSaved ? Icons.bookmark : Icons.bookmark_border),
                onPressed: () {
                  ref.read(bookmarksProvider.notifier).toggle(item.id);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                          isSaved ? 'Removed from Saved' : 'Saved for later'),
                      behavior: SnackBarBehavior.floating,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
              ),
              IconButton(
                tooltip: 'Copy',
                icon: const Icon(Icons.copy),
                onPressed: () async {
                  await Clipboard.setData(
                      ClipboardData(text: '${item.title}\n\n$body'));
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Copied to clipboard')),
                  );
                },
              ),
              IconButton(
                tooltip: 'Share',
                icon: const Icon(Icons.ios_share),
                onPressed: () {
                  SharePlus.instance.share(ShareParams(
                    text: '${item.title}\n\n$body',
                    subject: item.title,
                  ));
                },
              ),
            ],
          ),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SelectionArea(
                  child: ArticleBody(
                    rawText: body,
                    onTapLink: (id) {
                      // Navigate to linked article id
                      Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => ContentDetailScreen(id: id)),
                      );
                      // If you use GoRouter:
                      // context.go('/article/$id');
                    },
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
