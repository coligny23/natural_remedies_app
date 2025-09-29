import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

/// Simple saved QA model (Hive uses Map here to avoid adapters)
class SavedQa {
  final String id;          // q|sourceId|hash(answerText)
  final String question;
  final String answerText;
  final String? sourceId;
  final String? sourceTitle;
  final int savedAt;        // epoch ms

  SavedQa({
    required this.id,
    required this.question,
    required this.answerText,
    required this.savedAt,
    this.sourceId,
    this.sourceTitle,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'question': question,
    'answerText': answerText,
    'sourceId': sourceId,
    'sourceTitle': sourceTitle,
    'savedAt': savedAt,
  };

  static SavedQa fromMap(Map m) => SavedQa(
    id: m['id'] as String,
    question: m['question'] as String,
    answerText: m['answerText'] as String,
    sourceId: m['sourceId'] as String?,
    sourceTitle: m['sourceTitle'] as String?,
    savedAt: m['savedAt'] as int,
  );
}

const _boxName = 'saved_qa_v1';

final savedQaListProvider =
    StateNotifierProvider<SavedQaController, List<SavedQa>>((ref) {
  return SavedQaController();
});

class SavedQaController extends StateNotifier<List<SavedQa>> {
  SavedQaController() : super(const []) { _load(); }

  Future<Box> _box() async => Hive.isBoxOpen(_boxName) ? Hive.box(_boxName) : await Hive.openBox(_boxName);

  Future<void> _load() async {
    final b = await _box();
    final vals = b.values.cast<Map>().map(SavedQa.fromMap).toList();
    // newest first
    vals.sort((a,b) => b.savedAt.compareTo(a.savedAt));
    state = vals;
  }

  Future<void> save({
    required String question,
    required String answerText,
    String? sourceId,
    String? sourceTitle,
  }) async {
    if (answerText.trim().isEmpty) return;
    final ts = DateTime.now().millisecondsSinceEpoch;
    final key = _stableId(question, sourceId, answerText);
    final entry = SavedQa(
      id: key,
      question: question.trim(),
      answerText: answerText.trim(),
      sourceId: sourceId,
      sourceTitle: sourceTitle,
      savedAt: ts,
    );
    final b = await _box();
    await b.put(key, entry.toMap());
    await _load();
  }

  Future<void> remove(String id) async {
    final b = await _box();
    await b.delete(id);
    await _load();
  }

  Future<void> clear() async {
    final b = await _box();
    await b.clear();
    state = const [];
  }

  String _stableId(String q, String? src, String ans) {
    // small stable key (avoid crypto dep): truncate + combine lengths
    final base = '${q.trim()}|${src ?? ""}|${ans.trim()}';
    final s = base.length;
    final head = base.substring(0, s > 64 ? 64 : s);
    return '${head.hashCode}_$s';
  }
}
