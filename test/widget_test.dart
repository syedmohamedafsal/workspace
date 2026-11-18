import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rebs/app.dart';
import 'package:rebs/core/database/app_database.dart';
import 'package:rebs/core/di/injection_container.dart';
import 'package:rebs/core/network/network_info.dart';
import 'package:rebs/core/sync/sync_manager.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _TestOfflineNetworkInfo implements NetworkInfo {
  @override
  Future<bool> get isConnected async => false;

  @override
  Stream<bool> get onStatusChange => const Stream<bool>.empty();
}

void main() {
  sqfliteFfiInit();

  setUp(() async {
    await sl.reset();
    await initDependencies(
      databaseOverride: AppDatabase(
        databaseFactoryOverride: databaseFactoryFfi,
        pathOverride: inMemoryDatabasePath,
      ),
      networkInfoOverride: _TestOfflineNetworkInfo(),
    );
  });

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
    // Allow sequential sqflite_common_ffi isolate queries to complete across
    // FakeAsync / real-async boundaries before settling animations.
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 20));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
    }
    await tester.pumpAndSettle();
  }

  testWidgets('REBS app renders modules and allows offline check-in',
      (WidgetTester tester) async {
    await tester.pumpWidget(const RebsApp());
    await pumpAfterDbIo(tester);

    // Starts on HRMS Attendance with offline banner visible
    expect(find.text('REBS • Attendance'), findsOneWidget);
    expect(find.textContaining('Offline'), findsOneWidget);
    final checkInButton = find.widgetWithText(FilledButton, 'Check In');
    expect(checkInButton, findsOneWidget);

    // Tap Check In while offline -> transitions to Check Out + Queued chip
    await tester.tap(checkInButton);
    await pumpAfterDbIo(tester);

    expect(find.widgetWithText(FilledButton, 'Check Out'), findsOneWidget);
    expect(find.text('Queued'), findsWidgets);

    // Navigate to Leave tab
    await tester.tap(find.text('Leave'));
    await pumpAfterDbIo(tester);

    expect(find.text('REBS • Leave'), findsOneWidget);
    expect(find.text('Leave Balances'), findsOneWidget);
    expect(find.text('Apply Leave'), findsOneWidget);

    // Navigate to CRM & Accounts scaffolds
    await tester.tap(find.text('CRM'));
    await tester.pumpAndSettle();
    expect(find.text('REBS CRM Module'), findsOneWidget);

    await tester.tap(find.text('Accounts'));
    await tester.pumpAndSettle();
    expect(find.text('REBS Accounts Module'), findsOneWidget);
  });
}
