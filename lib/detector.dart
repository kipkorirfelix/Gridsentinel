import 'dart:math';
import 'models.dart';

class DetectionResult {
  const DetectionResult(this.score, this.channel);
  final double score;
  final int channel;
}

/// Baseline + EWMA z-score drift detector (placeholder until the 1D-CNN is trained).
class Detector {
  Detector({this.alpha = 0.05});
  final double alpha;
  final List<double> _mean = List<double>.filled(4, 0);
  final List<double> _std = List<double>.filled(4, 1);
  List<double>? _ewma;
  bool fitted = false;

  void fit(List<Telemetry> base) {
    for (var c = 0; c < 4; c++) {
      final vals = base.map((t) => t.v[c]).toList();
      final m = vals.reduce((a, b) => a + b) / vals.length;
      final variance =
          vals.map((x) => (x - m) * (x - m)).reduce((a, b) => a + b) / vals.length;
      _mean[c] = m;
      _std[c] = max(sqrt(variance), max(m.abs() * 0.001, 1e-6));
    }
    _ewma = null;
    fitted = true;
  }

  DetectionResult update(Telemetry t) {
    final prev = _ewma;
    final cur = List<double>.generate(
        4, (c) => prev == null ? t.v[c] : prev[c] + alpha * (t.v[c] - prev[c]));
    _ewma = cur;
    var best = 0.0;
    var ch = 0;
    for (var c = 0; c < 4; c++) {
      final z = (cur[c] - _mean[c]).abs() / _std[c];
      if (z > best) {
        best = z;
        ch = c;
      }
    }
    return DetectionResult(best, ch);
  }
}