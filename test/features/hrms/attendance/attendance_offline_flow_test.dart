import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rebs/core/config/app_config.dart';
import 'package:rebs/core/database/app_database.dart';
import 'package:rebs/core/error/exceptions.dart';
import 'package:rebs/core/error/failures.dart';
import 'package:rebs/core/location/location_models.dart';
import 'package:rebs/core/location/location_service.dart';
import 'package:rebs/core/network/network_info.dart';
import 'package:rebs/core/sync/sync_manager.dart';
import 'package:rebs/core/sync/sync_queue_datasource.dart';
import 'package:rebs/core/sync/sync_status.dart';
import 'package:rebs/core/time/company_clock.dart';
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
  late GeolocatorLocationService locationService;
  late AttendanceRepositoryImpl repository;
  late DateTime utcClockTime;

  setUp(() async {
    utcClockTime = DateTime.utc(2026, 11, 18, 3, 45); // 09:15 IST
    db = AppDatabase(
      databaseFactoryOverride: databaseFactoryFfi,
      pathOverride: inMemoryDatabasePath,
      seedSampleAttendance: false,
    );
    queueDataSource = SyncQueueDataSource(db);
    localDataSource = AttendanceLocalDataSourceImpl(
      appDatabase: db,
      syncQueueDataSource: queueDataSource,
    );
    remoteDataSource = MockAttendanceRemoteDataSource();
    networkInfo = ToggleNetworkInfo();
    const config = AppConfig();

    locationService = GeolocatorLocationService(
      employeeConfig: config.employeeConfig,
      initialSimulation: const LocationSimulationState(
        mode: LocationSimulationMode.insideOffice,
      ),
    );

    syncManager = SyncManager(
      queueDataSource: queueDataSource,
      networkInfo: networkInfo,
      config: config,
      clock: () => utcClockTime,
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
      locationService: locationService,
      companyClock: CompanyClock(utcClock: () => utcClockTime),
      config: config,
    );
  });

  tearDown(() async {
    await locationService.dispose();
    await syncManager.dispose();
    await networkInfo.dispose();
    await db.close();
  });

  test('check-out without check-in is rejected', () async {
    final result = await repository.checkOut();
    expect(result.isFailure, isTrue);
    expect(result.failureOrNull, isA<ValidationFailure>());
  });

  test('rejects attendance outside 200m geofence with meaningful message',
      () async {
    locationService.updateSimulation(
      const LocationSimulationState(mode: LocationSimulationMode.outsideOffice),
    );

    final result = await repository.checkIn();
    expect(result.isFailure, isTrue);
    expect(result.failureOrNull, isA<OutsideGeofenceFailure>());
    expect(result.failureOrNull!.message, contains('200m'));
    expect(result.failureOrNull!.message, contains('Teqbae Innovations, Kochi'));
  });

  test('handles denied, permanently denied, and unavailable location states',
      () async {
    locationService.updateSimulation(
      const LocationSimulationState(
        mode: LocationSimulationMode.permissionDenied,
      ),
    );
    expect(
      (await repository.checkIn()).failureOrNull,
      isA<LocationPermissionDeniedFailure>(),
    );

    locationService.updateSimulation(
      const LocationSimulationState(
        mode: LocationSimulationMode.permissionPermanentlyDenied,
      ),
    );
    expect(
      (await repository.checkIn()).failureOrNull,
      isA<LocationPermissionPermanentlyDeniedFailure>(),
    );

    locationService.updateSimulation(
      const LocationSimulationState(
        mode: LocationSimulationMode.locationUnavailable,
      ),
    );
    expect(
      (await repository.checkIn()).failureOrNull,
      isA<LocationUnavailableFailure>(),
    );
  });

  test('rapid concurrent taps do not create duplicate attendance events',
      () async {
    final results = await Future.wait([
      repository.checkIn(workLocation: 'Teqbae Innovations, Kochi'),
      repository.checkIn(workLocation: 'Teqbae Innovations, Kochi'),
      repository.checkIn(workLocation: 'Teqbae Innovations, Kochi'),
    ]);

    final successes = results.where((r) => r.isSuccess).toList();
    expect(successes.length, 1);

    final counts = await queueDataSource.getCounts();
    expect(counts.pending, 1);
  });

  test(
      'offline check-in and check-out capture GPS, persist locally, and sync in order online',
      () async {
    // 1. Check in while offline inside 200m
    final checkInResult =
        await repository.checkIn(workLocation: 'Teqbae Innovations, Kochi');
    expect(checkInResult.isSuccess, isTrue);
    final checkedIn = checkInResult.dataOrNull!;
    expect(checkedIn.isCheckedIn, isTrue);
    expect(checkedIn.syncStatus, RecordSyncStatus.pending);
    expect(checkedIn.checkInLatitude, isNotNull);
    expect(checkedIn.checkInLongitude, isNotNull);
    expect(checkedIn.checkInDistanceMeters, lessThanOrEqualTo(200));

    // 2. Duplicate check-in on the same day is blocked
    final duplicate = await repository.checkIn();
    expect(duplicate.isFailure, isTrue);

    // 3. Check out later while still offline
    utcClockTime = DateTime.utc(2026, 11, 18, 12, 15); // 17:45 IST
    final checkOutResult = await repository.checkOut(note: 'Done for the day');
    expect(checkOutResult.isSuccess, isTrue);
    final checkedOut = checkOutResult.dataOrNull!;
    expect(checkedOut.isCompleted, isTrue);
    expect(checkedOut.syncStatus, RecordSyncStatus.pending);
    expect(checkedOut.checkOutLatitude, isNotNull);
    expect(checkedOut.checkOutLongitude, isNotNull);

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

    // Check-out payload carries server_id from check-in + captured coordinates
    expect(capturedCheckOutPayload?['server_id'], 'srv-att-42');
    expect(capturedCheckOutPayload?['latitude'], isNotNull);
    expect(capturedCheckOutPayload?['longitude'], isNotNull);

    final todayAfterSync = await repository.getTodayAttendance();
    expect(todayAfterSync.dataOrNull?.syncStatus, RecordSyncStatus.synced);
    expect(todayAfterSync.dataOrNull?.serverId, 'srv-att-42');
  });

  test(
      'handles server 409 duplicate rejection and marks local record as conflict/rejected without blocking queue',
      () async {
    final checkInResult = await repository.checkIn();
    expect(checkInResult.isSuccess, isTrue);

    // Stub 409 Conflict response
    when(
      () => remoteDataSource.sendCheckIn(
        payload: any(named: 'payload'),
        idempotencyKey: any(named: 'idempotencyKey'),
      ),
    ).thenThrow(
      const ConflictException(
        'Attendance already recorded for this date on server',
      ),
    );

    when(
      () => remoteDataSource.fetchHistory(
        employeeId: any(named: 'employeeId'),
        limit: any(named: 'limit'),
      ),
    ).thenAnswer((_) async => []);

    networkInfo.goOnline();
    await syncManager.syncNow(forceDue: true);

    final record = await repository.getTodayAttendance();
    expect(record.dataOrNull?.syncStatus, RecordSyncStatus.conflict);
    expect(record.dataOrNull?.syncError, contains('Attendance already recorded'));

    // Queue status reflects conflict isolation
    final counts = await queueDataSource.getCounts();
    expect(counts.conflict, 1);
    expect(counts.pending, 0);
  });

  test(
      'reconciles timeout-after-server-accept when retry receives 409 conflict',
      () async {
    final checkInResult = await repository.checkIn();
    final localRecord = checkInResult.dataOrNull!;

    // 1st attempt: server accepts but client network times out
    when(
      () => remoteDataSource.sendCheckIn(
        payload: any(named: 'payload'),
        idempotencyKey: any(named: 'idempotencyKey'),
      ),
    ).thenThrow(
      const NetworkException('Connection timeout waiting for server response'),
    );

    networkInfo.goOnline();
    await syncManager.syncNow(forceDue: true);

    // Remains pending with retryCount > 0
    var counts = await queueDataSource.getCounts();
    expect(counts.pending, 1);

    // 2nd attempt (retry): server responds with 409 conflict because it already created the record
    when(
      () => remoteDataSource.sendCheckIn(
        payload: any(named: 'payload'),
        idempotencyKey: any(named: 'idempotencyKey'),
      ),
    ).thenThrow(
      const ConflictException('Attendance already recorded for this date'),
    );

    // Reconciliation check confirms the server accepted it on flight 1
    when(
      () => remoteDataSource.fetchHistory(
        employeeId: any(named: 'employeeId'),
        limit: any(named: 'limit'),
      ),
    ).thenAnswer(
      (_) async => [
        AttendanceRecordModel(
          localId: localRecord.localId,
          serverId: 'srv-att-reconciled-99',
          employeeId: localRecord.employeeId,
          date: localRecord.date,
          checkInAt: localRecord.checkInAt,
          status: AttendanceStatus.checkedIn,
          syncStatus: RecordSyncStatus.synced,
          createdAt: localRecord.createdAt,
          updatedAt: localRecord.updatedAt,
        ),
      ],
    );

    await syncManager.syncNow(forceDue: true);

    // Reconciled successfully as synced!
    final today = await repository.getTodayAttendance();
    expect(today.dataOrNull?.syncStatus, RecordSyncStatus.synced);
    expect(today.dataOrNull?.serverId, 'srv-att-reconciled-99');
  });
}
