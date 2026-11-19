import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rebs/core/sync/sync_manager.dart';
import 'package:rebs/core/sync/sync_status.dart';
import 'package:rebs/core/widgets/sync_feedback_handler.dart';

class MockSyncManager extends Mock implements SyncManager {}

void main() {
  late MockSyncManager mockSyncManager;

  setUp(() {
    mockSyncManager = MockSyncManager();
  });

  Widget buildTestWidget({required VoidCallback onSync}) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: ElevatedButton(
            key: const ValueKey('test_sync_button'),
            onPressed: onSync,
            child: const Text('Sync'),
          ),
        ),
      ),
    );
  }

  testWidgets(
      'displays floating failure SnackBar when device is offline before sync',
      (tester) async {
    when(() => mockSyncManager.currentSnapshot).thenReturn(
      const SyncSnapshot(
        isOnline: false,
        isSyncing: false,
        pendingCount: 2,
      ),
    );

    await tester.pumpWidget(
      buildTestWidget(
        onSync: () => SyncFeedbackHandler.performSync(
          context: tester.element(find.byKey(const ValueKey('test_sync_button'))),
          syncManager: mockSyncManager,
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('test_sync_button')));
    await tester.pump();

    // Verify floating failure SnackBar appears
    final snackBarFinder = find.byType(SnackBar);
    expect(snackBarFinder, findsOneWidget);

    final snackBar = tester.widget<SnackBar>(snackBarFinder);
    expect(snackBar.behavior, equals(SnackBarBehavior.floating));
    expect(snackBar.backgroundColor, equals(const Color(0xFFDC2626)));
    expect(
      find.text('Cannot sync: Device is offline. Please check your connection.'),
      findsOneWidget,
    );

    verifyNever(() => mockSyncManager.syncNow(forceDue: any(named: 'forceDue')));
  });

  testWidgets(
      'displays floating emerald success SnackBar when synchronization succeeds',
      (tester) async {
    when(() => mockSyncManager.currentSnapshot).thenReturn(
      const SyncSnapshot(
        isOnline: true,
        isSyncing: false,
        pendingCount: 0,
        failedCount: 0,
        conflictCount: 0,
      ),
    );
    when(() => mockSyncManager.syncNow(forceDue: true))
        .thenAnswer((_) async {});
    when(() => mockSyncManager.retryFailed())
        .thenAnswer((_) async {});

    await tester.pumpWidget(
      buildTestWidget(
        onSync: () => SyncFeedbackHandler.performSync(
          context: tester.element(find.byKey(const ValueKey('test_sync_button'))),
          syncManager: mockSyncManager,
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('test_sync_button')));
    // Wait for the minimum UX loading duration (400ms)
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pump();

    // Verify floating success SnackBar appears
    final snackBarFinder = find.byType(SnackBar);
    expect(snackBarFinder, findsOneWidget);

    final snackBar = tester.widget<SnackBar>(snackBarFinder);
    expect(snackBar.behavior, equals(SnackBarBehavior.floating));
    expect(snackBar.backgroundColor, equals(const Color(0xFF059669)));
    expect(
      find.text('All attendance and leave records synced successfully!'),
      findsOneWidget,
    );

    verify(() => mockSyncManager.syncNow(forceDue: true)).called(1);
  });

  testWidgets(
      'displays floating crimson error SnackBar when synchronization encounters issues',
      (tester) async {
    when(() => mockSyncManager.currentSnapshot).thenReturn(
      const SyncSnapshot(
        isOnline: true,
        isSyncing: false,
        pendingCount: 1,
        failedCount: 1,
        lastError: 'HTTP 503 Service Unavailable',
      ),
    );
    when(() => mockSyncManager.syncNow(forceDue: true))
        .thenAnswer((_) async {});
    when(() => mockSyncManager.retryFailed())
        .thenAnswer((_) async {});

    await tester.pumpWidget(
      buildTestWidget(
        onSync: () => SyncFeedbackHandler.performSync(
          context: tester.element(find.byKey(const ValueKey('test_sync_button'))),
          syncManager: mockSyncManager,
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('test_sync_button')));
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pump();

    // Verify floating error SnackBar appears
    final snackBarFinder = find.byType(SnackBar);
    expect(snackBarFinder, findsOneWidget);

    final snackBar = tester.widget<SnackBar>(snackBarFinder);
    expect(snackBar.behavior, equals(SnackBarBehavior.floating));
    expect(snackBar.backgroundColor, equals(const Color(0xFFDC2626)));
    expect(
      find.text('Sync failed: HTTP 503 Service Unavailable'),
      findsOneWidget,
    );
  });
}
