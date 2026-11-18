import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../constants/db_constants.dart';
import '../time/company_clock.dart';

/// Manages the local SQLite database used as the offline-first source of truth.
class AppDatabase {
  AppDatabase({
    DatabaseFactory? databaseFactoryOverride,
    String? pathOverride,
    this.seedSampleAttendance = true,
  })  : _databaseFactoryOverride = databaseFactoryOverride,
        _pathOverride = pathOverride;

  final DatabaseFactory? _databaseFactoryOverride;
  final String? _pathOverride;
  final bool seedSampleAttendance;

  Database? _database;

  Future<Database> get database async {
    final existing = _database;
    if (existing != null && existing.isOpen) {
      return existing;
    }
    _database = await _openDatabase();
    return _database!;
  }

  Future<Database> _openDatabase() async {
    final factory = _resolveFactory();
    final dbPath = _pathOverride ??
        p.join(await factory.getDatabasesPath(), DbConstants.databaseName);

    return factory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: DbConstants.databaseVersion,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      ),
    );
  }

  DatabaseFactory _resolveFactory() {
    if (_databaseFactoryOverride != null) {
      return _databaseFactoryOverride;
    }
    if (!kIsWeb && (Platform.isLinux || Platform.isWindows || Platform.isMacOS)) {
      sqfliteFfiInit();
      return databaseFactoryFfi;
    }
    return databaseFactory;
  }

  Future<void> _onCreate(Database db, int version) async {
    final batch = db.batch();

    batch.execute(_createEmployeeSessionsTableSql);

    batch.execute('''
      CREATE TABLE ${DbConstants.tableAttendance} (
        local_id TEXT PRIMARY KEY,
        server_id TEXT,
        employee_id TEXT NOT NULL,
        attendance_date TEXT NOT NULL,
        check_in_at TEXT,
        check_out_at TEXT,
        check_in_note TEXT,
        check_out_note TEXT,
        work_location TEXT,
        check_in_latitude REAL,
        check_in_longitude REAL,
        check_in_distance_meters REAL,
        check_out_latitude REAL,
        check_out_longitude REAL,
        check_out_distance_meters REAL,
        status TEXT NOT NULL,
        sync_status TEXT NOT NULL,
        sync_error TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    batch.execute('''
      CREATE UNIQUE INDEX IF NOT EXISTS idx_attendance_emp_date_unique
      ON ${DbConstants.tableAttendance}(employee_id, attendance_date)
    ''');

    batch.execute('''
      CREATE TABLE ${DbConstants.tableLeaveRequests} (
        local_id TEXT PRIMARY KEY,
        server_id TEXT,
        employee_id TEXT NOT NULL,
        leave_type TEXT NOT NULL,
        start_date TEXT NOT NULL,
        end_date TEXT NOT NULL,
        is_half_day INTEGER NOT NULL DEFAULT 0,
        reason TEXT NOT NULL,
        approval_status TEXT NOT NULL,
        approver_comment TEXT,
        sync_status TEXT NOT NULL,
        sync_error TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    batch.execute('''
      CREATE INDEX idx_leave_emp_start
      ON ${DbConstants.tableLeaveRequests}(employee_id, start_date DESC)
    ''');

    batch.execute('''
      CREATE TABLE ${DbConstants.tableLeaveBalances} (
        leave_type TEXT PRIMARY KEY,
        total_days REAL NOT NULL,
        used_days REAL NOT NULL,
        pending_days REAL NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    batch.execute('''
      CREATE TABLE ${DbConstants.tableSyncQueue} (
        id TEXT PRIMARY KEY,
        entity_type TEXT NOT NULL,
        entity_id TEXT NOT NULL,
        operation_type TEXT NOT NULL,
        payload TEXT NOT NULL,
        idempotency_key TEXT NOT NULL UNIQUE,
        status TEXT NOT NULL,
        retry_count INTEGER NOT NULL DEFAULT 0,
        next_retry_at TEXT,
        last_error TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    batch.execute('''
      CREATE INDEX idx_sync_queue_status_created
      ON ${DbConstants.tableSyncQueue}(status, created_at ASC)
    ''');

    // Seed baseline leave balances so the app is immediately usable offline
    // before the first successful server pull.
    final nowIso = DateTime.now().toIso8601String();
    batch.insert(DbConstants.tableLeaveBalances, {
      'leave_type': 'annual',
      'total_days': 18.0,
      'used_days': 4.0,
      'pending_days': 0.0,
      'updated_at': nowIso,
    });
    batch.insert(DbConstants.tableLeaveBalances, {
      'leave_type': 'sick',
      'total_days': 10.0,
      'used_days': 1.0,
      'pending_days': 0.0,
      'updated_at': nowIso,
    });
    batch.insert(DbConstants.tableLeaveBalances, {
      'leave_type': 'casual',
      'total_days': 6.0,
      'used_days': 1.0,
      'pending_days': 0.0,
      'updated_at': nowIso,
    });

    await batch.commit(noResult: true);

    if (seedSampleAttendance) {
      await _seedRecentWorkingDays(db);
    }
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute(_createEmployeeSessionsTableSql);
    }
    if (oldVersion < 3) {
      await db.execute(
        'ALTER TABLE ${DbConstants.tableAttendance} ADD COLUMN check_in_latitude REAL',
      );
      await db.execute(
        'ALTER TABLE ${DbConstants.tableAttendance} ADD COLUMN check_in_longitude REAL',
      );
      await db.execute(
        'ALTER TABLE ${DbConstants.tableAttendance} ADD COLUMN check_in_distance_meters REAL',
      );
      await db.execute(
        'ALTER TABLE ${DbConstants.tableAttendance} ADD COLUMN check_out_latitude REAL',
      );
      await db.execute(
        'ALTER TABLE ${DbConstants.tableAttendance} ADD COLUMN check_out_longitude REAL',
      );
      await db.execute(
        'ALTER TABLE ${DbConstants.tableAttendance} ADD COLUMN check_out_distance_meters REAL',
      );
    }
    if (oldVersion < 6) {
      // Remove any duplicate (employee_id, attendance_date) rows keeping the
      // most recently updated record before enforcing the unique index.
      await db.execute('''
        DELETE FROM ${DbConstants.tableAttendance}
        WHERE rowid NOT IN (
          SELECT MAX(rowid)
          FROM ${DbConstants.tableAttendance}
          GROUP BY employee_id, attendance_date
        )
      ''');
      await db.execute('DROP INDEX IF EXISTS idx_attendance_emp_date');
      await db.execute('''
        CREATE UNIQUE INDEX IF NOT EXISTS idx_attendance_emp_date_unique
        ON ${DbConstants.tableAttendance}(employee_id, attendance_date)
      ''');
      if (seedSampleAttendance) {
        await _seedRecentWorkingDays(db);
      }
    }
  }

  /// Seeds the last five working days (Monday–Friday, excluding today) for
  /// `REBS001` at Teqbae Innovations, Kochi. Inserts per-date only when that
  /// date is missing so existing records (including today's check-in) are never
  /// overwritten.
  Future<void> _seedRecentWorkingDays(Database db) async {
    final clock = CompanyClock();
    final today = clock.workingDate('Asia/Kolkata');

    // Collect the previous 5 working days (Mon–Fri) before today.
    final workingDays = <DateTime>[];
    var cursor = today.subtract(const Duration(days: 1));
    while (workingDays.length < 5) {
      if (cursor.weekday != DateTime.saturday &&
          cursor.weekday != DateTime.sunday) {
        workingDays.add(cursor);
      }
      cursor = cursor.subtract(const Duration(days: 1));
    }

    // Realistic 12-hour check-in/out times and GPS points within 200m of
    // Teqbae Innovations, Kochi (10.0159, 76.3419).
    const profiles = [
      (
        inHour: 9,
        inMin: 6,
        outHour: 18,
        outMin: 14,
        inLat: 10.0161,
        inLng: 76.3419,
        inDist: 22.0,
        outLat: 10.0160,
        outLng: 76.3420,
        outDist: 16.0,
      ),
      (
        inHour: 9,
        inMin: 18,
        outHour: 18,
        outMin: 5,
        inLat: 10.0162,
        inLng: 76.3421,
        inDist: 40.0,
        outLat: 10.0158,
        outLng: 76.3418,
        outDist: 15.0,
      ),
      (
        inHour: 8,
        inMin: 54,
        outHour: 17,
        outMin: 58,
        inLat: 10.0157,
        inLng: 76.3420,
        inDist: 25.0,
        outLat: 10.0161,
        outLng: 76.3417,
        outDist: 31.0,
      ),
      (
        inHour: 9,
        inMin: 11,
        outHour: 18,
        outMin: 22,
        inLat: 10.0163,
        inLng: 76.3418,
        inDist: 46.0,
        outLat: 10.0159,
        outLng: 76.3421,
        outDist: 22.0,
      ),
      (
        inHour: 9,
        inMin: 2,
        outHour: 18,
        outMin: 9,
        inLat: 10.0160,
        inLng: 76.3418,
        inDist: 16.0,
        outLat: 10.0161,
        outLng: 76.3419,
        outDist: 22.0,
      ),
    ];

    // Remove any previously seeded weekend rows from v4 so all 5 are Mon–Fri.
    await db.delete(
      DbConstants.tableAttendance,
      where: "local_id LIKE 'seed-att-%'",
    );

    final batch = db.batch();
    for (var i = 0; i < workingDays.length; i++) {
      final date = workingDays[i];
      final s = profiles[i];
      final dateKey =
          '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

      final alreadyPresent = await db.query(
        DbConstants.tableAttendance,
        columns: ['local_id'],
        where: 'employee_id = ? AND attendance_date = ?',
        whereArgs: ['REBS001', dateKey],
        limit: 1,
      );
      if (alreadyPresent.isNotEmpty) continue;

      final checkIn = CompanyClock.fromCompanyTimezone(
        year: date.year,
        month: date.month,
        day: date.day,
        hour: s.inHour,
        minute: s.inMin,
        timezone: 'Asia/Kolkata',
      );
      final checkOut = CompanyClock.fromCompanyTimezone(
        year: date.year,
        month: date.month,
        day: date.day,
        hour: s.outHour,
        minute: s.outMin,
        timezone: 'Asia/Kolkata',
      );

      batch.insert(
        DbConstants.tableAttendance,
        {
          'local_id': 'seed-att-$dateKey',
          'server_id': 'srv-att-$dateKey',
          'employee_id': 'REBS001',
          'attendance_date': dateKey,
          'check_in_at': checkIn.toIso8601String(),
          'check_out_at': checkOut.toIso8601String(),
          'check_in_note': null,
          'check_out_note': null,
          'work_location': 'Teqbae Innovations, Kochi',
          'check_in_latitude': s.inLat,
          'check_in_longitude': s.inLng,
          'check_in_distance_meters': s.inDist,
          'check_out_latitude': s.outLat,
          'check_out_longitude': s.outLng,
          'check_out_distance_meters': s.outDist,
          'status': 'checkedOut',
          'sync_status': 'synced',
          'sync_error': null,
          'created_at': checkIn.toIso8601String(),
          'updated_at': checkOut.toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
    await batch.commit(noResult: true);
  }

  static const String _createEmployeeSessionsTableSql = '''
      CREATE TABLE IF NOT EXISTS ${DbConstants.tableEmployeeSessions} (
        session_id TEXT PRIMARY KEY,
        employee_id TEXT NOT NULL,
        employee_name TEXT NOT NULL,
        department TEXT NOT NULL,
        designation TEXT NOT NULL,
        office_id TEXT NOT NULL,
        office_name TEXT NOT NULL,
        office_latitude REAL NOT NULL,
        office_longitude REAL NOT NULL,
        company_timezone TEXT NOT NULL,
        is_active INTEGER NOT NULL DEFAULT 1,
        initialized_at TEXT NOT NULL,
        last_restored_at TEXT NOT NULL
      )
    ''';

  Future<void> close() async {
    final db = _database;
    if (db != null && db.isOpen) {
      await db.close();
      _database = null;
    }
  }
}
