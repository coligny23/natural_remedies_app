// tools/import_sw_from_csv.dart
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;

void main(List<String> args) async {
  if (args.isEmpty) {
    stderr.writeln('Usage: dart run tools/import_sw_from_csv.dart <csv_path>');
    exit(64);
  }

  final csvPath = args.first;
  final csvFile = File(csvPath);
  if (!csvFile.existsSync()) {
    stderr.writeln('CSV not found: $csvPath');
    stderr.writeln('Tip: place it at tools/in/sw_translations.csv and run:');
    stderr.writeln('  dart run tools/import_sw_from_csv.dart tools/in/sw_translations.csv');
    exit(66);
  }

  final raw = await csvFile.readAsString();
  final lines = const LineSplitter().convert(raw);
  if (lines.isEmpty) {
    stderr.writeln('Empty CSV (no lines).');
    exit(64);
  }

  // Handle BOM on first header cell
  String headerLine = lines.first;
  if (headerLine.isNotEmpty && headerLine.codeUnitAt(0) == 0xFEFF) {
    headerLine = headerLine.substring(1);
  }

  final delimiter = _detectDelimiter(headerLine);
  final header = _parseCsvLine(headerLine, delimiter);
  final lower = header.map((h) => h.trim().toLowerCase()).toList();

  final idxId = lower.indexOf('id');
  // accept contentSw or contentsw (case-insensitive)
  final idxContent = lower.indexOf('contentsw');
  final idxTitle = lower.indexOf('titlesw'); // optional

  if (idxId == -1 || idxContent == -1) {
    stderr.writeln('CSV must include columns: id, contentSw (optional: titleSw)');
    stderr.writeln('Found columns: ${header.join(' | ')}');
    exit(64);
  }

  final out = <Map<String, dynamic>>[];
  var parsedRows = 0, written = 0, skipped = 0;

  for (var i = 1; i < lines.length; i++) {
    final line = lines[i];
    if (line.trim().isEmpty) { skipped++; continue; }
    final row = _parseCsvLine(line, delimiter);
    parsedRows++;

    String get(int idx) => (idx >= 0 && idx < row.length) ? row[idx] : '';
    final id = get(idxId).trim();
    final contentSw = get(idxContent).trim();
    final titleSw = idxTitle >= 0 ? get(idxTitle).trim() : '';

    if (id.isEmpty || contentSw.isEmpty) { skipped++; continue; }

    out.add({
      'id': id,
      'title': titleSw.isNotEmpty ? titleSw : id, // keep id as title if no titleSw yet
      'contentSw': contentSw,
    });
    written++;
  }

  final base = Directory.current.path;
  final outDir = Directory(p.join(base, 'assets', 'corpus', 'sw'))..createSync(recursive: true);
  final outFile = File(p.join(outDir.path, 'sw_import.json'));
  await outFile.writeAsString(const JsonEncoder.withIndent('  ').convert(out));

  stdout.writeln('CSV delimiter: ${_nameDelimiter(delimiter)}');
  stdout.writeln('Header columns: ${header.join(' | ')}');
  stdout.writeln('Parsed rows: $parsedRows, written: $written, skipped: $skipped');
  stdout.writeln('Wrote ${out.length} items → ${outFile.path}');
}

String _nameDelimiter(String d) {
  if (d == ',') return 'comma';
  if (d == ';') return 'semicolon';
  if (d == '\t') return 'tab';
  return 'unknown';
}

String _detectDelimiter(String headerLine) {
  // Simple heuristic: choose the delimiter with most occurrences
  final counts = {
    ',': _count(headerLine, ','),
    ';': _count(headerLine, ';'),
    '\t': _count(headerLine, '\t'),
  };
  var best = ',';
  var bestCount = -1;
  counts.forEach((delim, c) {
    if (c > bestCount) { best = delim; bestCount = c; }
  });
  return best;
}

int _count(String s, String sub) {
  var c = 0, i = 0;
  while (true) {
    final j = s.indexOf(sub, i);
    if (j < 0) break;
    c++; i = j + sub.length;
  }
  return c;
}

List<String> _parseCsvLine(String line, String delimiter) {
  final out = <String>[];
  final sb = StringBuffer();
  var inQuotes = false;

  for (var i = 0; i < line.length; i++) {
    final ch = line[i];
    if (ch == '"') {
      if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
        sb.write('"'); i++; // escaped quote
      } else {
        inQuotes = !inQuotes;
      }
    } else if (ch == delimiter && !inQuotes) {
      out.add(sb.toString()); sb.clear();
    } else {
      sb.write(ch);
    }
  }
  out.add(sb.toString());
  return out;
}
