// tools/export_corpus.dart
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;

void main() async {
  final base = Directory.current.path; // project root when run from repo
  final enDir = Directory(p.join(base, 'assets', 'corpus', 'en'));

  if (!enDir.existsSync()) {
    stderr.writeln('EN corpus not found at ${enDir.path}');
    exit(1);
  }

  final outDir = Directory(p.join(base, 'tools', 'out'))..createSync(recursive: true);
  final outFile = File(p.join(outDir.path, 'en_corpus.csv'));

  final headers = ['id', 'title', 'contentEn'];
  final sink = outFile.openWrite();
  sink.writeln(headers.map(_csvEscape).join(','));

  final files = enDir
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.json') && !f.path.endsWith('synonyms.json'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  var count = 0;
  for (final f in files) {
    final raw = await f.readAsString();
    final arr = json.decode(raw) as List<dynamic>;
    for (final o in arr) {
      final m = (o as Map).cast<String, dynamic>();
      final id = (m['id'] ?? '').toString();
      final title = (m['title'] ?? '').toString();
      final contentEn = (m['contentEn'] ?? '').toString();
      if (id.isEmpty) continue;
      sink.writeln([
        _csvEscape(id),
        _csvEscape(title),
        _csvEscape(contentEn),
      ].join(','));
      count++;
    }
  }

  await sink.flush();
  await sink.close();
  stdout.writeln('Wrote ${count} rows → ${outFile.path}');
}

String _csvEscape(String s) {
  var t = s.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  final needsQuotes = t.contains(',') || t.contains('"') || t.contains('\n');
  t = t.replaceAll('"', '""');
  return needsQuotes ? '"$t"' : t;
}
