import 'dart:math';

const channelNames = ['Pressure (kPa)', 'Motor (RPM)', 'Temperature (C)', 'Flow (L/min)'];
const channelShort = ['Pressure', 'Motor RPM', 'Temperature', 'Flow'];

class Telemetry {
  const Telemetry(this.time, this.v);
  final DateTime time;
  final List<double> v; // pressure, rpm, temperature, flow
}

class AlertRecord {
  const AlertRecord({
    required this.time,
    required this.source,
    required this.channel,
    required this.score,
    required this.severity,
  });
  final DateTime time;
  final String source;
  final String channel;
  final double score;
  final String severity;

  Map<String, dynamic> toJson() => {
        'time': time.toIso8601String(),
        'source': source,
        'channel': channel,
        'score': score,
        'severity': severity,
      };

  factory AlertRecord.fromJson(Map<String, dynamic> j) => AlertRecord(
        time: DateTime.parse(j['time'] as String),
        source: j['source'] as String,
        channel: j['channel'] as String,
        score: (j['score'] as num).toDouble(),
        severity: j['severity'] as String,
      );
}

String severityFor(double score, double threshold) {
  if (score >= threshold * 2.5) return 'Critical';
  if (score >= threshold * 1.5) return 'High';
  return 'Warning';
}

class Episode {
  const Episode(this.start, this.end, this.peak, this.channel);
  final int start;
  final int end;
  final double peak;
  final int channel;
}

class AnalysisResult {
  const AnalysisResult({
    required this.scores,
    required this.anomalies,
    required this.episodes,
    required this.baselineCount,
  });
  final List<double> scores;
  final List<int> anomalies;
  final List<Episode> episodes;
  final int baselineCount;
  double get maxScore => scores.isEmpty ? 0.0 : scores.reduce(max);
}