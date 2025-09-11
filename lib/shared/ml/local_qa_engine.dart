import 'package:natural_remedies_app/features/content/models/content_item.dart';

/// Result for a QA call (keep it simple but extensible)
class QaAnswer {
  final String text;                      // the answer string
  final ContentItem? source;              // the best-matching content
  final List<ContentItem> topMatches;     // optional: other candidates
  const QaAnswer({required this.text, this.source, this.topMatches = const []});
}

/// App-level contract that both the stub and future TFLite class will implement.
abstract class LocalQaEngine {
  /// Prepare the engine (load model / build index / etc.)
  Future<void> init({
    required List<ContentItem> corpus,
    required String lang, // 'en' or 'sw'
  });

  /// Get an answer for a natural-language query. Returns a best-effort result.
  Future<QaAnswer> answer(String query);
}
