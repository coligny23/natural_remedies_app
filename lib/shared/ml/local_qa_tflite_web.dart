// lib/shared/ml/local_qa_tflite_web.dart
import 'local_qa_engine.dart';
import 'local_qa_stub.dart';
import '../../features/content/models/content_item.dart';

/// Web build cannot use tflite_flutter; this class exists so imports compile.
/// It simply delegates to the stub.
class LocalQaTflite implements LocalQaEngine {
  final LocalQaStub _stub = LocalQaStub();

  @override
  Future<void> init({
    required List<ContentItem> corpus,
    required String lang,
  }) =>
      _stub.init(corpus: corpus, lang: lang);

  @override
  Future<QaAnswer> answer(
    String query, {
    List<ContentItem>? shortlist, // <-- new optional param
  }) =>
      _stub.answer(query, shortlist: shortlist); // <-- pass through
}
