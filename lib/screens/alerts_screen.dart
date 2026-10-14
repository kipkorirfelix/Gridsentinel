import 'package:flutter/material.dart';
import '../app_state.dart';
import '../models.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  String _searchQuery = '';
  String _selectedSeverity = 'ALL';

  List<AlertRecord> _filterAlerts(List<AlertRecord> alerts) {
    return alerts.where((a) {
      final matchesSearch = _searchQuery.isEmpty ||
          a.source.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          a.channel.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          a.severity.toLowerCase().contains(_searchQuery.toLowerCase());

      final matchesSeverity = _selectedSeverity == 'ALL' ||
          a.severity.toUpperCase() == _selectedSeverity;

      return matchesSearch && matchesSeverity;
    }).toList();
  }

  Color _severityColor(String severity) {
    switch (severity.toUpperCase()) {
      case 'CRITICAL':
        return Colors.red;
      case 'WARNING':
        return Colors.orange;
      case 'INFO':
      default:
        return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: appState,
      builder: (context, _) {
        final filtered = _filterAlerts(appState.alerts);

        return Scaffold(
          appBar: AppBar(
            title: const Text('Historical Alert Logs'),
            actions: [
              IconButton(
                icon: const Icon(Icons.file_download),
                tooltip: 'Export CSV',
                onPressed: appState.alerts.isEmpty
                    ? null
                    : () async {
                        final path = await appState.exportAlerts();
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Exported CSV to $path')),
                        );
                      },
              ),
              IconButton(
                icon: const Icon(Icons.code),
                tooltip: 'Export JSON',
                onPressed: appState.alerts.isEmpty
                    ? null
                    : () async {
                        final path = await appState.exportAlertsJson();
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Exported JSON to $path')),
                        );
                      },
              ),
              IconButton(
                icon: const Icon(Icons.delete_sweep),
                tooltip: 'Clear All Alerts',
                onPressed: appState.alerts.isEmpty
                    ? null
                    : () async {
                        await appState.clearAlerts();
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Cleared alert logs.')),
                        );
                      },
              ),
            ],
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        decoration: const InputDecoration(
                          hintText: 'Search channel, source, or severity...',
                          prefixIcon: Icon(Icons.search),
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        onChanged: (v) => setState(() => _searchQuery = v),
                      ),
                    ),
                    const SizedBox(width: 12),
                    DropdownButton<String>(
                      value: _selectedSeverity,
                      items: const [
                        DropdownMenuItem(value: 'ALL', child: Text('All Severities')),
                        DropdownMenuItem(value: 'CRITICAL', child: Text('Critical')),
                        DropdownMenuItem(value: 'WARNING', child: Text('Warning')),
                        DropdownMenuItem(value: 'INFO', child: Text('Info')),
                      ],
                      onChanged: (v) {
                        if (v != null) setState(() => _selectedSeverity = v);
                      },
                    ),
                  ],
                ),
              ),
              Expanded(
                child: filtered.isEmpty
                    ? const Center(
                        child: Text('No matching alert logs found.'),
                      )
                    : ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (context, i) {
                          final alert = filtered[i];
                          final color = _severityColor(alert.severity);

                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: color.withOpacity(0.2),
                                child: Icon(Icons.warning, color: color, size: 20),
                              ),
                              title: Text(
                                '${alert.source} · Channel ${alert.channel}',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Text(
                                'Score: ${alert.score.toStringAsFixed(2)} | Time: ${alert.time.toLocal().toString().split('.').first}',
                              ),
                              trailing: Chip(
                                label: Text(
                                  alert.severity.toUpperCase(),
                                  style: TextStyle(
                                    color: color,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                backgroundColor: color.withOpacity(0.1),
                                side: BorderSide(color: color),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
