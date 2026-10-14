import 'dart:convert';

class ChannelBounds {
  final String name;
  final String unit;
  double minVal;
  double maxVal;
  double zThreshold;
  bool enabled;

  ChannelBounds({
    required this.name,
    required this.unit,
    required this.minVal,
    required this.maxVal,
    this.zThreshold = 3.0,
    this.enabled = true,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'unit': unit,
    'minVal': minVal,
    'maxVal': maxVal,
    'zThreshold': zThreshold,
    'enabled': enabled,
  };

  factory ChannelBounds.fromJson(Map<String, dynamic> json) => ChannelBounds(
    name: json['name'] as String,
    unit: json['unit'] as String,
    minVal: (json['minVal'] as num).toDouble(),
    maxVal: (json['maxVal'] as num).toDouble(),
    zThreshold: (json['zThreshold'] as num?)?.toDouble() ?? 3.0,
    enabled: json['enabled'] as bool? ?? true,
  );

  static List<ChannelBounds> defaultThresholds() => [
    ChannelBounds(name: 'Pressure', unit: 'kPa', minVal: 80.0, maxVal: 125.0, zThreshold: 3.0),
    ChannelBounds(name: 'Motor', unit: 'RPM', minVal: 1100.0, maxVal: 1800.0, zThreshold: 3.0),
    ChannelBounds(name: 'Temperature', unit: '°C', minVal: 45.0, maxVal: 85.0, zThreshold: 3.0),
    ChannelBounds(name: 'Flow', unit: 'L/min', minVal: 6.0, maxVal: 18.0, zThreshold: 3.0),
  ];
}
