import '../../../../../core/error/exceptions.dart';
import '../../../../../core/sync/sync_handler.dart';
import '../../../../../core/sync/sync_operation.dart';
import '../../../../../core/sync/sync_status.dart';
import '../datasources/leave_local_datasource.dart';
import '../datasources/leave_remote_datasource.dart';

/// Synchronizes queued HRMS leave applications and cancellations.
class LeaveSyncHandler implements SyncHandler {
  LeaveSyncHandler({
    required LeaveLocalDataSource localDataSource,
    required LeaveRemoteDataSource remoteDataSource,
  })  : _localDataSource = localDataSource,
        _remoteDataSource = remoteDataSource;

  static const String kEntityType = 'hrms.leave';
  static const String kOpApplyLeave = 'apply_leave';
  static const String kOpCancelLeave = 'cancel_leave';

  final LeaveLocalDataSource _localDataSource;
  final LeaveRemoteDataSource _remoteDataSource;

  @override
  String get entityType => kEntityType;

  @override
  Future<void> handleOperation(SyncOperation operation) async {
    await _localDataSource.markSyncState(
      localId: operation.entityId,
      status: RecordSyncStatus.syncing,
    );

    if (operation.operationType == kOpApplyLeave) {
      final synced = await _remoteDataSource.submitLeave(
        payload: operation.payload,
        idempotencyKey: operation.idempotencyKey,
      );
      await _localDataSource.markSynced(
        localId: operation.entityId,
        serverId: synced.serverId,
        approvalStatus: synced.approvalStatus,
      );
      return;
    }

    if (operation.operationType == kOpCancelLeave) {
      final local = await _localDataSource.getLeaveByLocalId(operation.entityId);
      final targetId = local?.serverId ??
          (operation.payload['server_id'] as String?) ??
          operation.entityId;

      final synced = await _remoteDataSource.cancelLeave(
        serverOrClientId: targetId,
        idempotencyKey: operation.idempotencyKey,
      );
      await _localDataSource.markSynced(
        localId: operation.entityId,
        serverId: synced.serverId ?? local?.serverId,
        approvalStatus: synced.approvalStatus,
      );
      return;
    }

    throw ValidationException(
      'Unsupported leave sync operation: ${operation.operationType}',
    );
  }

  @override
  Future<void> onConflict(
    SyncOperation operation,
    ConflictException exception,
  ) async {
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
