import 'dart:math';
import 'models.dart';

class Simulator {
  final Random _rnd = Random();
  int t = 0;
  int? driftStart;

  void injectDrift() => driftStart ??= t;
  void clearDrift() => driftStart = null;
  double _n(double s) => (_rnd.nextDouble() - 0.5) * s;

  Telemetry next() {
    final i = t++;
    var p = 600 + 5 * sin(i / 8) + _n(2);
    final rpm = 1450 + 10 * sin(i / 10) + _n(4);
    var temp = 55 + 0.5 * sin(i / 12.5) + _n(0.3);
    var flow = 320 + 4 * sin(i / 9) + _n(1.5);
    final ds = driftStart;
    if (ds != null) {
      final k = min(1.0, max(0.0, (i - ds) / 120.0));
      final kt = min(1.0, max(0.0, (i - ds - 30) / 90.0));
      p *= 1 - 0.03 * k;
      temp *= 1 + 0.04 * kt;
      flow *= 1 - 0.01 * k;
    }
    return Telemetry(DateTime.now(), [p, rpm, temp, flow]);
  }
}