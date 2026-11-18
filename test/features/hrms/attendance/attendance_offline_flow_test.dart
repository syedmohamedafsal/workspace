import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rebs/core/config/app_config.dart';
import 'package:rebs/core/database/app_database.dart';
import 'package:rebs/core/network/network_info.dart';
import 'package:rebs/core/sync/sync_manager.dart';
import 'package:rebs/core/sync/sync_queue_datasource.dart';
import 'package:rebs/core/sync/sync_status.dart';
import 'package:rebs/features/hrms/attendance/data/datasources/attendance_local_datasource.dart';
import 'package:rebs/features/hrms/attendance/data/datasources/attendance_remote_datasource.dart';
import 'package:rebs/features/hrms/attendance/data/models/attendance_record_model.dart';
import 'package:rebs/features/hrms/attendance/data/repositories/attendance_repository_impl.dart';
import 'package:rebs/features/hrms/attendance/data/sync/attendance_sync_handler.dart';
import 'package:rebs/features/hrms/attendance/domain/entities/attendance_record.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class MockAttendanceRemoteDataSource extends Mock
    implements AttendanceRemoteDataSource {}

class ToggleNetworkInfo implements NetworkInfo {
  bool connected = false;
  final _controller = StreamController<bool>.broadcast();

  @override
  Future<bool> get isConnected async => connected;

  @override
  Stream<bool> get onStatusChange => _controller.stream;

  void goOnline() {
    connected = true;
    _controller.add(true);
  }

  Future<void> dispose() => _controller.close();
}

void main() {
  sqfliteFfiInit();

  late AppDatabase db;
  late SyncQueueDataSource queueDataSource;
  late AttendanceLocalDataSourceImpl localDataSource;
  late MockAttendanceRemoteDataSource remoteDataSource;
  late ToggleNetworkInfo networkInfo;
  late SyncManager syncManager;
  late AttendanceRepositoryImpl repository;
  late DateTime clockTime;

  setUp(() async {
    clockTime = DateTime(2026, 11, 18, 9, 15);
    db = AppDatabase(
      databaseFactoryOverride: databaseFactoryFfi,
      pathOverride: inMemoryDatabasePath,
    );
    queueDataSource = SyncQueueDataSource(db);
    localDataSource = AttendanceLocalDataSourceImpl(
      appDatabase: db,
      syncQueueDataSource: queueDataSource,
    );
    remoteDataSource = MockAttendanceRemoteDataSource();
    networkInfo = ToggleNetworkInfo();
    const config = AppConfig();

    syncManager = SyncManager(
      queueDataSource: queueDataSource,
      networkInfo: networkInfo,
      config: config,
      clock: () => clockTime,
    );

    syncManager.registerHandler(
      AttendanceSyncHandler(
        localDataSource: localDataSource,
        remoteDataSource: remoteDataSource,
      ),
    );
    await syncManager.initialize();

    repository = AttendanceRepositoryImpl(
      localDataSource: localDataSource,
      remoteDataSource: remoteDataSource,
      networkInfo: networkInfo,
      syncManager: syncManager,
      config: config,
      clock: () => clockTime,
    );
  });

  tearDown(() async {
    await syncManager.dispose();
    await networkInfo.dispose();
    await db.close();
  });

  test('offline check-in and check-out persist locally and sync in order online',
      () async {
    // 1. Check in while offline
    final checkInResult = await repository.checkIn(workLocation: 'Office');
    expect(checkInResult.isSuccess, isTrue);
    final checkedIn = checkInResult.dataOrNull!;
    expect(checkedIn.isCheckedIn, isTrue);
    expect(checkedIn.syncStatus, RecordSyncStatus.pending);

    // 2. Duplicate check-in on the same day is blocked
    final duplicate = await repository.checkIn(workLocation: 'Office');
    expect(duplicate.isFailure, isTrue);

    // 3. Check out later while still offline
    clockTime = DateTime(2026, 11, 18, 17, 45);
    final checkOutResult = await repository.checkOut(note: 'Done for the day');
    expect(checkOutResult.isSuccess, isTrue);
    final checkedOut = checkOutResult.dataOrNull!;
    expect(checkedOut.isCompleted, isTrue);
    expect(checkedOut.syncStatus, RecordSyncStatus.pending);

    // Verify 2 queued mutations exist in SQLite outbox
    final counts = await queueDataSource.getCounts();
    expect(counts.pending, 2);

    // 4. Stub remote server responses and restore connectivity
    when(
      () => remoteDataSource.sendCheckIn(
        payload: any(named: 'payload'),
        idempotencyKey: any(named: 'idempotencyKey'),
      ),
    ).thenAnswer(
      (_) async => AttendanceRecordModel(
        localId: checkedIn.localId,
        serverId: 'srv-att-42',
        employeeId: checkedIn.employeeId,
        date: checkedIn.date,
        checkInAt: checkedIn.checkInAt,
        status: AttendanceStatus.checkedIn,
        syncStatus: RecordSyncStatus.synced,
        createdAt: checkedIn.createdAt,
        updatedAt: checkedIn.updatedAt,
      ),
    );

    Map<String, dynamic>? capturedCheckOutPayload;
    when(
      () => remoteDataSource.sendCheckOut(
        payload: any(named: 'payload'),
        idempotencyKey: any(named: 'idempotencyKey'),
      ),
    ).thenAnswer((invocation) async {
      capturedCheckOutPayload =
          invocation.namedArguments[#payload] as Map<String, dynamic>;
      return AttendanceRecordModel(
        localId: checkedOut.localId,
        serverId: 'srv-att-42',
        employeeId: checkedOut.employeeId,
        date: checkedOut.date,
        checkInAt: checkedOut.checkInAt,
        checkOutAt: checkedOut.checkOutAt,
        status: AttendanceStatus.checkedOut,
        syncStatus: RecordSyncStatus.synced,
        createdAt: checkedOut.createdAt,
        updatedAt: checkedOut.updatedAt,
      );
    });

    final syncedDone = syncManager.statusStream.firstWhere(
      (s) => s.isOnline && !s.isSyncing && s.pendingCount == 0,
    );
    networkInfo.goOnline();
    await syncedDone;

    // Check-out payload must have inherited server_id returned by check-in!
    expect(capturedCheckOutPayload?['server_id'], 'srv-att-42');

    // Local record is now synced with serverId
    final todayAfterSync = await repository.getTodayAttendance();
    expect(todayAfterSync.dataOrNull?.syncStatus, RecordSyncStatus.synced);
    expect(todayAfterSync.dataOrNull?.serverId, 'srv-att-42');
  });
}
