class TelemetrySample {
  final DateTime timestamp;
  final double pressureKpa;
  final double motorRpm;
  final double temperatureC;
  final double flowLpm;

  TelemetrySample({
    required this.timestamp,
    required this.pressureKpa,
    required this.motorRpm,
    required this.temperatureC,
    required this.flowLpm,
  });

  factory TelemetrySample.fromMap(Map<String, dynamic> map) {
    return TelemetrySample(
      timestamp: DateTime.parse(map['timestamp'] as String),
      pressureKpa: (map['pressure_kpa'] as num).toDouble(),
      motorRpm: (map['motor_rpm'] as num).toDouble(),
      temperatureC: (map['temperature_c'] as num).toDouble(),
      flowLpm: (map['flow_lpm'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'pressure_kpa': pressureKpa,
      'motor_rpm': motorRpm,
      'temperature_c': temperatureC,
      'flow_lpm': flowLpm,
    };
  }
}
