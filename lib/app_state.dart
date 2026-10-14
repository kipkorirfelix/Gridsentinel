import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'connectors/connector_interface.dart';
import 'connectors/simulated_connector.dart';
import 'detector.dart';
import 'models.dart';
import 'models/channel_thresholds.dart';
import 'services/cnn_service.dart';
import 'services/database_service.dart';
import 'services/storage.dart';
import 'simulator.dart';

final appState = AppState();

class AppState extends ChangeNotifier {
  // navigation
  final ValueNotifier<int> tab = ValueNotifier<int>(0);
  void goTo(int i) => tab.value = i;

  // settings
  double threshold = 3.0;
  double alpha = 0.05;
  int intervalMs = 500;
  List<ChannelBounds> channelBounds = ChannelBounds.defaultThresholds();

  // connector & live streams
  IndustrialConnector activeConnector = SimulatedConnector();
  StreamSubscription<IndustrialTelemetry>? _telemetrySub;
  StreamSubscription<ConnectionStatus>? _statusSub;
  ConnectionStatus connectionStatus = ConnectionStatus.disconnected;

  Simulator get sim => (activeConnector is SimulatedConnector)
      ? (activeConnector as SimulatedConnector).simulator
      : Simulator();

  Detector _det = Detector();
  final CnnService cnnService = CnnService();
  final List<Telemetry> _warm = [];
  static const warmupSamples = 60;
  final List<Telemetry> live = [];
  Telemetry? latest;
  double score = 0;
  double cnnScore = 0.0;
  int scoreChannel = 0;
  bool running = false;
  int persistedCount = 0;
  DateTime? _lastAlert;

  // offline playback state
  bool isPlaybackMode = false;
  bool isPlaybackRunning = false;
  int playbackSpeed = 1;
  List<Telemetry> playbackBuffer = [];
  int playbackIndex = 0;
  Timer? _playbackTimer;

  bool get learning => !_det.fitted;
  bool get alarm => _det.fitted && (score > threshold || cnnScore > 0.85 || _hasChannelBreach());
  bool get driftActive => sim.driftStart != null;
  double get warmupProgress => min(1.0, _warm.length / warmupSamples);

  // import + analysis
  List<Telemetry> imported = [];
  String importedName = '';
  AnalysisResult? analysis;
  bool findingsSaved = false;

  // alerts
  List<AlertRecord> alerts = [];

  bool _hasChannelBreach() {
    if (latest == null) return false;
    for (int i = 0; i < channelBounds.length && i < latest!.v.length; i++) {
      final cb = channelBounds[i];
      if (cb.enabled) {
        final val = latest!.v[i];
        if (val < cb.minVal || val > cb.maxVal) return true;
      }
    }
    return false;
  }

  Future<void> init() async {
    try {
      final p = await SharedPreferences.getInstance();
      threshold = p.getDouble('threshold') ?? 3.0;
      alpha = p.getDouble('alpha') ?? 0.05;
      intervalMs = p.getInt('intervalMs') ?? 500;
      final rawBounds = p.getString('channelBounds');
      if (rawBounds != null) {
        final List list = json.decode(rawBounds);
        channelBounds = list.map((e) => ChannelBounds.fromJson(e)).toList();
      }
    } catch (_) {}
    alerts = await Storage.loadAlerts();
    _det = Detector(alpha: alpha);
    await cnnService.loadModel();

    final cached = await DatabaseService.instance.getRecentTelemetry();
    if (cached.isNotEmpty) {
      live.addAll(cached);
      latest = cached.last;
    }
    persistedCount = await DatabaseService.instance.getRecordCount();

    _bindConnector(activeConnector);
    startLive();
  }

  Future<void> saveChannelBounds() async {
    try {
      final p = await SharedPreferences.getInstance();
      final str = json.encode(channelBounds.map((e) => e.toJson()).toList());
      await p.setString('channelBounds', str);
    } catch (_) {}
    notifyListeners();
  }

  void _bindConnector(IndustrialConnector connector) {
    _telemetrySub?.cancel();
    _statusSub?.cancel();

    activeConnector = connector;
    _statusSub = activeConnector.statusStream.listen((status) {
      connectionStatus = status;
      notifyListeners();
    });

    _telemetrySub = activeConnector.telemetryStream.listen((item) {
      if (item.quality == DataQuality.good && running && !isPlaybackMode) {
        _processTelemetry(item.telemetry);
      }
    });
  }

  Future<void> switchConnector(IndustrialConnector connector, ConnectorConfig config) async {
    stopPlayback();
    await activeConnector.disconnect();
    _bindConnector(connector);
    await activeConnector.connect(config);
    running = true;
    notifyListeners();
  }

