import 'package:flutter/material.dart';
import '../app_state.dart';
import '../connectors/connector_interface.dart';
import 'connector_dialog.dart';

class ConnectionBadge extends StatelessWidget {
  const ConnectionBadge({super.key});

  Color _statusColor(ConnectionStatus status) {
    switch (status) {
      case ConnectionStatus.connected:
        return Colors.green;
      case ConnectionStatus.connecting:
      case ConnectionStatus.reconnecting:
        return Colors.orange;
      case ConnectionStatus.error:
        return Colors.red;
      case ConnectionStatus.disconnected:
      default:
        return Colors.grey;
    }
  }

  String _statusLabel(ConnectionStatus status) {
    switch (status) {
      case ConnectionStatus.connected:
        return 'CONNECTED';
      case ConnectionStatus.connecting:
        return 'CONNECTING...';
      case ConnectionStatus.reconnecting:
        return 'RECONNECTING...';
      case ConnectionStatus.error:
        return 'ERROR';
      case ConnectionStatus.disconnected:
      default:
        return 'DISCONNECTED';
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: appState,
      builder: (context, _) {
        final connector = appState.activeConnector;
        final status = appState.connectionStatus;
        final color = _statusColor(status);

        return OutlinedButton.icon(
          onPressed: () {
            showDialog(
              context: context,
              builder: (context) => const ConnectorDialog(),
            );
          },
          icon: Icon(Icons.sensors, size: 18, color: color),
          label: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                connector.name,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: color, width: 1),
                ),
                child: Text(
                  _statusLabel(status),
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
