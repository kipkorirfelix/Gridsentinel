import 'package:flutter/material.dart';
import '../app_state.dart';
import '../connectors/connector_interface.dart';
import '../connectors/modbus_connector.dart';
import '../connectors/mqtt_connector.dart';
import '../connectors/opc_ua_connector.dart';
import '../connectors/simulated_connector.dart';

class ConnectorDialog extends StatefulWidget {
  const ConnectorDialog({super.key});

  @override
  State<ConnectorDialog> createState() => _ConnectorDialogState();
}

class _ConnectorDialogState extends State<ConnectorDialog> {
  String _protocol = 'simulated';

  // Common fields
  final _nameController = TextEditingController(text: 'Industrial Field Source');
  final _hostController = TextEditingController(text: '127.0.0.1');

  // MQTT
  final _mqttPortController = TextEditingController(text: '1883');
  final _mqttTopicController = TextEditingController(text: 'factory/telemetry/grid1');
  final _mqttUserController = TextEditingController();
  final _mqttPassController = TextEditingController();

  // Modbus TCP
  final _modbusPortController = TextEditingController(text: '502');
  final _modbusSlaveController = TextEditingController(text: '1');
  final _modbusStartRegController = TextEditingController(text: '0');

  // OPC UA
  final _opcUaEndpointController = TextEditingController(text: 'http://127.0.0.1:4840');

  bool _isConnecting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _hostController.dispose();
    _mqttPortController.dispose();
    _mqttTopicController.dispose();
    _mqttUserController.dispose();
    _mqttPassController.dispose();
    _modbusPortController.dispose();
    _modbusSlaveController.dispose();
    _modbusStartRegController.dispose();
    _opcUaEndpointController.dispose();
    super.dispose();
  }

  Future<void> _applyConnector() async {
    setState(() => _isConnecting = true);

    try {
      if (_protocol == 'simulated') {
        await appState.switchConnector(
          SimulatedConnector(),
          SimulatedConfig(intervalMs: appState.intervalMs),
        );
      } else if (_protocol == 'mqtt') {
        final port = int.tryParse(_mqttPortController.text) ?? 1883;
        await appState.switchConnector(
          MqttConnector(),
          MqttConfig(
            id: 'mqtt_active',
            name: _nameController.text,
            host: _hostController.text,
            port: port,
            topic: _mqttTopicController.text,
            username: _mqttUserController.text.isEmpty ? null : _mqttUserController.text,
            password: _mqttPassController.text.isEmpty ? null : _mqttPassController.text,
          ),
        );
      } else if (_protocol == 'modbus') {
        final port = int.tryParse(_modbusPortController.text) ?? 502;
        final slave = int.tryParse(_modbusSlaveController.text) ?? 1;
        final start = int.tryParse(_modbusStartRegController.text) ?? 0;
        await appState.switchConnector(
          ModbusTcpConnector(),
          ModbusConfig(
            id: 'modbus_active',
            name: _nameController.text,
            host: _hostController.text,
            port: port,
            slaveId: slave,
            startRegister: start,
            pollIntervalMs: appState.intervalMs,
          ),
        );
      } else if (_protocol == 'opcua') {
        await appState.switchConnector(
          OpcUaConnector(),
          OpcUaConfig(
            id: 'opcua_active',
            name: _nameController.text,
            endpointUrl: _opcUaEndpointController.text,
            pollIntervalMs: appState.intervalMs,
          ),
        );
      }

      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to connect: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isConnecting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Connect Industrial Telemetry Source'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Read-only safety mode enabled by default.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _protocol,
              decoration: const InputDecoration(labelText: 'Protocol Driver'),
              items: const [
                DropdownMenuItem(value: 'simulated', child: Text('Simulator (Offline / Demo)')),
                DropdownMenuItem(value: 'mqtt', child: Text('MQTT Broker')),
                DropdownMenuItem(value: 'modbus', child: Text('Modbus TCP')),
                DropdownMenuItem(value: 'opcua', child: Text('OPC UA Server')),
              ],
              onChanged: (val) => setState(() => _protocol = val!),
            ),
            if (_protocol != 'simulated') ...[
              const SizedBox(height: 12),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Device Name / Label'),
              ),
              if (_protocol != 'opcua') ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _hostController,
                  decoration: const InputDecoration(labelText: 'Host / IP Address'),
                ),
              ],
            ],
            if (_protocol == 'mqtt') ...[
              const SizedBox(height: 12),
              TextField(
                controller: _mqttPortController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Port (default: 1883)'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _mqttTopicController,
                decoration: const InputDecoration(labelText: 'Telemetry Topic'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _mqttUserController,
                decoration: const InputDecoration(labelText: 'Username (optional)'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _mqttPassController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Password (optional)'),
              ),
            ],
            if (_protocol == 'modbus') ...[
              const SizedBox(height: 12),
              TextField(
                controller: _modbusPortController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Port (default: 502)'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _modbusSlaveController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Slave Unit ID (default: 1)'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _modbusStartRegController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Starting Register Address'),
              ),
            ],
            if (_protocol == 'opcua') ...[
              const SizedBox(height: 12),
              TextField(
                controller: _opcUaEndpointController,
                decoration: const InputDecoration(labelText: 'Endpoint URL (http/opc.tcp)'),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isConnecting ? null : _applyConnector,
          child: _isConnecting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Connect'),
        ),
      ],
    );
  }
}
