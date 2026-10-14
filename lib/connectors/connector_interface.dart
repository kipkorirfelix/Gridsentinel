import 'dart:async';
import '../models.dart';

enum ConnectionStatus {
  disconnected,
  connecting,
  connected,
  reconnecting,
  error,
}

enum DataQuality {
  good,
  uncertain,
  bad,
}

class IndustrialTelemetry {
  const IndustrialTelemetry({
    required this.telemetry,
    required this.quality,
    required this.sourceId,
    this.statusMessage,
  });

  final Telemetry telemetry;
  final DataQuality quality;
  final String sourceId;
  final String? statusMessage;
}

abstract class ConnectorConfig {
  const ConnectorConfig({
    required this.id,
    required this.name,
    this.readOnly = true,
  });

  final String id;
  final String name;
  final bool readOnly;

  Map<String, dynamic> toJson();
}

abstract class IndustrialConnector {
  String get id;
  String get name;
  ConnectionStatus get status;
  Stream<ConnectionStatus> get statusStream;
  Stream<IndustrialTelemetry> get telemetryStream;

  Future<void> connect(ConnectorConfig config);
  Future<void> disconnect();
}
