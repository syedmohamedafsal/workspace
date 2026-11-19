import 'dart:async';

import 'package:uuid/uuid.dart';

import '../../../../../core/config/app_config.dart';
import '../../../../../core/error/exceptions.dart';
import '../../../../../core/error/failures.dart';
import '../../../../../core/error/result.dart';
import '../../../../../core/location/geo_distance_calculator.dart';
import '../../../../../core/location/location_service.dart';
import '../../../../../core/network/network_info.dart';
import '../../../../../core/sync/sync_manager.dart';
import '../../../../../core/sync/sync_operation.dart';
import '../../../../../core/sync/sync_status.dart';
import '../../../../../core/time/company_clock.dart';
import '../../../../auth/data/datasources/auth_local_datasource.dart';
import '../../domain/entities/attendance_record.dart';
import '../../domain/repositories/attendance_repository.dart';
import '../datasources/attendance_local_datasource.dart';
import '../datasources/attendance_remote_datasource.dart';
import '../models/attendance_record_model.dart';
import '../sync/attendance_sync_handler.dart';

/// Offline-first implementation of [AttendanceRepository] enforcing:
/// - Once-per-company-working-day check-in
/// - Check-out only after check-in (single session per day, no overnight shifts)
/// - In-flight mutex preventing duplicate events from rapid repeated taps
/// - GPS capture and 200-metre office geofence validation
/// - Transactional local write + outbox sync queueing
class AttendanceRepositoryImpl implements AttendanceRepository {
  AttendanceRepositoryImpl({
    required AttendanceLocalDataSource localDataSource,
    required AttendanceRemoteDataSource remoteDataSource,
    required NetworkInfo networkInfo,
    required SyncManager syncManager,
    required LocationService locationService,
    required AppConfig config,
    AuthLocalDataSource? authLocalDataSource,
    CompanyClock? companyClock,
    Uuid? uuid,
  })  : _localDataSource = localDataSource,
        _remoteDataSource = remoteDataSource,
        _networkInfo = networkInfo,
        _syncManager = syncManager,
        _locationService = locationService,
        _config = config,
        _authLocalDataSource = authLocalDataSource,
        _companyClock = companyClock ?? CompanyClock(),
        _uuid = uuid ?? const Uuid();

  final AttendanceLocalDataSource _localDataSource;
  final AttendanceRemoteDataSource _remoteDataSource;
  final NetworkInfo _networkInfo;
  final SyncManager _syncManager;
  final LocationService _locationService;
  final AppConfig _config;
  final AuthLocalDataSource? _authLocalDataSource;
  final CompanyClock _companyClock;
  final Uuid _uuid;

  bool _isMutationInFlight = false;

  Future<
      ({
        String employeeId,
        String officeName,
        double officeLatitude,
        double officeLongitude,
        String companyTimezone,
      })> _resolveEmployeeContext() async {
    final defaults = _config.employeeConfig;
    try {
      final session = await _authLocalDataSource?.getActiveSession();
      if (session != null && session.isValid) {
        final emp = session.employee;
        return (
          employeeId: emp.employeeId,
          officeName: emp.officeName,
          officeLatitude: emp.officeLatitude,
          officeLongitude: emp.officeLongitude,
          companyTimezone: emp.companyTimezone,
        );
      }
    } on CacheException {
      // Fall back safely to configured defaults.
    }

    return (
      employeeId: defaults.employeeId,
      officeName: defaults.officeName,
      officeLatitude: defaults.officeLatitude,
      officeLongitude: defaults.officeLongitude,
      companyTimezone: defaults.companyTimezone,
    );
  }

