import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:gridsentinel/models.dart';
import 'package:gridsentinel/services/import_service.dart';

String _csv({
  int count = 30,
  String headers =
      'timestamp,pressure_kpa,motor_rpm,temperature_c,flow_lpm',
  String Function(int index)? rowBuilder,
}) {
  final rows = <String>[headers];
  for (var i = 0; i < count; i++) {
    rows.add(rowBuilder?.call(i) ??
        '2026-10-12T10:00:${i.toString().padLeft(2, '0')}Z,'
        '220.1,1480,41.2,75.4');
  }
  return rows.join('\n');
}

void main() {
  group('ImportService validation', () {
    test('parses a CSV with at least 30 valid records', () {
      final result = ImportService.parseCsv(_csv(), 'valid.csv');

      expect(result.ok, isTrue);
      expect(result.rows.length, 30);
      expect(result.rows.first, isA<Telemetry>());
      expect(result.rows.first.v[0], 220.1);
      expect(result.name, 'valid.csv');
    });

    test('rejects an empty CSV', () {
      final result = ImportService.parseCsv('', 'empty.csv');

      expect(result.ok, isFalse);
      expect(result.message, contains('no data rows'));
    });

    test('rejects missing required headers', () {
      final result = ImportService.parseCsv(
        _csv(
          headers: 'timestamp,pressure_kpa,motor_rpm',
        ),
        'missing-columns.csv',
      );

      expect(result.ok, isFalse);
      expect(result.message, contains('Missing column'));
    });

    test('skips rows containing non-numeric sensor readings', () {
      final result = ImportService.parseCsv(
        _csv(
          count: 31,
          rowBuilder: (i) => i == 0
              ? '2026-10-12T10:00:00Z,abc,1480,41.2,75.4'
              : '2026-10-12T10:00:${i.toString().padLeft(2, '0')}Z,'
                  '220.1,1480,41.2,75.4',
        ),
        'bad-reading.csv',
      );

      expect(result.ok, isTrue);
      expect(result.rows.length, 30);
      expect(result.name, contains('bad rows skipped'));
    });

    test('rejects data with fewer than 30 valid rows', () {
      final result = ImportService.parseCsv(
        _csv(count: 2),
        'too-short.csv',
      );

      expect(result.ok, isFalse);
      expect(result.message, contains('at least 30 valid rows'));
    });

    test('uses fallback timestamps for invalid timestamp text', () {
      final result = ImportService.parseCsv(
        _csv(
          rowBuilder: (i) => '${i == 0 ? 'not-a-date' : '2026-10-12T10:00:${i.toString().padLeft(2, '0')}Z'},'
              '220.1,1480,41.2,75.4',
        ),
        'timestamps.csv',
      );

      expect(result.ok, isTrue);
      expect(result.rows.first.time, isA<DateTime>());
    });

    test('parses JSON records', () {
      final records = List.generate(
        30,
        (i) => {
          'timestamp': '2026-10-12T10:00:${i.toString().padLeft(2, '0')}Z',
          'pressure_kpa': 220.1,
          'motor_rpm': 1480,
          'temperature_c': 41.2,
          'flow_lpm': 75.4,
        },
      );

      final result = ImportService.parseJson(
        jsonEncode(records),
        'records.json',
      );

      // The JSON parser must accept a valid JSON list of sensor records.
      expect(result.ok, isTrue);
      expect(result.rows.length, 30);
    });
  });
}


