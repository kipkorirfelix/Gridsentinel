import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import '../app_state.dart';
import '../services/import_service.dart';
import '../widgets/connection_badge.dart';
import '../widgets/thresholds_dialog.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  Future<void> _loadSample(BuildContext context) async {
    final result = await ImportService.loadSample();
    if (!context.mounted) return;

    if (!result.ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message)),
      );
      return;
    }

    appState.setImported(result.name, result.rows);
    appState.analyzeImported();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(
        'Loaded ${result.rows.length} telemetry rows for analysis.',
      )),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: appState,
      builder: (context, _) {
        final live = appState.live;
        final imported = appState.imported;
        final analysis = appState.analysis;

        return Scaffold(
          appBar: AppBar(
            title: const Text('GridSentinel Dashboard'),
            actions: [
              IconButton(
                icon: const Icon(Icons.settings),
                tooltip: 'Settings & Channel Rules',
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (_) => const ThresholdsDialog(),
                  );
                },
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                child: ConnectionBadge(),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Center(
                  child: Chip(
                    label: Text(appState.running ? 'LIVE' : 'PAUSED'),
                  ),
                ),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _MetricCard(
                    title: 'Live samples',
                    value: '${live.length}',
                    icon: Icons.sensors,
                  ),
                  _MetricCard(
                    title: 'SQLite Stored',
                    value: '${appState.persistedCount}',
                    icon: Icons.storage,
                  ),
                  _MetricCard(
                    title: 'EWMA Z-Score',
                    value: appState.score.toStringAsFixed(2),
                    icon: Icons.analytics,
                  ),
                  _MetricCard(
                    title: '1D-CNN Anomaly',
                    value: live.length >= 50
                        ? '${(appState.cnnScore * 100).toStringAsFixed(1)}%'
                        : 'Warming up',
                    icon: Icons.psychology,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Live pressure (kPa)',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 220,
                        child: live.length < 2
                            ? const Center(
                                child: Text('Waiting for live telemetry...'),
                              )
                            : LineChart(
                                LineChartData(
                                  gridData: const FlGridData(show: true),
                                  titlesData: const FlTitlesData(show: false),
                                  borderData: FlBorderData(show: true),
                                  lineBarsData: [
                                    LineChartBarData(
                                      spots: live.asMap().entries.map((e) {
                                        return FlSpot(
                                          e.key.toDouble(),
                                          e.value.v[0],
                                        );
                                      }).toList(),
                                      isCurved: false,
                                      dotData: const FlDotData(show: false),
                                      barWidth: 2,
                                    ),
                                  ],
                                ),
                              ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          FilledButton.icon(
                            onPressed: appState.running
                                ? appState.pauseLive
                                : appState.startLive,
                            icon: Icon(appState.running
                                ? Icons.pause
                                : Icons.play_arrow),
                            label: Text(
                                appState.running ? 'Pause live' : 'Resume live'),
                          ),
                          OutlinedButton.icon(
                            onPressed: appState.resetLive,
                            icon: const Icon(Icons.restart_alt),
                            label: const Text('Reset'),
                          ),
                          OutlinedButton.icon(
                            onPressed: appState.injectDrift,
                            icon: const Icon(Icons.trending_up),
                            label: const Text('Inject simulated drift'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        appState.latest == null
                            ? 'No live reading yet.'
                            : 'Latest reading: pressure '
                                '${appState.latest!.v[0].toStringAsFixed(2)} kPa, '
                                'motor ${appState.latest!.v[1].toStringAsFixed(1)} RPM, '
                                'temperature ${appState.latest!.v[2].toStringAsFixed(2)} °C, '
                                'flow ${appState.latest!.v[3].toStringAsFixed(2)} L/min',
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'EWMA Z-Score: ${appState.score.toStringAsFixed(2)} (Thresh: ${appState.threshold.toStringAsFixed(2)})',
                              style: const TextStyle(fontWeight: FontWeight.w500),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              '1D-CNN Probability: ${(appState.cnnScore * 100).toStringAsFixed(1)}%',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: appState.cnnScore > 0.85
                                    ? Colors.redAccent
                                    : Colors.cyanAccent,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (appState.alarm)
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Text(
                            'Anomaly Alert Active: Multi-tier threshold or physical channel bound exceeded.',
                            style: TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Imported telemetry analysis',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      Text(imported.isEmpty
                          ? 'No dataset imported yet.'
                          : '${appState.importedName}: ${imported.length} rows'),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          FilledButton.icon(
                            onPressed: () => _loadSample(context),
                            icon: const Icon(Icons.science),
                            label: const Text('Load sample dataset'),
                          ),
                          OutlinedButton.icon(
                            onPressed: imported.length >= 30
                                ? () {
                                    appState.analyzeImported();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Analysis completed.'),
                                      ),
                                    );
                                  }
                                : null,
                            icon: const Icon(Icons.analytics),
                            label: const Text('Analyze imported data'),
                          ),
                          OutlinedButton.icon(
                            onPressed: analysis == null
                                ? null
                                : () async {
                                    final count =
                                        await appState.saveFindings();
                                    if (!context.mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Saved $count anomaly episodes to local alerts.',
                                        ),
                                      ),
                                    );
                                  },
                            icon: const Icon(Icons.save),
                            label: const Text('Save findings'),
                          ),
                        ],
                      ),
                      if (analysis != null) ...[
                        const Divider(height: 24),
                        Text('Baseline rows: ${analysis.baselineCount}'),
                        Text('Flagged rows: ${analysis.anomalies.length}'),
                        Text('Anomaly episodes: ${analysis.episodes.length}'),
                        Text('Maximum score: ${analysis.maxScore.toStringAsFixed(2)}'),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'GridSentinel dual-detector engine active: statistical EWMA baseline combined with 50-step sliding window 1D-CNN neural network inference with per-channel bound triggers.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 180,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 24),
              const SizedBox(height: 10),
              Text(title),
              const SizedBox(height: 4),
              Text(
                value,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
