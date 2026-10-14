import 'dart:math';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../app_state.dart';
import '../services/database_service.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  int _queryLimit = 200;

  Future<void> _loadAndPlay(int limit) async {
    final records = await DatabaseService.instance.getRecentTelemetry(limit: limit);
    if (!mounted) return;

    if (records.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No telemetry records available in SQLite storage.')),
      );
      return;
    }

    appState.startPlayback(records, speed: appState.playbackSpeed);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Loaded ${records.length} historical frames for offline playback.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: appState,
      builder: (context, _) {
        final isPlayback = appState.isPlaybackMode;
        final isRunning = appState.isPlaybackRunning;
        final buffer = appState.playbackBuffer;
        final index = appState.playbackIndex;

        return Scaffold(
          appBar: AppBar(
            title: const Text('SQLite Offline Playback'),
            actions: [
              IconButton(
                icon: const Icon(Icons.delete_forever),
                tooltip: 'Clear SQLite Storage',
                onPressed: () async {
                  await appState.clearDatabaseHistory();
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Cleared SQLite telemetry database.')),
                  );
                },
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Database Summary',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          Chip(
                            avatar: const Icon(Icons.storage, size: 16),
                            label: Text('${appState.persistedCount} Records'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        children: [
                          ElevatedButton.icon(
                            onPressed: () => _loadAndPlay(100),
                            icon: const Icon(Icons.play_circle_outline),
                            label: const Text('Play Last 100'),
                          ),
                          ElevatedButton.icon(
                            onPressed: () => _loadAndPlay(300),
                            icon: const Icon(Icons.play_circle_fill),
                            label: const Text('Play Last 300'),
                          ),
                          ElevatedButton.icon(
                            onPressed: () => _loadAndPlay(1000),
                            icon: const Icon(Icons.history),
                            label: const Text('Play Last 1000'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (isPlayback) ...[
                Card(
                  color: Colors.blueGrey.shade900,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Offline Playback Engine',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white),
                            ),
                            DropdownButton<int>(
                              value: appState.playbackSpeed,
                              dropdownColor: Colors.blueGrey.shade800,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                              items: const [
                                DropdownMenuItem(value: 1, child: Text('1x Speed')),
                                DropdownMenuItem(value: 2, child: Text('2x Speed')),
                                DropdownMenuItem(value: 5, child: Text('5x Speed')),
                                DropdownMenuItem(value: 10, child: Text('10x Speed')),
                              ],
                              onChanged: (val) {
                                if (val != null) appState.setPlaybackSpeed(val);
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Slider(
                          value: buffer.isEmpty ? 0 : index.clamp(0, buffer.length - 1).toDouble(),
                          min: 0,
                          max: buffer.isEmpty ? 1 : (buffer.length - 1).toDouble(),
                          divisions: buffer.isEmpty ? 1 : max(1, buffer.length - 1),
                          label: '${index + 1}/${buffer.length}',
                          onChanged: (val) {
                            appState.seekPlayback(val.toInt());
                          },
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              icon: Icon(isRunning ? Icons.pause_circle : Icons.play_circle),
                              iconSize: 40,
                              color: Colors.cyanAccent,
                              onPressed: () {
                                if (isRunning) {
                                  appState.pausePlayback();
                                } else {
                                  appState.resumePlayback();
                                }
                              },
                            ),
                            const SizedBox(width: 16),
                            IconButton(
                              icon: const Icon(Icons.stop_circle),
                              iconSize: 40,
                              color: Colors.redAccent,
                              onPressed: () {
                                appState.stopPlayback();
                                appState.startLive();
                              },
                            ),
                          ],
                        ),
                        Center(
                          child: Text(
                            'Frame ${index + 1} of ${buffer.length}',
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Playback Analysis Stream',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 200,
                        child: appState.live.length < 2
                            ? const Center(child: Text('No telemetry loaded in playback buffer.'))
                            : LineChart(
                                LineChartData(
                                  gridData: const FlGridData(show: true),
                                  titlesData: const FlTitlesData(show: false),
                                  borderData: FlBorderData(show: true),
                                  lineBarsData: [
                                    LineChartBarData(
                                      spots: appState.live.asMap().entries.map((e) {
                                        return FlSpot(e.key.toDouble(), e.value.v[0]);
                                      }).toList(),
                                      isCurved: false,
                                      dotData: const FlDotData(show: false),
                                      barWidth: 2,
                                    ),
                                  ],
                                ),
                              ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'EWMA Score: ${appState.score.toStringAsFixed(2)}',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              '1D-CNN Prob: ${(appState.cnnScore * 100).toStringAsFixed(1)}%',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: appState.cnnScore > 0.85 ? Colors.redAccent : Colors.cyanAccent,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