  @override
  Future<Result<AttendanceRecord?>> getTodayAttendance() async {
    try {
      final ctx = await _resolveEmployeeContext();
      final today = _companyClock.workingDate(ctx.companyTimezone);
      final record = await _localDataSource.getAttendanceByDate(
        ctx.employeeId,
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
      final ctx = await _resolveEmployeeContext();
      if (refreshRemote && await _networkInfo.isConnected) {
        try {
          final remoteRecords = await _remoteDataSource.fetchHistory(
            employeeId: ctx.employeeId,
            limit: limit,
          );
          await _localDataSource.mergeRemoteRecords(remoteRecords);
        } on AppException {
          // Offline-first resilience: fall back gracefully to local cache.
        }
      }

      final localRecords = await _localDataSource.getAttendanceHistory(
        ctx.employeeId,
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
    if (_isMutationInFlight) {
      return const FailureResult(
        ValidationFailure('An attendance action is already in progress.'),
      );
    }

    _isMutationInFlight = true;
    try {
      final ctx = await _resolveEmployeeContext();
      final today = _companyClock.workingDate(ctx.companyTimezone);

      // 1. Pre-check daily uniqueness before invoking GPS
      final existingBeforeGps = await _localDataSource.getAttendanceByDate(
        ctx.employeeId,
        today,
      );
      if (existingBeforeGps != null && existingBeforeGps.checkInAt != null) {
        return const FailureResult(
          ValidationFailure('You have already checked in for today.'),
        );
      }

      // 2. Capture current GPS coordinates (handles denied / permanently denied / unavailable)
      final locationResult = await _locationService.getCurrentLocation(
        officeLatitude: ctx.officeLatitude,
        officeLongitude: ctx.officeLongitude,
      );
      if (locationResult.isFailure) {
        return FailureResult(locationResult.failureOrNull!);
      }
      final coord = locationResult.dataOrNull!;

      // 3. Enforce 200m office geofence
      final distanceMeters = GeoDistanceCalculator.distanceInMeters(
        startLatitude: coord.latitude,
        startLongitude: coord.longitude,
        endLatitude: ctx.officeLatitude,
        endLongitude: ctx.officeLongitude,
      );
      if (distanceMeters > _config.allowedAttendanceRadiusMeters) {
        return FailureResult(
          OutsideGeofenceFailure(
            distanceMeters: distanceMeters,
            allowedRadiusMeters: _config.allowedAttendanceRadiusMeters,
            officeName: ctx.officeName,
          ),
        );
      }

      // 4. Re-check persisted state right before writing to prevent races
      final existingAfterGps = await _localDataSource.getAttendanceByDate(
        ctx.employeeId,
        today,
      );
      if (existingAfterGps != null && existingAfterGps.checkInAt != null) {
        return const FailureResult(
          ValidationFailure('You have already checked in for today.'),
        );
      }

      final now = _companyClock.nowUtc();
      final record = AttendanceRecordModel(
        localId: existingAfterGps?.localId ?? _uuid.v4(),
        serverId: existingAfterGps?.serverId,
        employeeId: ctx.employeeId,
        date: today,
        checkInAt: now,
        checkInNote: note?.trim().isEmpty ?? true ? null : note!.trim(),
        workLocation: workLocation?.trim().isEmpty ?? true
            ? ctx.officeName
            : workLocation!.trim(),
        checkInLatitude: coord.latitude,
        checkInLongitude: coord.longitude,
        checkInDistanceMeters: distanceMeters,
        status: AttendanceStatus.checkedIn,
        syncStatus: RecordSyncStatus.pending,
        createdAt: existingAfterGps?.createdAt ?? now,
        updatedAt: now,
      );

      final idempotencyKey = _uuid.v4();
      final operation = SyncOperation(
        id: _uuid.v4(),
        entityType: AttendanceSyncHandler.kEntityType,
        entityId: record.localId,
        operationType: AttendanceSyncHandler.kOpCheckIn,
        payload: record.toCheckInPayload(
          companyTimezone: ctx.companyTimezone,
          eventId: idempotencyKey,
        ),
        idempotencyKey: idempotencyKey,
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
    } finally {
      _isMutationInFlight = false;
    }
  }

  @override
  Future<Result<AttendanceRecord>> checkOut({String? note}) async {
    if (_isMutationInFlight) {
      return const FailureResult(
        ValidationFailure('An attendance action is already in progress.'),
      );
    }

    _isMutationInFlight = true;
    try {
      final ctx = await _resolveEmployeeContext();
      final today = _companyClock.workingDate(ctx.companyTimezone);

      // 1. Check-out is permitted only after check-in for today's working day
      final existing = await _localDataSource.getAttendanceByDate(
        ctx.employeeId,
        today,
      );
      if (existing == null || existing.checkInAt == null) {
        return const FailureResult(
          ValidationFailure('Check-out is permitted only after checking in.'),
        );
      }
      if (existing.checkOutAt != null) {
        return const FailureResult(
          ValidationFailure('You have already checked out for today.'),
        );
      }

      // 2. Capture GPS coordinates
      final locationResult = await _locationService.getCurrentLocation(
        officeLatitude: ctx.officeLatitude,
        officeLongitude: ctx.officeLongitude,
      );
      if (locationResult.isFailure) {
        return FailureResult(locationResult.failureOrNull!);
      }
      final coord = locationResult.dataOrNull!;

      // 3. Enforce 200m office geofence
      final distanceMeters = GeoDistanceCalculator.distanceInMeters(
        startLatitude: coord.latitude,
        startLongitude: coord.longitude,
        endLatitude: ctx.officeLatitude,
        endLongitude: ctx.officeLongitude,
      );
      if (distanceMeters > _config.allowedAttendanceRadiusMeters) {
        return FailureResult(
          OutsideGeofenceFailure(
            distanceMeters: distanceMeters,
            allowedRadiusMeters: _config.allowedAttendanceRadiusMeters,
            officeName: ctx.officeName,
          ),
        );
      }

      final now = _companyClock.nowUtc();
      final updated = AttendanceRecordModel.fromEntity(
        existing.copyWith(
          checkOutAt: now,
          checkOutNote: note?.trim().isEmpty ?? true ? null : note!.trim(),
          checkOutLatitude: coord.latitude,
          checkOutLongitude: coord.longitude,
          checkOutDistanceMeters: distanceMeters,
          status: AttendanceStatus.checkedOut,
          syncStatus: RecordSyncStatus.pending,
          clearSyncError: true,
          updatedAt: now,
        ),
      );

      final idempotencyKey = _uuid.v4();
      final operation = SyncOperation(
        id: _uuid.v4(),
        entityType: AttendanceSyncHandler.kEntityType,
        entityId: updated.localId,
        operationType: AttendanceSyncHandler.kOpCheckOut,
        payload: updated.toCheckOutPayload(
          companyTimezone: ctx.companyTimezone,
          eventId: idempotencyKey,
        ),
        idempotencyKey: idempotencyKey,
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
    } finally {
      _isMutationInFlight = false;
    }
  }

  @override
  Future<Result<void>> resetTodayAttendance() async {
    try {
      final ctx = await _resolveEmployeeContext();
      final workingDate = _companyClock.workingDate(ctx.companyTimezone);
      await _localDataSource.clearTodayAttendance(
        employeeId: ctx.employeeId,
        date: workingDate,
      );
      return const Success(null);
    } catch (e) {
      return FailureResult(CacheFailure('Failed to reset attendance: $e'));
    }
  }
}
