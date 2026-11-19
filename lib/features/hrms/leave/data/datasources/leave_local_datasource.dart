import 'package:sqflite/sqflite.dart';

import '../../../../../core/constants/db_constants.dart';
import '../../../../../core/database/app_database.dart';
import '../../../../../core/error/exceptions.dart';
import '../../../../../core/sync/sync_operation.dart';
import '../../../../../core/sync/sync_queue_datasource.dart';
import '../../../../../core/sync/sync_status.dart';
import '../../domain/entities/leave_request.dart';
import '../models/leave_balance_model.dart';
import '../models/leave_request_model.dart';

abstract interface class LeaveLocalDataSource {
  Future<List<LeaveRequestModel>> getLeaveRequests(String employeeId);

  Future<LeaveRequestModel?> getLeaveByLocalId(String localId);

  Future<List<LeaveBalanceModel>> getLeaveBalances();

  Future<void> saveRequestAndEnqueue({
    required LeaveRequestModel request,
    required SyncOperation syncOperation,
    double pendingDaysDelta = 0,
  });

  Future<void> saveRequest({
    required LeaveRequestModel request,
    double pendingDaysDelta = 0,
  });

  Future<void> mergeRemoteRequests(List<LeaveRequestModel> remoteRequests);

  Future<void> replaceBalances(List<LeaveBalanceModel> balances);

  Future<void> markSynced({
    required String localId,
    String? serverId,
    LeaveApprovalStatus? approvalStatus,
  });

  Future<void> markSyncState({
    required String localId,
    required RecordSyncStatus status,
    String? error,
  });
}

class LeaveLocalDataSourceImpl implements LeaveLocalDataSource {
  LeaveLocalDataSourceImpl({
    required AppDatabase appDatabase,
    required SyncQueueDataSource syncQueueDataSource,
  })  : _appDatabase = appDatabase,
        _syncQueueDataSource = syncQueueDataSource;

  final AppDatabase _appDatabase;
  final SyncQueueDataSource _syncQueueDataSource;

  @override
  Future<List<LeaveRequestModel>> getLeaveRequests(String employeeId) async {
    try {
      final db = await _appDatabase.database;
      final rows = await db.query(
        DbConstants.tableLeaveRequests,
        where: 'employee_id = ?',
        whereArgs: [employeeId],
        orderBy: 'created_at DESC',
      );
      return rows.map(LeaveRequestModel.fromDbMap).toList();
    } catch (e) {
      throw CacheException('Failed to read leave requests.', cause: e);
    }
  }

  @override
  Future<LeaveRequestModel?> getLeaveByLocalId(String localId) async {
    try {
      final db = await _appDatabase.database;
      final rows = await db.query(
        DbConstants.tableLeaveRequests,
        where: 'local_id = ?',
        whereArgs: [localId],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      return LeaveRequestModel.fromDbMap(rows.first);
    } catch (e) {
      throw CacheException('Failed to read leave request.', cause: e);
    }
  }

  @override
  Future<List<LeaveBalanceModel>> getLeaveBalances() async {
    try {
      final db = await _appDatabase.database;
      final rows = await db.query(DbConstants.tableLeaveBalances);
      return rows.map(LeaveBalanceModel.fromDbMap).toList();
    } catch (e) {
      throw CacheException('Failed to read leave balances.', cause: e);
    }
  }

  @override
  Future<void> saveRequestAndEnqueue({
    required LeaveRequestModel request,
    required SyncOperation syncOperation,
    double pendingDaysDelta = 0,
  }) async {
    try {
      final db = await _appDatabase.database;
      await db.transaction((txn) async {
        await txn.insert(
          DbConstants.tableLeaveRequests,
          request.toDbMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );

        if (pendingDaysDelta != 0) {
          await txn.rawUpdate(
            '''
            UPDATE ${DbConstants.tableLeaveBalances}
            SET pending_days = MAX(0, pending_days + ?),
                updated_at = ?
            WHERE leave_type = ?
            ''',
            [
              pendingDaysDelta,
              DateTime.now().toIso8601String(),
              request.leaveType.name,
            ],
          );
        }

        await _syncQueueDataSource.enqueue(syncOperation, executor: txn);
      });
    } catch (e) {
      throw CacheException('Failed to save leave request locally.', cause: e);
    }
  }

  @override
  Future<void> saveRequest({
    required LeaveRequestModel request,
    double pendingDaysDelta = 0,
  }) async {
    try {
      final db = await _appDatabase.database;
      await db.transaction((txn) async {
        await txn.insert(
          DbConstants.tableLeaveRequests,
          request.toDbMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );

        if (pendingDaysDelta != 0) {
          await txn.rawUpdate(
            '''
            UPDATE ${DbConstants.tableLeaveBalances}
            SET pending_days = MAX(0, pending_days + ?),
                updated_at = ?
            WHERE leave_type = ?
            ''',
            [
              pendingDaysDelta,
              DateTime.now().toIso8601String(),
              request.leaveType.name,
            ],
          );
        }
      });
    } catch (e) {
      throw CacheException('Failed to save leave request locally.', cause: e);
    }
  }

  @override
  Future<void> mergeRemoteRequests(
    List<LeaveRequestModel> remoteRequests,
  ) async {
    try {
      final db = await _appDatabase.database;
      await db.transaction((txn) async {
        for (final remote in remoteRequests) {
          final existingRows = await txn.query(
            DbConstants.tableLeaveRequests,
            where: 'local_id = ? OR (server_id IS NOT NULL AND server_id = ?)',
            whereArgs: [remote.localId, remote.serverId ?? ''],
            limit: 1,
          );

          if (existingRows.isNotEmpty) {
            final existing = LeaveRequestModel.fromDbMap(existingRows.first);
            if (existing.needsSync) {
              continue;
            }
          }

          await txn.insert(
            DbConstants.tableLeaveRequests,
            remote.toDbMap(),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      });
    } catch (e) {
      throw CacheException('Failed to cache remote leave requests.', cause: e);
    }
  }

  @override
  Future<void> replaceBalances(List<LeaveBalanceModel> balances) async {
    try {
      final db = await _appDatabase.database;
      await db.transaction((txn) async {
        for (final balance in balances) {
          await txn.insert(
            DbConstants.tableLeaveBalances,
            balance.toDbMap(),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      });
    } catch (e) {
      throw CacheException('Failed to cache leave balances.', cause: e);
    }
  }

  @override
  Future<void> markSynced({
    required String localId,
    String? serverId,
    LeaveApprovalStatus? approvalStatus,
  }) async {
    try {
      final db = await _appDatabase.database;
      await db.update(
        DbConstants.tableLeaveRequests,
        {
          'server_id': ?serverId,
          'approval_status': ?approvalStatus?.name,
          'sync_status': RecordSyncStatus.synced.name,
          'sync_error': null,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'local_id = ?',
        whereArgs: [localId],
      );
    } catch (e) {
      throw CacheException('Failed to mark leave request as synced.', cause: e);
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
        DbConstants.tableLeaveRequests,
        {
          'sync_status': status.name,
          'sync_error': error,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'local_id = ?',
        whereArgs: [localId],
      );
    } catch (e) {
      throw CacheException('Failed to update leave sync status.', cause: e);
    }
  }
}
