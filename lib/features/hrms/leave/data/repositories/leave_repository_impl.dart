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
      // 1. Connectivity requirement: Leave submission requires connectivity
      final isConnected = await _networkInfo.isConnected;
      if (!isConnected) {
        return const FailureResult(
          NetworkFailure(
            'Leave submission requires an active internet connection. Previously loaded requests remain viewable offline.',
          ),
        );
      }

      final localId = _uuid.v4();
      final idempotencyKey = _uuid.v4();

      final payload = {
        'client_id': localId,
        'employee_id': _config.defaultEmployeeId,
        'leave_type': leaveType.name,
        'start_date': LeaveRequestModel.formatDateKey(startDate),
        'end_date': LeaveRequestModel.formatDateKey(endDate),
        'is_half_day': isHalfDay,
        'reason': reason,
      };

      // 2. Submit directly to remote server with idempotency key
      final remoteCreated = await _remoteDataSource.submitLeave(
        payload: payload,
        idempotencyKey: idempotencyKey,
      );

      // 3. Persist the successfully created leave request locally for offline viewing
      await _localDataSource.saveRequest(
        request: remoteCreated,
        pendingDaysDelta: remoteCreated.requestedDays,
      );

      return Success(remoteCreated);
    } on ValidationException catch (e) {
      // Handle server-side validation rejection (e.g. HTTP 422 Unprocessable Entity)
      return FailureResult(ValidationFailure(e.message));
    } on ServerException catch (e) {
      return FailureResult(ServerFailure(e.message));
    } on NetworkException catch (e) {
      return FailureResult(NetworkFailure(e.message));
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
