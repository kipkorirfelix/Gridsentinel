import 'dart:async';
import 'dart:convert';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import '../models.dart';
import 'connector_interface.dart';

class MqttConfig extends ConnectorConfig {
  const MqttConfig({
    required String id,
    required String name,
    required this.host,
    required this.port,
    required this.topic,
    this.username,
    this.password,
    this.useTls = false,
  }) : super(id: id, name: name, readOnly: true);

  final String host;
  final int port;
  final String topic;
  final String? username;
  final String? password;
  final bool useTls;

  @override
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'host': host,
        'port': port,
        'topic': topic,
        'useTls': useTls,
      };
}

class MqttConnector implements IndustrialConnector {
  MqttServerClient? _client;
  final _statusController = StreamController<ConnectionStatus>.broadcast();
  final _telemetryController = StreamController<IndustrialTelemetry>.broadcast();

  ConnectionStatus _status = ConnectionStatus.disconnected;
  MqttConfig? _config;

  @override
  String get id => _config?.id ?? 'mqtt_source';

  @override
  String get name => _config?.name ?? 'MQTT Broker';

  @override
  ConnectionStatus get status => _status;

  @override
  Stream<ConnectionStatus> get statusStream => _statusController.stream;

  @override
  Stream<IndustrialTelemetry> get telemetryStream => _telemetryController.stream;

  @override
  Future<void> connect(ConnectorConfig config) async {
    _config = config as MqttConfig;
    _setStatus(ConnectionStatus.connecting);

    final clientIdentifier = 'gridsentinel_${DateTime.now().millisecondsSinceEpoch}';
    _client = MqttServerClient.withPort(_config!.host, clientIdentifier, _config!.port);
    _client!.secure = _config!.useTls;
    _client!.keepAlivePeriod = 20;

    final connMessage = MqttConnectMessage()
        .withClientIdentifier(clientIdentifier)
        .startClean();

    if (_config!.username != null && _config!.password != null) {
      connMessage.authenticateAs(_config!.username, _config!.password);
    }

    _client!.connectionMessage = connMessage;

    try {
      await _client!.connect();
      if (_client!.connectionStatus?.state == MqttConnectionState.connected) {
        _setStatus(ConnectionStatus.connected);
        _client!.subscribe(_config!.topic, MqttQos.atLeastOnce);
        _listenToUpdates();
      } else {
        _setStatus(ConnectionStatus.error);
        await disconnect();
      }
    } catch (_) {
      _setStatus(ConnectionStatus.error);
      await disconnect();
    }
  }

  void _listenToUpdates() {
    _client!.updates?.listen((List<MqttReceivedMessage<MqttMessage>> c) {
      final recMess = c[0].payload as MqttPublishMessage;
      final payload = MqttPublishPayload.bytesToStringAsString(recMess.payload.message);

      try {
        final Map<String, dynamic> data = jsonDecode(payload);
        final double pressure = (data['pressure_kpa'] ?? data['pressure'] ?? 0.0).toDouble();
        final double rpm = (data['motor_rpm'] ?? data['rpm'] ?? 0.0).toDouble();
        final double temp = (data['temperature_c'] ?? data['temp'] ?? 0.0).toDouble();
        final double flow = (data['flow_lpm'] ?? data['flow'] ?? 0.0).toDouble();

        final telemetry = Telemetry(DateTime.now(), [pressure, rpm, temp, flow]);

        _telemetryController.add(
          IndustrialTelemetry(
            telemetry: telemetry,
            quality: DataQuality.good,
            sourceId: id,
          ),
        );
      } catch (_) {
        _telemetryController.add(
          IndustrialTelemetry(
            telemetry: Telemetry(DateTime.now(), const [0.0, 0.0, 0.0, 0.0]),
            quality: DataQuality.bad,
            sourceId: id,
            statusMessage: 'Malformed payload received',
          ),
        );
      }
    });
  }

  @override
  Future<void> disconnect() async {
    _client?.disconnect();
    _setStatus(ConnectionStatus.disconnected);
  }

  void _setStatus(ConnectionStatus s) {
    _status = s;
    _statusController.add(s);
  }
}
