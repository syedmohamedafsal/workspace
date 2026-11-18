import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../constants/db_constants.dart';

/// Manages the local SQLite database used as the offline-first source of truth.
class AppDatabase {
  AppDatabase({DatabaseFactory? databaseFactoryOverride, String? pathOverride})
      : _databaseFactoryOverride = databaseFactoryOverride,
        _pathOverride = pathOverride;

  final DatabaseFactory? _databaseFactoryOverride;
  final String? _pathOverride;

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
        status TEXT NOT NULL,
        sync_status TEXT NOT NULL,
        sync_error TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    batch.execute('''
      CREATE INDEX idx_attendance_emp_date
      ON ${DbConstants.tableAttendance}(employee_id, attendance_date DESC)
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
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Future schema migrations go here incrementally by version.
  }

  Future<void> close() async {
    final db = _database;
    if (db != null && db.isOpen) {
      await db.close();
      _database = null;
    }
  }
}
