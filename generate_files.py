import os

os.makedirs("lib/services", exist_ok=True)
os.makedirs("lib/screens", exist_ok=True)

import_service_code = """import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import 'package:flutter/services.dart' show rootBundle;

class ImportService {
  static const expectedHeaders = ['timestamp', 'pressure_kpa', 'motor_rpm', 'temperature_c', 'flow_lpm'];

  static Future<Map<String, dynamic>> pickAndParseCsv() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      if (result == null || result.files.single.path == null) {
        return {'success': false, 'error': 'No file selected.'};
      }

      final file = File(result.files.single.path!);
      final csvString = await file.readAsString();
      return _processCsv(csvString);
    } catch (e) {
      return {'success': false, 'error': 'Error reading file: $e'};
    }
  }

  static Future<Map<String, dynamic>> loadSampleCsv() async {
    try {
      final csvString = await rootBundle.loadString('assets/samples/sample_telemetry.csv');
      return _processCsv(csvString);
    } catch (e) {
      return {'success': false, 'error': 'Failed to load sample asset: $e'};
    }
  }

  static Map<String, dynamic> _processCsv(String csvString) {
    List<List<dynamic>> rows = const CsvToListConverter().convert(csvString);
    if (rows.isEmpty) return {'success': false, 'error': 'File is empty'};

    final headers = rows.first.map((e) => e.toString().trim().toLowerCase()).toList();
    for (var expected in expectedHeaders) {
      if (!headers.contains(expected)) {
        return {'success': false, 'error': 'Validation failed. Missing column: $expected'};
      }
    }

    final dataRows = rows.skip(1).toList();
    if (dataRows.isEmpty) return {'success': false, 'error': 'No data rows found.'};

    return {
      'success': true,
      'headers': headers,
      'data': dataRows,
      'total_rows': dataRows.length,
    };
  }
}
"""

with open("lib/services/import_service.dart", "w", encoding="utf-8") as f:
    f.write(import_service_code)

import_screen_code = """import 'package:flutter/material.dart';
import '../services/import_service.dart';

class ImportScreen extends StatefulWidget {
  const ImportScreen({super.key});

  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen> {
  String _status = 'Select a CSV file or load the sample to validate telemetry data.';
  List<String> _headers = [];
  List<List<dynamic>> _previewData = [];
  bool _isLoading = false;

  void _handleImportResult(Map<String, dynamic> result) {
    setState(() {
      _isLoading = false;
      if (result['success']) {
        _status = 'Validation passed! Loaded ${result['total_rows']} records ready for analysis.';
        _headers = List<String>.from(result['headers']);
        _previewData = List<List<dynamic>>.from(result['data'].take(5));
      } else {
        _status = 'Error: ${result['error']}';
        _headers = [];
        _previewData = [];
      }
    });
  }

  Future<void> _pickFile() async {
    setState(() => _isLoading = true);
    final result = await ImportService.pickAndParseCsv();
    _handleImportResult(result);
  }

  Future<void> _loadSample() async {
    setState(() => _isLoading = true);
    final result = await ImportService.loadSampleCsv();
    _handleImportResult(result);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Import Telemetry'), backgroundColor: const Color(0xFF15151E)),
      backgroundColor: const Color(0xFF0D0D12),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.file_open),
                  label: const Text('Pick CSV'),
                  onPressed: _isLoading ? null : _pickFile,
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.science),
                  label: const Text('Load Sample'),
                  onPressed: _isLoading ? null : _loadSample,
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              _status, 
              style: TextStyle(
                color: _status.contains('Error') ? Colors.redAccent : Colors.greenAccent,
                fontSize: 15
              )
            ),
            const SizedBox(height: 24),
            if (_previewData.isNotEmpty) ...[
              const Text('Data Preview', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
              const SizedBox(height: 12),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(Colors.grey[900]),
                      columns: _headers.map((h) => DataColumn(label: Text(h, style: const TextStyle(color: Colors.cyanAccent)))).toList(),
                      rows: _previewData.map((row) {
                        return DataRow(cells: row.map((cell) => DataCell(Text(cell.toString(), style: const TextStyle(color: Colors.white70)))).toList());
                      }).toList(),
                    ),
                  ),
                ),
              )
            ]
          ],
        ),
      ),
    );
  }
}
"""

with open("lib/screens/import_screen.dart", "w", encoding="utf-8") as f:
    f.write(import_screen_code)

print("Files generated cleanly via Python!")
