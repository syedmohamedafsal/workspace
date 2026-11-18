import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rebs/app.dart';
import 'package:rebs/core/database/app_database.dart';
import 'package:rebs/core/di/injection_container.dart';
import 'package:rebs/core/error/failures.dart';
import 'package:rebs/core/error/result.dart';
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
      'routes Splash -> Login when no session exists, allows Demo sign-in to Dashboard, and persists session',
      (WidgetTester tester) async {
    await tester.runAsync(() async {
      await sl.reset();
      await initDependencies(
        databaseOverride: AppDatabase(
          databaseFactoryOverride: databaseFactoryFfi,
          pathOverride: inMemoryDatabasePath,
        ),
        networkInfoOverride: _TestOfflineNetworkInfo(),
      );
    });

    await tester.pumpWidget(const RebsApp());
    await pumpAfterDbIo(tester);

    // No persisted session -> lands on REBS Login screen
    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
    expect(find.text('Continue as Demo Employee'), findsOneWidget);

    // Tap Demo Employee -> persists session and navigates to Dashboard
    await tester.ensureVisible(find.text('Continue as Demo Employee'));
    await tester.tap(find.text('Continue as Demo Employee'));
    await pumpAfterDbIo(tester);

    expect(find.text('Employee Dashboard - Coming Soon'), findsOneWidget);

    // Verify session was persisted in SQLite
    final restored = await tester.runAsync(
      () => sl<AuthRepository>().restoreSession(),
    );
    expect(restored?.isSuccess, isTrue);
    expect(restored?.dataOrNull?.employee.employeeId, 'REBS001');
    expect(restored?.dataOrNull?.employee.employeeName, 'Syed Mohamed Afsal');

    // Sign out returns cleanly to Login
    await tester.tap(find.byIcon(Icons.logout_rounded));
    await pumpAfterDbIo(tester);
    expect(find.text('Welcome back'), findsOneWidget);
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
        officeName: 'REBS Chennai Office',
        officeLatitude: 13.0827,
        officeLongitude: 80.2707,
        companyTimezone: 'Asia/Kolkata',
      ),
      initializedAt: DateTime(2026, 11, 18, 9, 0),
      lastRestoredAt: DateTime(2026, 11, 18, 9, 0),
    );

    when(() => mockAuthRepo.restoreSession()).thenAnswer((_) async {
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
    await tester.pumpAndSettle();

    expect(find.text('Employee Dashboard - Coming Soon'), findsOneWidget);
  });
}
