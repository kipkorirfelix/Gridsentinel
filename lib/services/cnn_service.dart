import 'dart:math' as math;
import 'dart:convert';
import 'package:flutter/services.dart';
import '../models.dart';
import '../models/telemetry_sample.dart';

class CnnService {
  Map<String, dynamic>? _modelData;
  bool _isLoaded = false;

  bool get isLoaded => _isLoaded;

  Future<void> loadModel() async {
    if (_isLoaded) return;
    try {
      String jsonString = await rootBundle.loadString('assets/models/gridsentinel_weights.json');
      _modelData = json.decode(jsonString);
      _isLoaded = true;
    } catch (e) {
      _isLoaded = false;
    }
  }

  double predictTelemetry(List<Telemetry> window) {
    if (!_isLoaded || _modelData == null) return 0.0;
    if (window.length != 50) return 0.0;

    final samples = window.map((t) => TelemetrySample(
      timestamp: t.time,
      pressureKpa: t.v[0],
      motorRpm: t.v[1],
      temperatureC: t.v[2],
      flowLpm: t.v[3],
    )).toList();

    return predict(samples);
  }

  List<List<double>> _preprocessWindow(List<TelemetrySample> window) {
    var normConfig = _modelData!['normalization'];
    List mean = normConfig['mean'];
    List std = normConfig['std'];

    List<List<double>> normalized = [];
    for (var sample in window) {
      List<double> raw = [
        sample.pressureKpa,
        sample.motorRpm,
        sample.temperatureC,
        sample.flowLpm,
      ];
      List<double> scaled = [];
      for (int i = 0; i < raw.length; i++) {
        double val = (raw[i] - mean[i]) / (std[i] + 1e-8);
        scaled.add(val);
      }
      normalized.add(scaled);
    }
    return normalized;
  }

  double predict(List<TelemetrySample> window) {
    if (!_isLoaded || _modelData == null) {
      throw Exception('CNN model weights are not loaded.');
    }

    if (window.length != 50) {
      throw ArgumentError('Input window must contain exactly 50 samples.');
    }

    List<List<double>> normWindow = _preprocessWindow(window);
    int channels = 4;
    int length = 50;
    List<List<double>> x = List.generate(channels, (c) => List.generate(length, (l) => normWindow[l][c]));

    var weights = _modelData!['weights'];

    x = _conv1d(x, weights['conv1_weight'], weights['conv1_bias'], padding: 1);
    x = _relu2d(x);
    x = _maxPool1d(x, kernelSize: 2, stride: 2);

    x = _conv1d(x, weights['conv2_weight'], weights['conv2_bias'], padding: 1);
    x = _relu2d(x);
    x = _maxPool1d(x, kernelSize: 2, stride: 2);

    List<double> flattened = [];
    for (var ch in x) {
      flattened.addAll(ch);
    }

    List<double> fc1Out = _linear(flattened, weights['fc1_weight'], weights['fc1_bias']);
    fc1Out = fc1Out.map((v) => v > 0 ? v : 0.0).toList();

    List<double> fc2Out = _linear(fc1Out, weights['fc2_weight'], weights['fc2_bias']);

    double score = 1.0 / (1.0 + math.exp(-fc2Out[0]));
    return score;
  }

  List<List<double>> _conv1d(List<List<double>> input, List weight, List bias, {int padding = 1}) {
    int cIn = input.length;
    int length = input[0].length;
    int cOut = weight.length;
    int kernelSize = weight[0][0].length;

    List<List<double>> output = List.generate(cOut, (_) => List.filled(length, 0.0));

    for (int o = 0; o < cOut; o++) {
      double b = bias[o];
      for (int l = 0; l < length; l++) {
        double sum = b;
        for (int c = 0; c < cIn; c++) {
          for (int k = 0; k < kernelSize; k++) {
            int inpIdx = l + k - padding;
            if (inpIdx >= 0 && inpIdx < length) {
              sum += input[c][inpIdx] * weight[o][c][k];
            }
          }
        }
        output[o][l] = sum;
      }
    }
    return output;
  }

  List<List<double>> _relu2d(List<List<double>> input) {
    return input.map((row) => row.map((v) => v > 0 ? v : 0.0).toList()).toList();
  }

  List<List<double>> _maxPool1d(List<List<double>> input, {int kernelSize = 2, int stride = 2}) {
    int cIn = input.length;
    int inLen = input[0].length;
    int outLen = (inLen / stride).floor();

    List<List<double>> output = List.generate(cIn, (_) => List.filled(outLen, 0.0));

    for (int c = 0; c < cIn; c++) {
      for (int i = 0; i < outLen; i++) {
        int start = i * stride;
        int end = start + kernelSize;
        if (end > inLen) end = inLen;
        double maxVal = input[c][start];
        for (int j = start + 1; j < end; j++) {
          if (input[c][j] > maxVal) maxVal = input[c][j];
        }
        output[c][i] = maxVal;
      }
    }
    return output;
  }

  List<double> _linear(List<double> input, List weight, List bias) {
    int outFeatures = weight.length;
    int inFeatures = weight[0].length;
    List<double> output = List.filled(outFeatures, 0.0);

    for (int i = 0; i < outFeatures; i++) {
      double sum = bias[i];
      for (int j = 0; j < inFeatures; j++) {
        sum += input[j] * weight[i][j];
      }
      output[i] = sum;
    }
    return output;
  }
}
