import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rebs/app.dart';
import 'package:rebs/core/config/app_config.dart';
import 'package:rebs/core/database/app_database.dart';
import 'package:rebs/core/di/injection_container.dart';
import 'package:rebs/core/error/failures.dart';
import 'package:rebs/core/error/result.dart';
import 'package:rebs/core/location/location_models.dart';
import 'package:rebs/core/location/location_service.dart';
import 'package:rebs/core/network/network_info.dart';
import 'package:rebs/core/sync/sync_manager.dart';
import 'package:rebs/features/auth/domain/entities/employee.dart';
import 'package:rebs/features/auth/domain/entities/employee_session.dart';
import 'package:rebs/features/auth/domain/repositories/auth_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _TestOfflineNetworkInfo implements NetworkInfo {
  @override
  Future<bool> get isConnected async => false;

  @override
  Stream<bool> get onStatusChange => const Stream<bool>.empty();
}

class _MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  sqfliteFfiInit();

  tearDown(() async {
    if (sl.isRegistered<LocationService>()) {
      await sl<LocationService>().dispose();
    }
    if (sl.isRegistered<SyncManager>()) {
      await sl<SyncManager>().dispose();
    }
    if (sl.isRegistered<AppDatabase>()) {
      await sl<AppDatabase>().close();
    }
    await sl.reset();
  });

  Future<void> pumpAfterDbIo(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 20));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
    }
    await tester.pumpAndSettle();
  }

  testWidgets(
      'launches Splash -> Employee Dashboard, renders employee info, and supports offline Check In with Pending Sync badge',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.runAsync(() async {
      await sl.reset();
      await initDependencies(
        databaseOverride: AppDatabase(
          databaseFactoryOverride: databaseFactoryFfi,
          pathOverride: inMemoryDatabasePath,
        ),
        networkInfoOverride: _TestOfflineNetworkInfo(),
        locationServiceOverride: GeolocatorLocationService(
          employeeConfig: const AppConfig().employeeConfig,
          initialSimulation: const LocationSimulationState(
            mode: LocationSimulationMode.insideOffice,
          ),
        ),
      );
    });

    await tester.pumpWidget(const RebsApp());
    await pumpAfterDbIo(tester);

    // Employee profile & initial dashboard state
    final empConfig = const AppConfig().employeeConfig;
    expect(find.text(empConfig.employeeName), findsOneWidget);
    expect(
      find.text('${empConfig.employeeId} • ${empConfig.department}'),
      findsOneWidget,
    );
    expect(find.text('Not Checked In'), findsOneWidget);
    expect(find.text('Available Leave Balance'), findsOneWidget);
    expect(find.textContaining('Offline'), findsWidgets);

    // Toggle Inside 200m Range OFF -> shows Outside Office Premises warning
    // and blocks Check In
    final rangeSwitch = find.byKey(const ValueKey('inside_200m_switch'));
    expect(rangeSwitch, findsOneWidget);
    await tester.tap(rangeSwitch);
    await tester.pumpAndSettle();

    expect(find.text('Outside Office Premises'), findsOneWidget);
    final checkInTile = find.byKey(const ValueKey('dashboard_check_in_tile'));
    expect(checkInTile, findsOneWidget);
    await tester.tap(checkInTile);
    await pumpAfterDbIo(tester);
    expect(find.text('Not Checked In'), findsOneWidget);

    // Toggle Inside 200m Range ON -> warning clears and Check In registers
    await tester.tap(rangeSwitch);
    await tester.pumpAndSettle();
    expect(find.text('Outside Office Premises'), findsNothing);

    await tester.tap(checkInTile);
    await pumpAfterDbIo(tester);

    expect(find.text('Checked In'), findsOneWidget);
    expect(find.text('Pending Sync'), findsWidgets);

    // Scroll down to verify Recent Attendance section with seeded latest 5 records
    await tester.scrollUntilVisible(
      find.text('Recent Attendance'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Recent Attendance'), findsOneWidget);
    // Tap a seeded attendance row to verify Attendance Details bottom sheet
    final seededRow = find.text('09:06 AM');
    await tester.scrollUntilVisible(
      seededRow,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(seededRow);
    await tester.pumpAndSettle();
    await tester.tap(seededRow);
    await tester.pumpAndSettle();
    expect(find.text('Attendance Details'), findsOneWidget);
    expect(find.text('Working Duration'), findsOneWidget);
    Navigator.of(tester.element(find.text('Attendance Details'))).pop();
    await tester.pumpAndSettle();

    // Navigate to Leave tab
    await tester.tap(find.text('Leave'));
    await pumpAfterDbIo(tester);
    expect(find.text('Leave Balance'), findsOneWidget);
    expect(find.text('Apply Leave'), findsOneWidget);

    // Navigate to Modules tab
    await tester.tap(find.text('Modules'));
    await tester.pumpAndSettle();
    expect(find.text('REBS Platform Modules'), findsOneWidget);
    expect(find.text('CRM'), findsOneWidget);
    expect(find.text('Accounts'), findsOneWidget);
  });

  testWidgets(
      'displays error state on Splash and navigates to Dashboard after Retry succeeds',
      (WidgetTester tester) async {
    final mockAuthRepo = _MockAuthRepository();
    var attempts = 0;
    final sampleSession = EmployeeSession(
      sessionId: 'retry-session',
      employee: const Employee(
        employeeId: 'REBS001',
        employeeName: 'Syed Mohamed Afsal',
        department: 'Engineering',
        designation: 'Flutter Developer',
        officeId: 'OFFICE001',
        officeName: 'Teqbae Innovations, Kochi',
        officeLatitude: 10.0159,
        officeLongitude: 76.3419,
        companyTimezone: 'Asia/Kolkata',
      ),
      initializedAt: DateTime(2026, 11, 18, 9, 0),
      lastRestoredAt: DateTime(2026, 11, 18, 9, 0),
    );

    when(() => mockAuthRepo.initializeSession()).thenAnswer((_) async {
      attempts++;
      if (attempts == 1) {
        return const FailureResult(CacheFailure('Storage read error'));
      }
      return Success(sampleSession);
    });

    await tester.runAsync(() async {
      await sl.reset();
      await initDependencies(
        databaseOverride: AppDatabase(
          databaseFactoryOverride: databaseFactoryFfi,
          pathOverride: inMemoryDatabasePath,
        ),
        networkInfoOverride: _TestOfflineNetworkInfo(),
        authRepositoryOverride: mockAuthRepo,
      );
    });

    await tester.pumpWidget(const RebsApp());
    await tester.pumpAndSettle();

    expect(find.text('REBS'), findsOneWidget);
    expect(find.text('Initialization Failed'), findsOneWidget);
    expect(find.text('Storage read error'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await pumpAfterDbIo(tester);

    expect(find.text('Syed Mohamed Afsal'), findsOneWidget);
  });

  testWidgets('renders empty state cleanly when no attendance records exist',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.runAsync(() async {
      await sl.reset();
      await initDependencies(
        databaseOverride: AppDatabase(
          databaseFactoryOverride: databaseFactoryFfi,
          pathOverride: inMemoryDatabasePath,
          seedSampleAttendance: false,
        ),
        networkInfoOverride: _TestOfflineNetworkInfo(),
      );
    });

    await tester.pumpWidget(const RebsApp());
    await pumpAfterDbIo(tester);

    await tester.scrollUntilVisible(
      find.text('No attendance records yet'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('No attendance records yet'), findsOneWidget);
  });

  testWidgets(
      'swipes attendance card to 200m Office Geofence Map and updates live distance with range switch',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.runAsync(() async {
      await sl.reset();
      await initDependencies(
        databaseOverride: AppDatabase(
          databaseFactoryOverride: databaseFactoryFfi,
          pathOverride: inMemoryDatabasePath,
        ),
        networkInfoOverride: _TestOfflineNetworkInfo(),
        locationServiceOverride: GeolocatorLocationService(
          employeeConfig: const AppConfig().employeeConfig,
          initialSimulation: const LocationSimulationState(
            mode: LocationSimulationMode.insideOffice,
          ),
        ),
      );
    });

    await tester.pumpWidget(const RebsApp());
    await pumpAfterDbIo(tester);

    // Switch to the 200m Office Geofence Map inside the dark-navy panel
    await tester.tap(find.byKey(const ValueKey('panel_tab_map')));
    await tester.pumpAndSettle();

    expect(find.text('Office Geofence'), findsOneWidget);
    expect(find.byKey(const ValueKey('office_geofence_map')), findsOneWidget);
    expect(find.text('200m'), findsOneWidget);
    expect(find.text('25m • Inside 200m'), findsOneWidget);
    expect(find.text('You'), findsOneWidget);

    // Toggle Inside 200m Range OFF -> map updates immediately to outside (~450m)
    await tester.tap(find.byKey(const ValueKey('inside_200m_switch')));
    await tester.pumpAndSettle();

    expect(find.textContaining('• Outside 200m'), findsOneWidget);
    expect(find.text('Outside Office Premises'), findsOneWidget);

    // Open Full-Screen Real Interactive Map and close it cleanly
    await tester.tap(find.byKey(const ValueKey('map_expand_button')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('office_geofence_map_fullscreen')),
      findsOneWidget,
    );
    expect(find.text('Inside (~25m)'), findsOneWidget);
    Navigator.of(tester.element(find.text('Inside (~25m)'))).pop();
    await tester.pumpAndSettle();

    // Switch back to Clock / Check In-Out page
    await tester.tap(find.byKey(const ValueKey('panel_tab_attendance')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('dashboard_check_in_tile')), findsOneWidget);
  });
}
