import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import '../models.dart';
import 'connector_interface.dart';

enum ModbusRegisterType {
  holding, // Function Code 0x03
  input,   // Function Code 0x04
}

enum ModbusDataType {
  uint16,  // 4 registers = 4 channels directly
  float32, // 8 registers = 4 IEEE 754 single-precision floats (2 registers per channel)
}

class ModbusConfig extends ConnectorConfig {
  const ModbusConfig({
    required String id,
    required String name,
    required this.host,
    this.port = 502,
    this.slaveId = 1,
    this.startRegister = 0,
    this.registerType = ModbusRegisterType.holding,
    this.dataType = ModbusDataType.uint16,
    this.pollIntervalMs = 500,
  }) : super(id: id, name: name, readOnly: true);

  final String host;
  final int port;
  final int slaveId;
  final int startRegister;
  final ModbusRegisterType registerType;
  final ModbusDataType dataType;
  final int pollIntervalMs;

  @override
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'host': host,
        'port': port,
        'slaveId': slaveId,
        'startRegister': startRegister,
        'registerType': registerType.name,
        'dataType': dataType.name,
        'pollIntervalMs': pollIntervalMs,
      };
}

class ModbusTcpConnector implements IndustrialConnector {
  Socket? _socket;
  Timer? _pollTimer;
  int _transactionId = 0;

  final _statusController = StreamController<ConnectionStatus>.broadcast();
  final _telemetryController = StreamController<IndustrialTelemetry>.broadcast();

  ConnectionStatus _status = ConnectionStatus.disconnected;
  ModbusConfig? _config;

  @override
  String get id => _config?.id ?? 'modbus_source';

  @override
  String get name => _config?.name ?? 'Modbus TCP Device';

  @override
  ConnectionStatus get status => _status;

  @override
  Stream<ConnectionStatus> get statusStream => _statusController.stream;

  @override
  Stream<IndustrialTelemetry> get telemetryStream => _telemetryController.stream;

  @override
  Future<void> connect(ConnectorConfig config) async {
    _config = config as ModbusConfig;
    _setStatus(ConnectionStatus.connecting);

    try {
      _socket = await Socket.connect(_config!.host, _config!.port, timeout: const Duration(seconds: 5));
      _setStatus(ConnectionStatus.connected);

      final count = _config!.dataType == ModbusDataType.float32 ? 8 : 4;

      _pollTimer?.cancel();
      _pollTimer = Timer.periodic(Duration(milliseconds: _config!.pollIntervalMs), (_) {
        _pollRegisters(count);
      });
    } catch (_) {
      _setStatus(ConnectionStatus.error);
      await disconnect();
    }
  }

  Future<void> _pollRegisters(int count) async {
    if (_socket == null || _status != ConnectionStatus.connected) return;

    _transactionId = (_transactionId + 1) & 0xFFFF;
    final fc = _config!.registerType == ModbusRegisterType.holding ? 0x03 : 0x04;

    // Build MBAP Header (7 bytes) + PDU (5 bytes)
    final frame = Uint8List(12);
    final bd = ByteData.view(frame.buffer);

    bd.setUint16(0, _transactionId);                   // Transaction ID
    bd.setUint16(2, 0x0000);                            // Protocol ID (Modbus = 0)
    bd.setUint16(4, 6);                                 // Length (6 bytes follow)
    bd.setUint8(6, _config!.slaveId);                   // Unit/Slave ID
    bd.setUint8(7, fc);                                 // Function Code
    bd.setUint16(8, _config!.startRegister);           // Starting Address
    bd.setUint16(10, count);                            // Quantity of Registers

    try {
      _socket!.add(frame);
      final rawData = await _socket!.first.timeout(const Duration(seconds: 2));

      if (rawData.length < 9) {
        _emitBad('Incomplete MBAP header received');
        return;
      }

      final resBd = ByteData.view(Uint8List.fromList(rawData).buffer);
      final byteCount = resBd.getUint8(8);

      if (rawData.length < 9 + byteCount) {
        _emitBad('Truncated response payload');
        return;
      }

      final values = <double>[];
      if (_config!.dataType == ModbusDataType.uint16) {
        for (var i = 0; i < 4; i++) {
          values.add(resBd.getUint16(9 + (i * 2)).toDouble());
        }
      } else {
        for (var i = 0; i < 4; i++) {
          values.add(resBd.getFloat32(9 + (i * 4)));
        }
      }

      _telemetryController.add(
        IndustrialTelemetry(
          telemetry: Telemetry(DateTime.now(), values),
          quality: DataQuality.good,
          sourceId: id,
        ),
      );
    } catch (_) {
      _emitBad('Modbus TCP read timeout or connection drop');
    }
  }

  void _emitBad(String msg) {
    _telemetryController.add(
      IndustrialTelemetry(
        telemetry: Telemetry(DateTime.now(), const [0.0, 0.0, 0.0, 0.0]),
        quality: DataQuality.bad,
        sourceId: id,
        statusMessage: msg,
      ),
    );
  }

  @override
  Future<void> disconnect() async {
    _pollTimer?.cancel();
    await _socket?.close();
    _socket = null;
    _setStatus(ConnectionStatus.disconnected);
  }

  void _setStatus(ConnectionStatus s) {
    _status = s;
    _statusController.add(s);
  }
}