  Future<void> saveSettings() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setDouble('threshold', threshold);
      await p.setDouble('alpha', alpha);
      await p.setInt('intervalMs', intervalMs);
    } catch (_) {}
  }

  void setThreshold(double v) {
    threshold = v;
    notifyListeners();
  }

  void setAlpha(double v) {
    alpha = v;
    notifyListeners();
  }

  void commitAlpha() {
    _det = Detector(alpha: alpha);
    _warm.clear();
    score = 0;
    cnnScore = 0.0;
    saveSettings();
    notifyListeners();
  }

  void setInterval(int ms) {
    intervalMs = ms;
    if (running && activeConnector is SimulatedConnector && !isPlaybackMode) {
      startLive();
    }
    saveSettings();
    notifyListeners();
  }

  // ---- live ----
  void startLive() {
    stopPlayback();
    running = true;
    activeConnector.connect(SimulatedConfig(intervalMs: intervalMs));
    notifyListeners();
  }

  void pauseLive() {
    running = false;
    activeConnector.disconnect();
    notifyListeners();
  }

  void resetLive() {
    sim.clearDrift();
    live.clear();
    _warm.clear();
    _det = Detector(alpha: alpha);
    latest = null;
    score = 0;
    cnnScore = 0.0;
    notifyListeners();
  }

  // ---- playback ----
  void startPlayback(List<Telemetry> records, {int speed = 1}) {
    if (records.isEmpty) return;
    pauseLive();
    isPlaybackMode = true;
    playbackBuffer = List.from(records);
    playbackIndex = 0;
    playbackSpeed = speed;
    resetLive();
    isPlaybackRunning = true;
    _scheduleNextPlaybackTick();
    notifyListeners();
  }

  void pausePlayback() {
    isPlaybackRunning = false;
    _playbackTimer?.cancel();
    notifyListeners();
  }

  void resumePlayback() {
    if (playbackBuffer.isEmpty || playbackIndex >= playbackBuffer.length) return;
    isPlaybackRunning = true;
    _scheduleNextPlaybackTick();
    notifyListeners();
  }

  void stopPlayback() {
    isPlaybackRunning = false;
    isPlaybackMode = false;
    _playbackTimer?.cancel();
    playbackBuffer.clear();
    playbackIndex = 0;
    notifyListeners();
  }

  void setPlaybackSpeed(int speed) {
    playbackSpeed = speed;
    if (isPlaybackRunning) {
      _playbackTimer?.cancel();
      _scheduleNextPlaybackTick();
    }
    notifyListeners();
  }

  void seekPlayback(int index) {
    if (index < 0 || index >= playbackBuffer.length) return;
    playbackIndex = index;
    live.clear();
    _warm.clear();
    _det = Detector(alpha: alpha);
    latest = null;
    score = 0;
    cnnScore = 0.0;
    for (int i = 0; i <= playbackIndex; i++) {
      _processTelemetry(playbackBuffer[i]);
    }
    notifyListeners();
  }

  void _scheduleNextPlaybackTick() {
    _playbackTimer?.cancel();
    if (!isPlaybackRunning || playbackIndex >= playbackBuffer.length) {
      isPlaybackRunning = false;
      notifyListeners();
      return;
    }

    final delayMs = max(50, (intervalMs / playbackSpeed).round());
    _playbackTimer = Timer(Duration(milliseconds: delayMs), () {
      if (playbackIndex < playbackBuffer.length) {
        _processTelemetry(playbackBuffer[playbackIndex]);
        playbackIndex++;
        notifyListeners();
        _scheduleNextPlaybackTick();
      } else {
        isPlaybackRunning = false;
        notifyListeners();
      }
    });
  }

  Future<void> clearDatabaseHistory() async {
    await DatabaseService.instance.clearHistory();
    persistedCount = 0;
    notifyListeners();
  }

  void injectDrift() {
    sim.injectDrift();
    notifyListeners();
  }

  void _processTelemetry(Telemetry t) {
    latest = t;
    live.add(t);
    if (live.length > 300) live.removeAt(0);

    if (!_det.fitted) {
      _warm.add(t);
      if (_warm.length >= warmupSamples) _det.fit(_warm);
    } else {
      final r = _det.update(t);
      score = r.score;
      scoreChannel = r.channel;

      if (live.length >= 50 && cnnService.isLoaded) {
        cnnScore = cnnService.predictTelemetry(live.sublist(live.length - 50));
      }

      if (alarm) _maybeLogAlert(t);
    }

    if (!isPlaybackMode) {
      DatabaseService.instance.insertTelemetry(t, score, cnnScore, activeConnector.name).then((_) {
        persistedCount++;
        notifyListeners();
      });
    }
  }

  void _maybeLogAlert(Telemetry t) {
    final now = DateTime.now();
    if (_lastAlert != null && now.difference(_lastAlert!).inSeconds < 15) return;
    _lastAlert = now;
    alerts.insert(
      0,
      AlertRecord(
        time: t.time,
        source: isPlaybackMode ? 'Offline Playback' : activeConnector.name,
        channel: channelShort[scoreChannel],
        score: score,
        severity: severityFor(score, threshold),
      ),
    );
    if (alerts.length > 500) alerts.removeLast();
    Storage.saveAlerts(alerts);
  }

  // ---- import / analysis ----
  void setImported(String name, List<Telemetry> rows) {
    imported = rows;
    importedName = name;
    analysis = null;
    findingsSaved = false;
    notifyListeners();
  }

  void analyzeImported() {
    final n = imported.length;
    if (n < 30) return;
    final baseCount = min(max(30, (n * 0.2).round()), n - 10);
    final det = Detector(alpha: alpha)..fit(imported.sublist(0, baseCount));
    final scores = <double>[];
    final chans = <int>[];
    for (var i = 0; i < n; i++) {
      final r = det.update(imported[i]);
      scores.add(i < baseCount ? 0.0 : r.score);
      chans.add(r.channel);
    }
    final anomalies = <int>[];
    final episodes = <Episode>[];
    int? start;
    var peak = 0.0;
    var pch = 0;
    var last = -1;
    for (var i = baseCount; i < n; i++) {
      if (scores[i] > threshold) {
        anomalies.add(i);
        if (start == null) {
          start = i;
          peak = 0.0;
        }
        if (scores[i] > peak) {
          peak = scores[i];
          pch = chans[i];
        }
        last = i;
      } else if (start != null) {
        episodes.add(Episode(start, last, peak, pch));
        start = null;
      }
    }
    if (start != null) episodes.add(Episode(start, last, peak, pch));
    analysis = AnalysisResult(
      scores: scores,
      anomalies: anomalies,
      episodes: episodes,
      baselineCount: baseCount,
    );
    findingsSaved = false;
    notifyListeners();
  }

  Future<int> saveFindings() async {
    final a = analysis;
    if (a == null) return 0;
    for (final e in a.episodes) {
      alerts.insert(
        0,
        AlertRecord(
          time: imported[e.start].time,
          source: importedName,
          channel: channelShort[e.channel],
          score: e.peak,
          severity: severityFor(e.peak, threshold),
        ),
      );
    }
    findingsSaved = true;
    notifyListeners();
    await Storage.saveAlerts(alerts);
    return a.episodes.length;
  }

  Future<void> clearAlerts() async {
    alerts.clear();
    notifyListeners();
    await Storage.saveAlerts(alerts);
  }

  String _stamp() => DateTime.now().toIso8601String().replaceAll(RegExp(r'[:.]'), '-');

  Future<String> exportAlerts() {
    final rows = <List<dynamic>>[
      <dynamic>['time', 'source', 'channel', 'score', 'severity'],
      for (final a in alerts)
        <dynamic>[a.time.toIso8601String(), a.source, a.channel, a.score.toStringAsFixed(2), a.severity],
    ];
    return Storage.exportCsv('gridsentinel_alerts_${_stamp()}.csv', rows);
  }

  Future<String> exportAlertsJson() {
    final list = alerts.map((a) => {
      'timestamp': a.time.toIso8601String(),
      'source': a.source,
      'channel': a.channel,
      'score': a.score,
      'severity': a.severity,
    }).toList();
    return Storage.exportJson('gridsentinel_alerts_${_stamp()}.json', list);
  }

  Future<String> exportReport() {
    final a = analysis!;
    final flagged = a.anomalies.toSet();
    final rows = <List<dynamic>>[
      <dynamic>['timestamp', 'pressure_kpa', 'motor_rpm', 'temperature_c', 'flow_lpm', 'anomaly_score', 'flagged'],
    ];
    for (var i = 0; i < imported.length; i++) {
      final t = imported[i];
      rows.add(<dynamic>[
        t.time.toIso8601String(),
        ...t.v.map((x) => x.toStringAsFixed(3)),
        a.scores[i].toStringAsFixed(2),
        flagged.contains(i) ? 1 : 0,
      ]);
    }
    return Storage.exportCsv('gridsentinel_report_${_stamp()}.csv', rows);
  }
}
