import '../../../../../core/error/exceptions.dart';
import '../../../../../core/sync/sync_handler.dart';
import '../../../../../core/sync/sync_operation.dart';
import '../../../../../core/sync/sync_status.dart';
import '../datasources/attendance_local_datasource.dart';
import '../datasources/attendance_remote_datasource.dart';

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
