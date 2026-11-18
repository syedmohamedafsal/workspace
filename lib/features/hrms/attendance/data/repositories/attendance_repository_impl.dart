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
import '../../domain/entities/attendance_record.dart';
import '../../domain/repositories/attendance_repository.dart';
import '../datasources/attendance_local_datasource.dart';
import '../datasources/attendance_remote_datasource.dart';
import '../models/attendance_record_model.dart';
import '../sync/attendance_sync_handler.dart';

/// Offline-first implementation of [AttendanceRepository].
///
/// All writes commit locally + enqueue a durable outbox operation first, so the
/// employee experiences instant, reliable check-in/out regardless of network state.
class AttendanceRepositoryImpl implements AttendanceRepository {
  AttendanceRepositoryImpl({
    required AttendanceLocalDataSource localDataSource,
    required AttendanceRemoteDataSource remoteDataSource,
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

  final AttendanceLocalDataSource _localDataSource;
  final AttendanceRemoteDataSource _remoteDataSource;
  final NetworkInfo _networkInfo;
  final SyncManager _syncManager;
  final AppConfig _config;
  final Uuid _uuid;
  final DateTime Function() _clock;

  @override
  Future<Result<AttendanceRecord?>> getTodayAttendance() async {
    try {
      final now = _clock();
      final today = DateTime(now.year, now.month, now.day);
      final record = await _localDataSource.getAttendanceByDate(
        _config.defaultEmployeeId,
        today,
      );
      return Success(record);
    } on CacheException catch (e) {
      return FailureResult(CacheFailure(e.message));
    } catch (e) {
      return FailureResult(UnexpectedFailure(e.toString()));
    }
  }

  @override
  Future<Result<List<AttendanceRecord>>> getAttendanceHistory({
    int limit = 30,
    bool refreshRemote = false,
  }) async {
    try {
      if (refreshRemote && await _networkInfo.isConnected) {
        try {
          final remoteRecords = await _remoteDataSource.fetchHistory(
            employeeId: _config.defaultEmployeeId,
            limit: limit,
          );
          await _localDataSource.mergeRemoteRecords(remoteRecords);
        } on AppException {
          // Offline-first resilience: fall back gracefully to local cache.
        }
      }

      final localRecords = await _localDataSource.getAttendanceHistory(
        _config.defaultEmployeeId,
        limit: limit,
      );
      return Success(localRecords);
    } on CacheException catch (e) {
      return FailureResult(CacheFailure(e.message));
    } catch (e) {
      return FailureResult(UnexpectedFailure(e.toString()));
    }
  }

  @override
  Future<Result<AttendanceRecord>> checkIn({
    String? workLocation,
    String? note,
  }) async {
    try {
      final now = _clock();
      final today = DateTime(now.year, now.month, now.day);
      final existing = await _localDataSource.getAttendanceByDate(
        _config.defaultEmployeeId,
        today,
      );

      if (existing != null && existing.checkInAt != null) {
        return const FailureResult(
          ValidationFailure('You have already checked in today.'),
        );
      }

      final record = AttendanceRecordModel(
        localId: existing?.localId ?? _uuid.v4(),
        serverId: existing?.serverId,
        employeeId: _config.defaultEmployeeId,
        date: today,
        checkInAt: now,
        checkInNote: note?.trim().isEmpty ?? true ? null : note!.trim(),
        workLocation:
            workLocation?.trim().isEmpty ?? true ? 'Office' : workLocation!.trim(),
        status: AttendanceStatus.checkedIn,
        syncStatus: RecordSyncStatus.pending,
        createdAt: existing?.createdAt ?? now,
        updatedAt: now,
      );

      final operation = SyncOperation(
        id: _uuid.v4(),
        entityType: AttendanceSyncHandler.kEntityType,
        entityId: record.localId,
        operationType: AttendanceSyncHandler.kOpCheckIn,
        payload: record.toCheckInPayload(),
        idempotencyKey: _uuid.v4(),
        status: SyncQueueStatus.pending,
        retryCount: 0,
        createdAt: now,
        updatedAt: now,
      );

      await _localDataSource.saveAndEnqueue(
        record: record,
        syncOperation: operation,
      );
      unawaited(_syncManager.notifyQueueChanged());

      return Success(record);
    } on CacheException catch (e) {
      return FailureResult(CacheFailure(e.message));
    } catch (e) {
      return FailureResult(UnexpectedFailure(e.toString()));
    }
  }

  @override
  Future<Result<AttendanceRecord>> checkOut({String? note}) async {
    try {
      final now = _clock();
      final today = DateTime(now.year, now.month, now.day);
      final existing = await _localDataSource.getAttendanceByDate(
        _config.defaultEmployeeId,
        today,
      );

      if (existing == null || existing.checkInAt == null) {
        return const FailureResult(
          ValidationFailure('Please check in before checking out.'),
        );
      }
      if (existing.checkOutAt != null) {
        return const FailureResult(
          ValidationFailure('You have already checked out for today.'),
        );
      }

      final updated = AttendanceRecordModel.fromEntity(
        existing.copyWith(
          checkOutAt: now,
          checkOutNote: note?.trim().isEmpty ?? true ? null : note!.trim(),
          status: AttendanceStatus.checkedOut,
          syncStatus: RecordSyncStatus.pending,
          clearSyncError: true,
          updatedAt: now,
        ),
      );

      final operation = SyncOperation(
        id: _uuid.v4(),
        entityType: AttendanceSyncHandler.kEntityType,
        entityId: updated.localId,
        operationType: AttendanceSyncHandler.kOpCheckOut,
        payload: updated.toCheckOutPayload(),
        idempotencyKey: _uuid.v4(),
        status: SyncQueueStatus.pending,
        retryCount: 0,
        createdAt: now,
        updatedAt: now,
      );

      await _localDataSource.saveAndEnqueue(
        record: updated,
        syncOperation: operation,
      );
      unawaited(_syncManager.notifyQueueChanged());

      return Success(updated);
    } on CacheException catch (e) {
      return FailureResult(CacheFailure(e.message));
    } catch (e) {
      return FailureResult(UnexpectedFailure(e.toString()));
    }
  }
}
