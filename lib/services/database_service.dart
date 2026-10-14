import 'dart:io';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../models.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._internal();
  DatabaseService._internal();

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    if (Platform.isWindows || Platform.isLinux) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final docDir = await getApplicationDocumentsDirectory();
    final dbPath = join(docDir.path, 'gridsentinel_telemetry.db');

    return await openDatabase(
      dbPath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE telemetry_history (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            timestamp TEXT NOT NULL,
            pressure_kpa REAL NOT NULL,
            motor_rpm REAL NOT NULL,
            temperature_c REAL NOT NULL,
            flow_lpm REAL NOT NULL,
            ewma_score REAL NOT NULL,
            cnn_score REAL NOT NULL,
            source TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE INDEX idx_telemetry_timestamp ON telemetry_history (timestamp)
        ''');
      },
    );
  }

  Future<void> insertTelemetry(Telemetry t, double ewmaScore, double cnnScore, String source) async {
    final db = await database;
    await db.insert(
      'telemetry_history',
      {
        'timestamp': t.time.toIso8601String(),
        'pressure_kpa': t.v[0],
        'motor_rpm': t.v[1],
        'temperature_c': t.v[2],
        'flow_lpm': t.v[3],
        'ewma_score': ewmaScore,
        'cnn_score': cnnScore,
        'source': source,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Telemetry>> getRecentTelemetry({int limit = 300}) async {
    final db = await database;
    final maps = await db.query(
      'telemetry_history',
      orderBy: 'id DESC',
      limit: limit,
    );

    final items = maps.map((m) {
      return Telemetry(
        DateTime.parse(m['timestamp'] as String),
        [
          (m['pressure_kpa'] as num).toDouble(),
          (m['motor_rpm'] as num).toDouble(),
          (m['temperature_c'] as num).toDouble(),
          (m['flow_lpm'] as num).toDouble(),
        ],
      );
    }).toList();

    return items.reversed.toList();
  }

  Future<List<Telemetry>> queryTelemetryRange({
    DateTime? start,
    DateTime? end,
    int limit = 1000,
  }) async {
    final db = await database;
    String whereClause = '';
    List<dynamic> whereArgs = [];

    if (start != null && end != null) {
      whereClause = 'timestamp BETWEEN ? AND ?';
      whereArgs = [start.toIso8601String(), end.toIso8601String()];
    } else if (start != null) {
      whereClause = 'timestamp >= ?';
      whereArgs = [start.toIso8601String()];
    } else if (end != null) {
      whereClause = 'timestamp <= ?';
      whereArgs = [end.toIso8601String()];
    }

    final maps = await db.query(
      'telemetry_history',
      where: whereClause.isEmpty ? null : whereClause,
      whereArgs: whereArgs.isEmpty ? null : whereArgs,
      orderBy: 'timestamp ASC',
      limit: limit,
    );

    return maps.map((m) {
      return Telemetry(
        DateTime.parse(m['timestamp'] as String),
        [
          (m['pressure_kpa'] as num).toDouble(),
          (m['motor_rpm'] as num).toDouble(),
          (m['temperature_c'] as num).toDouble(),
          (m['flow_lpm'] as num).toDouble(),
        ],
      );
    }).toList();
  }

  Future<int> getRecordCount() async {
    final db = await database;
    final res = await db.rawQuery('SELECT COUNT(*) as count FROM telemetry_history');
    return Sqflite.firstIntValue(res) ?? 0;
  }

  Future<void> clearHistory() async {
    final db = await database;
    await db.delete('telemetry_history');
  }
}
