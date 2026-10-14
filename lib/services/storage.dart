import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models.dart';

class Storage {
  static const _keyAlerts = 'gridsentinel_alerts_v1';

  static Future<List<AlertRecord>> loadAlerts() async {
    try {
      final p = await SharedPreferences.getInstance();
      final str = p.getString(_keyAlerts);
      if (str == null) return [];
      final List list = json.decode(str);
      return list.map((e) => AlertRecord.fromJson(e)).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveAlerts(List<AlertRecord> alerts) async {
    try {
      final p = await SharedPreferences.getInstance();
      final str = json.encode(alerts.map((e) => e.toJson()).toList());
      await p.setString(_keyAlerts, str);
    } catch (_) {}
  }

  static Future<String> exportCsv(String fileName, List<List<dynamic>> rows) async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$fileName');
    final csvContent = rows.map((r) => r.join(',')).join('\n');
    await file.writeAsString(csvContent);
    return file.path;
  }

  static Future<String> exportJson(String fileName, List<Map<String, dynamic>> items) async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$fileName');
    final jsonContent = const JsonEncoder.withIndent('  ').convert(items);
    await file.writeAsString(jsonContent);
    return file.path;
  }
}
