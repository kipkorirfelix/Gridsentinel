import 'dart:convert';
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../models.dart';

class ImportResult {
  const ImportResult.error(this.message)
      : ok = false,
        name = '',
        rows = const [];
  const ImportResult.success(this.name, this.rows)
      : ok = true,
        message = '';
  final bool ok;
  final String message;
  final String name;
  final List<Telemetry> rows;
}

class ImportService {
  static const keys = ['pressure_kpa', 'motor_rpm', 'temperature_c', 'flow_lpm'];

  static Future<ImportResult> pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'json'],
      );
      if (result == null || result.files.single.path == null) {
        return const ImportResult.error('No file selected.');
      }
      final name = result.files.single.name;
      final text = await File(result.files.single.path!).readAsString();
      return name.toLowerCase().endsWith('.json')
          ? parseJson(text, name)
          : parseCsv(text, name);
    } catch (e) {
      return ImportResult.error('Could not read file: $e');
    }
  }

  static Future<ImportResult> loadSample() async {
    try {
      final text = await rootBundle.loadString('assets/samples/sample_telemetry.csv');
      return parseCsv(text, 'sample_telemetry.csv');
    } catch (e) {
      return ImportResult.error('Could not load sample: $e');
    }
  }

  static ImportResult parseCsv(String text, String name) {
    final clean = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final rows = const CsvToListConverter(eol: '\n').convert(clean);
    if (rows.length < 2) return const ImportResult.error('CSV has no data rows.');
    final headers = rows.first.map((e) => e.toString().trim().toLowerCase()).toList();
    final recs = <Map<String, dynamic>>[];
    for (final row in rows.skip(1)) {
      if (row.isEmpty || (row.length == 1 && row.first.toString().trim().isEmpty)) continue;
      final m = <String, dynamic>{};
      for (var i = 0; i < headers.length && i < row.length; i++) {
        m[headers[i]] = row[i];
      }
      recs.add(m);
    }
    return _build(recs, name);
  }

  static ImportResult parseJson(String text, String name) {
    try {
      dynamic data = jsonDecode(text);
      if (data is Map) data = data['data'] ?? data['records'] ?? data['rows'];
      if (data is! List) {
        return const ImportResult.error('JSON must be a list of records (or an object with a data list).');
      }
      final recs = <Map<String, dynamic>>[];
      for (final item in data) {
        if (item is Map) {
          recs.add(item.map((k, v) => MapEntry(k.toString().toLowerCase(), v)));
        }
      }
      return _build(recs, name);
    } catch (e) {
      return ImportResult.error('Invalid JSON: $e');
    }
  }

  static ImportResult _build(List<Map<String, dynamic>> recs, String name) {
    if (recs.isEmpty) return const ImportResult.error('File has no data rows.');
    final missing = keys.where((k) => !recs.first.containsKey(k)).toList();
    if (missing.isNotEmpty) {
      return ImportResult.error('Missing column(s): ${missing.join(', ')}');
    }
    final base = DateTime.now();
    final out = <Telemetry>[];
    var skipped = 0;
    for (var i = 0; i < recs.length; i++) {
      final r = recs[i];
      final vals = keys.map((k) => double.tryParse('${r[k]}')).toList();
      if (vals.any((v) => v == null)) {
        skipped++;
        continue;
      }
      final ts = DateTime.tryParse('${r['timestamp']}') ?? base.add(Duration(seconds: i));
      out.add(Telemetry(ts, vals.map((v) => v!).toList()));
    }
    if (out.length < 30) {
      return ImportResult.error('Need at least 30 valid rows (found ${out.length}, skipped $skipped).');
    }
    return ImportResult.success(skipped > 0 ? '$name ($skipped bad rows skipped)' : name, out);
  }
}