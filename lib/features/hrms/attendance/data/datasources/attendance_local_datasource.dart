import 'package:sqflite/sqflite.dart';

import '../../../../../core/constants/db_constants.dart';
import '../../../../../core/database/app_database.dart';
import '../../../../../core/error/exceptions.dart';
import '../../../../../core/sync/sync_operation.dart';
import '../../../../../core/sync/sync_queue_datasource.dart';
import '../../../../../core/sync/sync_status.dart';
import '../models/attendance_record_model.dart';

/// Local SQLite data source for offline-first attendance persistence.
abstract interface class AttendanceLocalDataSource {
  Future<AttendanceRecordModel?> getAttendanceByDate(
    String employeeId,
    DateTime date,
  );

  Future<AttendanceRecordModel?> getByLocalId(String localId);

  Future<List<AttendanceRecordModel>> getAttendanceHistory(
    String employeeId, {
    int limit = 30,
  });

  /// Persists the attendance record and queues the sync operation in a single
  /// SQLite transaction so local state and outbox never diverge.
  Future<void> saveAndEnqueue({
    required AttendanceRecordModel record,
    required SyncOperation syncOperation,
  });

  /// Merges remote records into local storage while preserving any locally
  /// modified records that have not yet finished syncing.
  Future<void> mergeRemoteRecords(List<AttendanceRecordModel> remoteRecords);

  Future<void> markSynced({
    required String localId,
    String? serverId,
  });

  Future<void> markSyncState({
    required String localId,
    required RecordSyncStatus status,
    String? error,
  });
}

class AttendanceLocalDataSourceImpl implements AttendanceLocalDataSource {
  AttendanceLocalDataSourceImpl({
    required AppDatabase appDatabase,
    required SyncQueueDataSource syncQueueDataSource,
  })  : _appDatabase = appDatabase,
        _syncQueueDataSource = syncQueueDataSource;

  final AppDatabase _appDatabase;
  final SyncQueueDataSource _syncQueueDataSource;

  @override
  Future<AttendanceRecordModel?> getAttendanceByDate(
    String employeeId,
    DateTime date,
  ) async {
    try {
      final db = await _appDatabase.database;
      final rows = await db.query(
        DbConstants.tableAttendance,
        where: 'employee_id = ? AND attendance_date = ?',
        whereArgs: [employeeId, AttendanceRecordModel.formatDateKey(date)],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      return AttendanceRecordModel.fromDbMap(rows.first);
    } catch (e) {
      throw CacheException('Failed to read attendance for date.', cause: e);
    }
  }

  @override
  Future<AttendanceRecordModel?> getByLocalId(String localId) async {
    try {
      final db = await _appDatabase.database;
      final rows = await db.query(
        DbConstants.tableAttendance,
        where: 'local_id = ?',
        whereArgs: [localId],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      return AttendanceRecordModel.fromDbMap(rows.first);
    } catch (e) {
      throw CacheException('Failed to read attendance record.', cause: e);
    }
  }

  @override
  Future<List<AttendanceRecordModel>> getAttendanceHistory(
    String employeeId, {
    int limit = 30,
  }) async {
    try {
      final db = await _appDatabase.database;
      final rows = await db.query(
        DbConstants.tableAttendance,
        where: 'employee_id = ?',
        whereArgs: [employeeId],
        orderBy: 'attendance_date DESC, created_at DESC',
        limit: limit,
      );
      return rows.map(AttendanceRecordModel.fromDbMap).toList();
    } catch (e) {
      throw CacheException('Failed to read attendance history.', cause: e);
    }
  }

  @override
  Future<void> saveAndEnqueue({
    required AttendanceRecordModel record,
    required SyncOperation syncOperation,
  }) async {
    try {
      final db = await _appDatabase.database;
      await db.transaction((txn) async {
        await txn.insert(
          DbConstants.tableAttendance,
          record.toDbMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        await _syncQueueDataSource.enqueue(syncOperation, executor: txn);
      });
    } catch (e) {
      throw CacheException(
        'Failed to save attendance record locally.',
        cause: e,
      );
    }
  }

  @override
  Future<void> mergeRemoteRecords(
    List<AttendanceRecordModel> remoteRecords,
  ) async {
    try {
      final db = await _appDatabase.database;
      await db.transaction((txn) async {
        for (final remote in remoteRecords) {
          final existingRows = await txn.query(
            DbConstants.tableAttendance,
            where: 'local_id = ? OR (server_id IS NOT NULL AND server_id = ?)',
            whereArgs: [remote.localId, remote.serverId ?? ''],
            limit: 1,
          );

          if (existingRows.isNotEmpty) {
            final existing = AttendanceRecordModel.fromDbMap(existingRows.first);
            if (existing.needsSync) {
              // Keep local unsynced changes intact until outbox resolves them.
              continue;
            }
          }

          await txn.insert(
            DbConstants.tableAttendance,
            remote.toDbMap(),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      });
    } catch (e) {
      throw CacheException('Failed to cache remote attendance records.', cause: e);
    }
  }

  @override
  Future<void> markSynced({
    required String localId,
    String? serverId,
  }) async {
    try {
      final db = await _appDatabase.database;
      await db.update(
        DbConstants.tableAttendance,
        {
          'server_id': ?serverId,
          'sync_status': RecordSyncStatus.synced.name,
          'sync_error': null,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'local_id = ?',
        whereArgs: [localId],
      );
    } catch (e) {
      throw CacheException('Failed to mark attendance as synced.', cause: e);
    }
  }

  @override
  Future<void> markSyncState({
    required String localId,
    required RecordSyncStatus status,
    String? error,
  }) async {
    try {
      final db = await _appDatabase.database;
      await db.update(
        DbConstants.tableAttendance,
        {
          'sync_status': status.name,
          'sync_error': error,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'local_id = ?',
        whereArgs: [localId],
      );
    } catch (e) {
      throw CacheException('Failed to update attendance sync status.', cause: e);
    }
  }
}
