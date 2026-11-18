import 'dart:async';

import 'package:uuid/uuid.dart';

import '../../../../../core/config/app_config.dart';
import '../../../../../core/error/exceptions.dart';
import '../../../../../core/error/failures.dart';
import '../../../../../core/error/result.dart';
import '../../../../../core/network/network_info.dart';
import '../../../../../core/sync/sync_manager.dart';
import '../../../../../core/sync/sync_operation.dart';
import '../../../../../core/sync/sync_status.dart';
import '../../domain/entities/leave_balance.dart';
import '../../domain/entities/leave_request.dart';
import '../../domain/repositories/leave_repository.dart';
import '../datasources/leave_local_datasource.dart';
import '../datasources/leave_remote_datasource.dart';
import '../models/leave_request_model.dart';
import '../sync/leave_sync_handler.dart';

/// Offline-first implementation of [LeaveRepository].
class LeaveRepositoryImpl implements LeaveRepository {
  LeaveRepositoryImpl({
    required LeaveLocalDataSource localDataSource,
    required LeaveRemoteDataSource remoteDataSource,
    required NetworkInfo networkInfo,
    required SyncManager syncManager,
    required AppConfig config,
    Uuid? uuid,
    DateTime Function()? clock,
  })  : _localDataSource = localDataSource,
        _remoteDataSource = remoteDataSource,
        _networkInfo = networkInfo,
        _syncManager = syncManager,
        _config = config,
        _uuid = uuid ?? const Uuid(),
        _clock = clock ?? DateTime.now;

  final LeaveLocalDataSource _localDataSource;
  final LeaveRemoteDataSource _remoteDataSource;
  final NetworkInfo _networkInfo;
  final SyncManager _syncManager;
  final AppConfig _config;
  final Uuid _uuid;
  final DateTime Function() _clock;

  @override
  Future<Result<List<LeaveRequest>>> getLeaveRequests({
    bool refreshRemote = false,
  }) async {
    try {
      if (refreshRemote && await _networkInfo.isConnected) {
        try {
          final remote = await _remoteDataSource.fetchLeaveRequests(
            _config.defaultEmployeeId,
          );
          await _localDataSource.mergeRemoteRequests(remote);
        } on AppException {
          // Serve local cache seamlessly when remote is unavailable.
        }
      }

      final requests = await _localDataSource.getLeaveRequests(
        _config.defaultEmployeeId,
      );
      return Success(requests);
    } on CacheException catch (e) {
      return FailureResult(CacheFailure(e.message));
    } catch (e) {
      return FailureResult(UnexpectedFailure(e.toString()));
    }
  }

  @override
  Future<Result<List<LeaveBalance>>> getLeaveBalances({
    bool refreshRemote = false,
  }) async {
    try {
      if (refreshRemote && await _networkInfo.isConnected) {
        try {
          final remote = await _remoteDataSource.fetchLeaveBalances(
            _config.defaultEmployeeId,
          );
          if (remote.isNotEmpty) {
            await _localDataSource.replaceBalances(remote);
          }
        } on AppException {
          // Fall back to cached balances.
        }
      }

      final balances = await _localDataSource.getLeaveBalances();
      return Success(balances);
    } on CacheException catch (e) {
      return FailureResult(CacheFailure(e.message));
    } catch (e) {
      return FailureResult(UnexpectedFailure(e.toString()));
    }
  }

  @override
  Future<Result<LeaveRequest>> applyLeave({
    required LeaveType leaveType,
    required DateTime startDate,
    required DateTime endDate,
    required bool isHalfDay,
    required String reason,
  }) async {
    try {
      final now = _clock();
      final request = LeaveRequestModel(
        localId: _uuid.v4(),
        employeeId: _config.defaultEmployeeId,
        leaveType: leaveType,
        startDate: startDate,
        endDate: endDate,
        isHalfDay: isHalfDay,
        reason: reason,
        approvalStatus: LeaveApprovalStatus.pending,
        syncStatus: RecordSyncStatus.pending,
        createdAt: now,
        updatedAt: now,
      );

      final operation = SyncOperation(
        id: _uuid.v4(),
        entityType: LeaveSyncHandler.kEntityType,
        entityId: request.localId,
        operationType: LeaveSyncHandler.kOpApplyLeave,
        payload: request.toApiPayload(),
        idempotencyKey: _uuid.v4(),
        status: SyncQueueStatus.pending,
        retryCount: 0,
        createdAt: now,
        updatedAt: now,
      );

      await _localDataSource.saveRequestAndEnqueue(
        request: request,
        syncOperation: operation,
        pendingDaysDelta: request.requestedDays,
      );
      unawaited(_syncManager.notifyQueueChanged());

      return Success(request);
    } on CacheException catch (e) {
      return FailureResult(CacheFailure(e.message));
    } catch (e) {
      return FailureResult(UnexpectedFailure(e.toString()));
    }
  }

  @override
  Future<Result<LeaveRequest>> cancelLeave(String localId) async {
    try {
      final existing = await _localDataSource.getLeaveByLocalId(localId);
      if (existing == null) {
        return const FailureResult(
          ValidationFailure('Leave request not found.'),
        );
      }
      if (!existing.canCancel) {
        return const FailureResult(
          ValidationFailure('Only pending leave requests can be cancelled.'),
        );
      }

      final now = _clock();
      final cancelled = LeaveRequestModel.fromEntity(
        existing.copyWith(
          approvalStatus: LeaveApprovalStatus.cancelled,
          syncStatus: RecordSyncStatus.pending,
          clearSyncError: true,
          updatedAt: now,
        ),
      );

      final operation = SyncOperation(
        id: _uuid.v4(),
        entityType: LeaveSyncHandler.kEntityType,
        entityId: cancelled.localId,
        operationType: LeaveSyncHandler.kOpCancelLeave,
        payload: {
          'client_id': cancelled.localId,
          'server_id': cancelled.serverId,
        },
        idempotencyKey: _uuid.v4(),
        status: SyncQueueStatus.pending,
        retryCount: 0,
        createdAt: now,
        updatedAt: now,
      );

      await _localDataSource.saveRequestAndEnqueue(
        request: cancelled,
        syncOperation: operation,
        pendingDaysDelta: -existing.requestedDays,
      );
      unawaited(_syncManager.notifyQueueChanged());

      return Success(cancelled);
    } on CacheException catch (e) {
      return FailureResult(CacheFailure(e.message));
    } catch (e) {
      return FailureResult(UnexpectedFailure(e.toString()));
    }
  }
}
