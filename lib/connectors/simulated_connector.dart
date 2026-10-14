import 'dart:async';
import '../models.dart';
import '../simulator.dart';
import 'connector_interface.dart';

class SimulatedConfig extends ConnectorConfig {
  const SimulatedConfig({
    int intervalMs = 500,
  })  : intervalMs = intervalMs,
        super(id: 'simulated_source', name: 'Internal Simulator', readOnly: true);

  final int intervalMs;

  @override
  Map<String, dynamic> toJson() => {'intervalMs': intervalMs};
}

class SimulatedConnector implements IndustrialConnector {
  final Simulator _sim = Simulator();
  final _statusController = StreamController<ConnectionStatus>.broadcast();
  final _telemetryController = StreamController<IndustrialTelemetry>.broadcast();

  Timer? _timer;
  ConnectionStatus _status = ConnectionStatus.disconnected;

  @override
  String get id => 'simulated_source';

  @override
  String get name => 'Internal Simulator';

  @override
  ConnectionStatus get status => _status;

  @override
  Stream<ConnectionStatus> get statusStream => _statusController.stream;

  @override
  Stream<IndustrialTelemetry> get telemetryStream => _telemetryController.stream;

  Simulator get simulator => _sim;

  @override
  Future<void> connect(ConnectorConfig config) async {
    final simConfig = config is SimulatedConfig ? config : const SimulatedConfig();
    _setStatus(ConnectionStatus.connecting);
    await Future.delayed(const Duration(milliseconds: 50));

    _timer?.cancel();
    _setStatus(ConnectionStatus.connected);

    _timer = Timer.periodic(Duration(milliseconds: simConfig.intervalMs), (_) {
      final t = _sim.next();
      _telemetryController.add(
        IndustrialTelemetry(
          telemetry: t,
          quality: DataQuality.good,
          sourceId: id,
        ),
      );
    });
  }

  @override
  Future<void> disconnect() async {
    _timer?.cancel();
    _setStatus(ConnectionStatus.disconnected);
  }

  void _setStatus(ConnectionStatus s) {
    _status = s;
    _statusController.add(s);
  }
}
