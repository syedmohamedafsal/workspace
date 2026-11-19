import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rebs/core/config/app_config.dart';
import 'package:rebs/core/database/app_database.dart';
import 'package:rebs/core/error/exceptions.dart';
import 'package:rebs/core/error/failures.dart';
import 'package:rebs/core/network/network_info.dart';
import 'package:rebs/core/sync/sync_manager.dart';
import 'package:rebs/core/sync/sync_queue_datasource.dart';
import 'package:rebs/core/sync/sync_status.dart';
import 'package:rebs/core/time/company_clock.dart';
import 'package:rebs/features/hrms/leave/data/datasources/leave_local_datasource.dart';
import 'package:rebs/features/hrms/leave/data/datasources/leave_remote_datasource.dart';
import 'package:rebs/features/hrms/leave/data/models/leave_request_model.dart';
import 'package:rebs/features/hrms/leave/data/repositories/leave_repository_impl.dart';
import 'package:rebs/features/hrms/leave/data/sync/leave_sync_handler.dart';
import 'package:rebs/features/hrms/leave/domain/entities/leave_request.dart';
import 'package:rebs/features/hrms/leave/domain/usecases/apply_leave.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class MockLeaveRemoteDataSource extends Mock implements LeaveRemoteDataSource {}

class ToggleNetworkInfo implements NetworkInfo {
  bool connected = false;
  final StreamController<bool> _controller = StreamController<bool>.broadcast();

  @override
  Future<bool> get isConnected async => connected;

  @override
  Stream<bool> get onStatusChange => _controller.stream;

  void goOnline() {
    connected = true;
    _controller.add(true);
  }

  void goOffline() {
    connected = false;
    _controller.add(false);
  }

  Future<void> dispose() => _controller.close();
}

