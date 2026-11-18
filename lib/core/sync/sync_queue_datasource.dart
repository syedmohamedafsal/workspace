import 'package:sqflite/sqflite.dart';

import '../constants/db_constants.dart';
import '../database/app_database.dart';
import 'sync_operation.dart';
import 'sync_status.dart';

/// Counts of outbox items grouped by queue status.
class SyncQueueCounts {
  const SyncQueueCounts({
    this.pending = 0,
    this.failed = 0,
    this.conflict = 0,
  });

  final int pending;
  final int failed;
  final int conflict;
}

/// Persistent SQLite storage for the offline synchronization outbox.
class SyncQueueDataSource {
  SyncQueueDataSource(this._appDatabase);

  final AppDatabase _appDatabase;

  Future<void> enqueue(SyncOperation operation, {DatabaseExecutor? executor}) async {
    final db = executor ?? await _appDatabase.database;
    await db.insert(
      DbConstants.tableSyncQueue,
      operation.toDbMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Returns operations eligible to run at [now] in FIFO order.
  Future<List<SyncOperation>> getDueOperations({DateTime? now}) async {
    final db = await _appDatabase.database;
    final cutoff = (now ?? DateTime.now()).toIso8601String();
    final rows = await db.query(
      DbConstants.tableSyncQueue,
      where: 'status = ? AND (next_retry_at IS NULL OR next_retry_at <= ?)',
      whereArgs: [SyncQueueStatus.pending.name, cutoff],
      orderBy: 'created_at ASC',
    );
    return rows.map(SyncOperation.fromDbMap).toList();
  }

  /// Resets any items left in `processing` (e.g. after an app crash) back to `pending`.
  Future<void> recoverInterruptedOperations() async {
    final db = await _appDatabase.database;
    await db.update(
      DbConstants.tableSyncQueue,
      {
        'status': SyncQueueStatus.pending.name,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'status = ?',
      whereArgs: [SyncQueueStatus.processing.name],
    );
  }

  Future<void> markProcessing(String operationId) async {
    final db = await _appDatabase.database;
    await db.update(
      DbConstants.tableSyncQueue,
      {
        'status': SyncQueueStatus.processing.name,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [operationId],
    );
  }

  Future<void> markCompleted(String operationId) async {
    final db = await _appDatabase.database;
    await db.delete(
      DbConstants.tableSyncQueue,
      where: 'id = ?',
      whereArgs: [operationId],
    );
  }

  Future<void> scheduleRetry({
    required String operationId,
    required int retryCount,
    required DateTime nextRetryAt,
    required String error,
  }) async {
    final db = await _appDatabase.database;
    await db.update(
      DbConstants.tableSyncQueue,
      {
        'status': SyncQueueStatus.pending.name,
        'retry_count': retryCount,
        'next_retry_at': nextRetryAt.toIso8601String(),
        'last_error': error,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [operationId],
    );
  }

  Future<void> markFailed({
    required String operationId,
    required int retryCount,
    required String error,
  }) async {
    final db = await _appDatabase.database;
    await db.update(
      DbConstants.tableSyncQueue,
      {
        'status': SyncQueueStatus.failed.name,
        'retry_count': retryCount,
        'next_retry_at': null,
        'last_error': error,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [operationId],
    );
  }

  Future<void> markConflict({
    required String operationId,
    required String error,
  }) async {
    final db = await _appDatabase.database;
    await db.update(
      DbConstants.tableSyncQueue,
      {
        'status': SyncQueueStatus.conflict.name,
        'last_error': error,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [operationId],
    );
  }

  /// Re-queues all failed operations for manual retry.
  Future<void> resetFailedToPending() async {
    final db = await _appDatabase.database;
    await db.update(
      DbConstants.tableSyncQueue,
      {
        'status': SyncQueueStatus.pending.name,
        'retry_count': 0,
        'next_retry_at': null,
        'last_error': null,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'status = ?',
      whereArgs: [SyncQueueStatus.failed.name],
    );
  }

  Future<SyncQueueCounts> getCounts() async {
    final db = await _appDatabase.database;
    final rows = await db.rawQuery('''
      SELECT status, COUNT(*) AS cnt
      FROM ${DbConstants.tableSyncQueue}
      GROUP BY status
    ''');

    var pending = 0;
    var failed = 0;
    var conflict = 0;

    for (final row in rows) {
      final status = row['status'] as String;
      final count = (row['cnt'] as num).toInt();
      if (status == SyncQueueStatus.pending.name ||
          status == SyncQueueStatus.processing.name) {
        pending += count;
      } else if (status == SyncQueueStatus.failed.name) {
        failed += count;
      } else if (status == SyncQueueStatus.conflict.name) {
        conflict += count;
      }
    }

    return SyncQueueCounts(
      pending: pending,
      failed: failed,
      conflict: conflict,
    );
  }
}
