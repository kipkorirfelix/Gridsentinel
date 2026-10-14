import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models.dart';
import '../services/import_service.dart';

class ImportScreen extends StatefulWidget {
  const ImportScreen({super.key});

  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen> {
  ImportResult? _result;
  bool _busy = false;

  Future<void> _runImport(
    Future<ImportResult> Function() action,
  ) async {
    setState(() => _busy = true);

    ImportResult result;
    try {
      result = await action();
    } catch (e) {
      result = ImportResult.error('Import failed: $e');
    }

    if (!mounted) return;
    setState(() {
      _result = result;
      _busy = false;
    });

    if (result.ok) {
      appState.setImported(result.name, result.rows);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Imported ${result.rows.length} valid rows.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;

    return Scaffold(
      appBar: AppBar(title: const Text('Import Telemetry')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Import a CSV or JSON telemetry dataset. Required sensor fields: '
            'pressure_kpa, motor_rpm, temperature_c, and flow_lpm. '
            'The importer requires at least 30 valid records.',
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              FilledButton.icon(
                onPressed: _busy
                    ? null
                    : () => _runImport(ImportService.pickFile),
                icon: const Icon(Icons.file_open),
                label: const Text('Choose CSV / JSON'),
              ),
              OutlinedButton.icon(
                onPressed: _busy
                    ? null
                    : () => _runImport(ImportService.loadSample),
                icon: const Icon(Icons.science),
                label: const Text('Load sample'),
              ),
            ],
          ),
          if (_busy) ...[
            const SizedBox(height: 20),
            const LinearProgressIndicator(),
            const SizedBox(height: 8),
            const Text('Reading and validating telemetry...'),
          ],
          if (result != null) ...[
            const SizedBox(height: 20),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      result.ok ? 'Import successful' : 'Import failed',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(result.ok
                        ? 'File: ${result.name}\nValid rows: ${result.rows.length}'
                        : result.message),
                    if (result.ok) ...[
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: () {
                          appState.analyzeImported();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Imported data analyzed.'),
                            ),
                          );
                        },
                        icon: const Icon(Icons.analytics),
                        label: const Text('Analyze imported data'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (result.ok) ...[
              const SizedBox(height: 16),
              Text('Preview (first 5 rows)',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('Timestamp')),
                    DataColumn(label: Text('Pressure')),
                    DataColumn(label: Text('Motor RPM')),
                    DataColumn(label: Text('Temp °C')),
                    DataColumn(label: Text('Flow')),
                  ],
                  rows: result.rows.take(5).map((Telemetry t) {
                    return DataRow(
                      cells: [
                        DataCell(Text(t.time.toIso8601String())),
                        DataCell(Text(t.v[0].toStringAsFixed(2))),
                        DataCell(Text(t.v[1].toStringAsFixed(2))),
                        DataCell(Text(t.v[2].toStringAsFixed(2))),
                        DataCell(Text(t.v[3].toStringAsFixed(2))),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