void main() {
  sqfliteFfiInit();

  late AppDatabase db;
  late SyncQueueDataSource queueDataSource;
  late LeaveLocalDataSourceImpl localDataSource;
  late MockLeaveRemoteDataSource remoteDataSource;
  late ToggleNetworkInfo networkInfo;
  late SyncManager syncManager;
  late LeaveRepositoryImpl repository;
  late CompanyClock companyClock;
  late ApplyLeave applyLeave;
  late DateTime simulatedToday;

  setUp(() async {
    // Simulated company clock: 20 Nov 2026
    simulatedToday = DateTime.utc(2026, 11, 20, 4, 30); // 10:00 IST
    companyClock = CompanyClock(utcClock: () => simulatedToday);

    db = AppDatabase(
      databaseFactoryOverride: databaseFactoryFfi,
      pathOverride: inMemoryDatabasePath,
    );
    queueDataSource = SyncQueueDataSource(db);
    localDataSource = LeaveLocalDataSourceImpl(
      appDatabase: db,
      syncQueueDataSource: queueDataSource,
    );
    remoteDataSource = MockLeaveRemoteDataSource();
    networkInfo = ToggleNetworkInfo();
    const config = AppConfig();

    syncManager = SyncManager(
      queueDataSource: queueDataSource,
      networkInfo: networkInfo,
      config: config,
      clock: () => simulatedToday,
    );
    syncManager.registerHandler(
      LeaveSyncHandler(
        localDataSource: localDataSource,
        remoteDataSource: remoteDataSource,
      ),
    );
    await syncManager.initialize();

    repository = LeaveRepositoryImpl(
      localDataSource: localDataSource,
      remoteDataSource: remoteDataSource,
      networkInfo: networkInfo,
      syncManager: syncManager,
      config: config,
      clock: () => simulatedToday,
    );

    applyLeave = ApplyLeave(
      repository: repository,
      companyClock: companyClock,
      config: config,
    );
  });

  tearDown(() async {
    await syncManager.dispose();
    await networkInfo.dispose();
    await db.close();
  });

  group('Section 4 Leave Validation Rules', () {
    test('rejects leave types other than Casual or Sick', () async {
      final result = await applyLeave(
        ApplyLeaveParams(
          leaveType: LeaveType.annual,
          startDate: DateTime(2026, 11, 22),
          endDate: DateTime(2026, 11, 23),
          reason: 'Taking annual break for vacation',
        ),
      );

      expect(result.isFailure, isTrue);
      expect(result.failureOrNull, isA<ValidationFailure>());
      expect(
        result.failureOrNull!.message,
        contains('Only Casual and Sick leave types are permitted'),
      );
    });

    test('rejects start date earlier than current company date', () async {
      final result = await applyLeave(
        ApplyLeaveParams(
          leaveType: LeaveType.casual,
          startDate: DateTime(2026, 11, 19), // Past date
          endDate: DateTime(2026, 11, 22),
          reason: 'Need leave for personal family event',
        ),
      );

      expect(result.isFailure, isTrue);
      expect(result.failureOrNull, isA<ValidationFailure>());
      expect(
        result.failureOrNull!.message,
        contains('Start date cannot be before the current company date'),
      );
    });

    test('rejects end date before start date', () async {
      final result = await applyLeave(
        ApplyLeaveParams(
          leaveType: LeaveType.casual,
          startDate: DateTime(2026, 11, 25),
          endDate: DateTime(2026, 11, 23), // End earlier than start
          reason: 'Need leave for personal family event',
        ),
      );

      expect(result.isFailure, isTrue);
      expect(result.failureOrNull, isA<ValidationFailure>());
      expect(
        result.failureOrNull!.message,
        contains('End date cannot be before the start date'),
      );
    });

    test('rejects reasons with fewer than 10 non-whitespace characters', () async {
      final result = await applyLeave(
        ApplyLeaveParams(
          leaveType: LeaveType.sick,
          startDate: DateTime(2026, 11, 22),
          endDate: DateTime(2026, 11, 22),
          reason: '   Cold   ', // Only 4 non-whitespace chars
        ),
      );

      expect(result.isFailure, isTrue);
      expect(result.failureOrNull, isA<ValidationFailure>());
      expect(
        result.failureOrNull!.message,
        contains('10 non-whitespace characters'),
      );
    });

    test('rejects requested calendar days exceeding available balance', () async {
      // Default seeded casual leave balance is 6 total - 1 used = 5 remaining
      final result = await applyLeave(
        ApplyLeaveParams(
          leaveType: LeaveType.casual,
          startDate: DateTime(2026, 11, 22),
          endDate: DateTime(2026, 11, 28), // 7 calendar days requested
          reason: 'Attending long family wedding celebration',
        ),
      );

      expect(result.isFailure, isTrue);
      expect(result.failureOrNull, isA<ValidationFailure>());
      expect(
        result.failureOrNull!.message,
        contains('exceed available balance'),
      );
    });

    test('rejects leave dates overlapping an existing Pending or Approved request',
        () async {
      // Pre-populate an existing pending leave request for Nov 24 - Nov 26
      await localDataSource.saveRequest(
        request: LeaveRequestModel(
          localId: 'req-existing-1',
          employeeId: const AppConfig().defaultEmployeeId,
          leaveType: LeaveType.casual,
          startDate: DateTime(2026, 11, 24),
          endDate: DateTime(2026, 11, 26),
          isHalfDay: false,
          reason: 'Existing booked leave request',
          approvalStatus: LeaveApprovalStatus.pending,
          syncStatus: RecordSyncStatus.synced,
          createdAt: simulatedToday,
          updatedAt: simulatedToday,
        ),
      );

      // Overlapping request: Nov 25 - Nov 27
      final result = await applyLeave(
        ApplyLeaveParams(
          leaveType: LeaveType.sick,
          startDate: DateTime(2026, 11, 25),
          endDate: DateTime(2026, 11, 27),
          reason: 'High fever and viral infection recovery',
        ),
      );

      expect(result.isFailure, isTrue);
      expect(result.failureOrNull, isA<ValidationFailure>());
      expect(
        result.failureOrNull!.message,
        contains('overlap with an existing Pending or Approved leave request'),
      );
    });
  });

  group('Section 4 Connectivity and Server Validation Rules', () {
    test(
        'rejects leave submission when offline and informs user connectivity is required',
        () async {
      networkInfo.goOffline();

      final result = await applyLeave(
        ApplyLeaveParams(
          leaveType: LeaveType.sick,
          startDate: DateTime(2026, 11, 22),
          endDate: DateTime(2026, 11, 23),
          reason: 'Under doctor care for severe migraine',
        ),
      );

      expect(result.isFailure, isTrue);
      expect(result.failureOrNull, isA<NetworkFailure>());
      expect(
        result.failureOrNull!.message,
        contains('Leave submission requires an active internet connection'),
      );
    });

    test(
        'submits successfully when online, persists locally for offline viewing, and deducts balance',
        () async {
      networkInfo.goOnline();

      when(
        () => remoteDataSource.submitLeave(
          payload: any(named: 'payload'),
          idempotencyKey: any(named: 'idempotencyKey'),
        ),
      ).thenAnswer(
        (_) async => LeaveRequestModel(
          localId: 'req-srv-101',
          serverId: 'srv-leave-101',
          employeeId: const AppConfig().defaultEmployeeId,
          leaveType: LeaveType.sick,
          startDate: DateTime(2026, 11, 22),
          endDate: DateTime(2026, 11, 23),
          isHalfDay: false,
          reason: 'Under doctor care for severe migraine',
          approvalStatus: LeaveApprovalStatus.pending,
          syncStatus: RecordSyncStatus.synced,
          createdAt: simulatedToday,
          updatedAt: simulatedToday,
        ),
      );

      final result = await applyLeave(
        ApplyLeaveParams(
          leaveType: LeaveType.sick,
          startDate: DateTime(2026, 11, 22),
          endDate: DateTime(2026, 11, 23), // 2 calendar days
          reason: 'Under doctor care for severe migraine',
        ),
      );

      expect(result.isSuccess, isTrue);
      final created = result.dataOrNull!;
      expect(created.serverId, 'srv-leave-101');
      expect(created.requestedDays, 2.0);

      // Verify it remains viewable offline
      networkInfo.goOffline();
      final offlineRequests = await repository.getLeaveRequests();
      expect(offlineRequests.isSuccess, isTrue);
      expect(offlineRequests.dataOrNull!.any((r) => r.serverId == 'srv-leave-101'), isTrue);
    });

    test(
        'handles server-side validation error (HTTP 422) even when local validation passes',
        () async {
      networkInfo.goOnline();

      when(
        () => remoteDataSource.submitLeave(
          payload: any(named: 'payload'),
          idempotencyKey: any(named: 'idempotencyKey'),
        ),
      ).thenThrow(
        const ValidationException(
          'Department quota exceeded: No more sick leaves permitted this quarter.',
        ),
      );

      final result = await applyLeave(
        ApplyLeaveParams(
          leaveType: LeaveType.sick,
          startDate: DateTime(2026, 11, 22),
          endDate: DateTime(2026, 11, 22),
          reason: 'High fever and cold symptoms today',
        ),
      );

      expect(result.isFailure, isTrue);
      expect(result.failureOrNull, isA<ValidationFailure>());
      expect(
        result.failureOrNull!.message,
        contains('Department quota exceeded'),
      );
    });
  });
}
