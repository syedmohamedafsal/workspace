import '../../../../../core/error/exceptions.dart';
import '../../../../../core/sync/sync_handler.dart';
import '../../../../../core/sync/sync_operation.dart';
import '../../../../../core/sync/sync_status.dart';
import '../datasources/attendance_local_datasource.dart';
import '../datasources/attendance_remote_datasource.dart';
import '../models/attendance_record_model.dart';

/// Synchronizes queued HRMS attendance check-in and check-out mutations.
class AttendanceSyncHandler implements SyncHandler {
  AttendanceSyncHandler({
    required AttendanceLocalDataSource localDataSource,
    required AttendanceRemoteDataSource remoteDataSource,
  })  : _localDataSource = localDataSource,
        _remoteDataSource = remoteDataSource;

  static const String kEntityType = 'hrms.attendance';
  static const String kOpCheckIn = 'check_in';
  static const String kOpCheckOut = 'check_out';

  final AttendanceLocalDataSource _localDataSource;
  final AttendanceRemoteDataSource _remoteDataSource;

  @override
  String get entityType => kEntityType;

  @override
  Future<void> handleOperation(SyncOperation operation) async {
    await _localDataSource.markSyncState(
      localId: operation.entityId,
      status: RecordSyncStatus.syncing,
    );

    if (operation.operationType == kOpCheckIn) {
      final synced = await _remoteDataSource.sendCheckIn(
        payload: operation.payload,
        idempotencyKey: operation.idempotencyKey,
      );
      await _localDataSource.markSynced(
        localId: operation.entityId,
        serverId: synced.serverId,
      );
      return;
    }

    if (operation.operationType == kOpCheckOut) {
      // Attach the latest serverId if check-in synced right before this op.
      final localRecord = await _localDataSource.getByLocalId(operation.entityId);
      final payload = Map<String, dynamic>.from(operation.payload);
      if (localRecord?.serverId != null) {
        payload['server_id'] = localRecord!.serverId;
      }

      final synced = await _remoteDataSource.sendCheckOut(
        payload: payload,
        idempotencyKey: operation.idempotencyKey,
      );
      await _localDataSource.markSynced(
        localId: operation.entityId,
        serverId: synced.serverId,
      );
      return;
    }

    throw ValidationException(
      'Unsupported attendance sync operation: ${operation.operationType}',
    );
  }

  @override
  Future<void> onConflict(
    SyncOperation operation,
    ConflictException exception,
  ) async {
    // Timeout-after-accept reconciliation:
    // If the server rejected with 409 because attendance already exists, check
    // if this operation was a retry where the server actually accepted and created
    // the record on the previous flight before the client timed out.
    if (operation.retryCount > 0) {
      try {
        final employeeId = operation.payload['employee_id'] as String? ?? '';
        final history = await _remoteDataSource.fetchHistory(
          employeeId: employeeId,
          limit: 5,
        );
        final dateKey = operation.payload['date'] as String? ??
            operation.payload['attendance_date'] as String?;
        final matched = history.where((r) {
          final rDateKey = AttendanceRecordModel.formatDateKey(r.date);
          return rDateKey == dateKey && r.employeeId == employeeId;
        }).firstOrNull;

        if (matched != null) {
          // Reconciled: server had accepted the event before the timeout!
          await _localDataSource.markSynced(
            localId: operation.entityId,
            serverId: matched.serverId,
          );
          return;
        }
      } catch (_) {
        // Fallback to recording conflict if reconciliation check fails
      }
    }

    await _localDataSource.markSyncState(
      localId: operation.entityId,
      status: RecordSyncStatus.conflict,
      error: exception.message,
    );
  }

  @override
  Future<void> onPermanentFailure(
    SyncOperation operation,
    String errorMessage,
  ) async {
    await _localDataSource.markSyncState(
      localId: operation.entityId,
      status: RecordSyncStatus.failed,
      error: errorMessage,
    );
  }
}
