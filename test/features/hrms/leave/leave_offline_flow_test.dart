import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rebs/core/config/app_config.dart';
import 'package:rebs/core/database/app_database.dart';
import 'package:rebs/core/network/network_info.dart';
import 'package:rebs/core/sync/sync_manager.dart';
import 'package:rebs/core/sync/sync_queue_datasource.dart';
import 'package:rebs/core/sync/sync_status.dart';
import 'package:rebs/features/hrms/leave/data/datasources/leave_local_datasource.dart';
import 'package:rebs/features/hrms/leave/data/datasources/leave_remote_datasource.dart';
import 'package:rebs/features/hrms/leave/data/repositories/leave_repository_impl.dart';
import 'package:rebs/features/hrms/leave/data/sync/leave_sync_handler.dart';
import 'package:rebs/features/hrms/leave/domain/entities/leave_request.dart';
import 'package:rebs/features/hrms/leave/domain/usecases/apply_leave.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class MockLeaveRemoteDataSource extends Mock implements LeaveRemoteDataSource {}

class OfflineNetworkInfo implements NetworkInfo {
  @override
  Future<bool> get isConnected async => false;

  @override
  Stream<bool> get onStatusChange => const Stream<bool>.empty();
}

void main() {
  sqfliteFfiInit();

  late AppDatabase db;
  late SyncQueueDataSource queueDataSource;
  late LeaveLocalDataSourceImpl localDataSource;
  late MockLeaveRemoteDataSource remoteDataSource;
  late SyncManager syncManager;
  late LeaveRepositoryImpl repository;
  late ApplyLeave applyLeave;

  setUp(() async {
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
    const config = AppConfig();

    syncManager = SyncManager(
      queueDataSource: queueDataSource,
      networkInfo: OfflineNetworkInfo(),
      config: config,
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
      networkInfo: OfflineNetworkInfo(),
      syncManager: syncManager,
      config: config,
    );
    applyLeave = ApplyLeave(repository);
  });

  tearDown(() async {
    await syncManager.dispose();
    await db.close();
  });

  test('validates leave dates and reason in domain use case', () async {
    final emptyReason = await applyLeave(
      ApplyLeaveParams(
        leaveType: LeaveType.annual,
        startDate: DateTime(2026, 11, 20),
        endDate: DateTime(2026, 11, 21),
        reason: '   ',
      ),
    );
    expect(emptyReason.isFailure, isTrue);

    final invalidRange = await applyLeave(
      ApplyLeaveParams(
        leaveType: LeaveType.annual,
        startDate: DateTime(2026, 11, 22),
        endDate: DateTime(2026, 11, 20),
        reason: 'Trip',
      ),
    );
    expect(invalidRange.isFailure, isTrue);
  });

  test('applies and cancels leave offline while keeping balance accurate',
      () async {
    final beforeBalances = await repository.getLeaveBalances();
    final annualBefore = beforeBalances.dataOrNull!
        .firstWhere((b) => b.leaveType == LeaveType.annual);

    // Apply for 2 days of annual leave offline
    final applied = await applyLeave(
      ApplyLeaveParams(
        leaveType: LeaveType.annual,
        startDate: DateTime(2026, 11, 20),
        endDate: DateTime(2026, 11, 21),
        reason: 'Family event',
      ),
    );
    expect(applied.isSuccess, isTrue);
    final leave = applied.dataOrNull!;
    expect(leave.requestedDays, 2.0);
    expect(leave.syncStatus, RecordSyncStatus.pending);

    final afterApplyBalances = await repository.getLeaveBalances();
    final annualAfterApply = afterApplyBalances.dataOrNull!
        .firstWhere((b) => b.leaveType == LeaveType.annual);
    expect(annualAfterApply.pendingDays, annualBefore.pendingDays + 2.0);

    // Cancel offline -> restores pending days
    final cancelled = await repository.cancelLeave(leave.localId);
    expect(cancelled.isSuccess, isTrue);
    expect(cancelled.dataOrNull!.approvalStatus, LeaveApprovalStatus.cancelled);

    final afterCancelBalances = await repository.getLeaveBalances();
    final annualAfterCancel = afterCancelBalances.dataOrNull!
        .firstWhere((b) => b.leaveType == LeaveType.annual);
    expect(annualAfterCancel.pendingDays, annualBefore.pendingDays);

    // Both mutations are queued for sync
    final counts = await queueDataSource.getCounts();
    expect(counts.pending, 2);
  });
}
