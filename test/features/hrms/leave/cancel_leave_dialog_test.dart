import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rebs/core/sync/sync_status.dart';
import 'package:rebs/features/hrms/leave/domain/entities/leave_balance.dart';
import 'package:rebs/features/hrms/leave/domain/entities/leave_request.dart';
import 'package:rebs/features/hrms/leave/presentation/bloc/leave_bloc.dart';
import 'package:rebs/features/hrms/leave/presentation/bloc/leave_event.dart';
import 'package:rebs/features/hrms/leave/presentation/bloc/leave_state.dart';
import 'package:rebs/features/hrms/leave/presentation/pages/leave_page.dart';

class MockLeaveBloc extends MockBloc<LeaveEvent, LeaveState>
    implements LeaveBloc {}

void main() {
  late MockLeaveBloc mockLeaveBloc;

  setUpAll(() {
    registerFallbackValue(const CancelLeaveSubmitted('fake_id'));
  });

  setUp(() {
    mockLeaveBloc = MockLeaveBloc();
  });

  testWidgets(
      'tapping Cancel Request opens confirmation alert box, and Keep Leave dismisses it',
      (tester) async {
    final sampleRequest = LeaveRequest(
      localId: 'leave_101',
      employeeId: 'EMP001',
      leaveType: LeaveType.casual,
      startDate: DateTime(2026, 11, 19),
      endDate: DateTime(2026, 11, 20),
      isHalfDay: false,
      reason: 'I need leave for personal errands',
      approvalStatus: LeaveApprovalStatus.pending,
      syncStatus: RecordSyncStatus.synced,
      createdAt: DateTime(2026, 11, 19, 9, 0),
      updatedAt: DateTime(2026, 11, 19, 9, 0),
    );

    when(() => mockLeaveBloc.state).thenReturn(
      LeaveState(
        status: LeaveViewStatus.loaded,
        balances: [
          LeaveBalance(
            leaveType: LeaveType.casual,
            totalDays: 6.0,
            usedDays: 1.0,
            pendingDays: 2.0,
            updatedAt: DateTime(2026, 11, 19),
          ),
          LeaveBalance(
            leaveType: LeaveType.sick,
            totalDays: 10.0,
            usedDays: 1.0,
            pendingDays: 0.0,
            updatedAt: DateTime(2026, 11, 19),
          ),
        ],
        requests: [sampleRequest],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<LeaveBloc>.value(
          value: mockLeaveBloc,
          child: const LeavePage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify leave card is rendered with Cancel Request button
    expect(find.text('Casual Leave'), findsWidgets);
    expect(find.text('Cancel Request'), findsOneWidget);

    // Tap Cancel Request
    await tester.tap(find.text('Cancel Request'));
    await tester.pumpAndSettle();

    // Verify Alert Box is visible
    expect(find.text('Cancel Leave Request?'), findsOneWidget);
    expect(
      find.textContaining('Are you sure you want to cancel this leave application?'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('cancel_dialog_keep_button')), findsOneWidget);
    expect(find.byKey(const ValueKey('cancel_dialog_confirm_button')), findsOneWidget);

    // Tap Keep Leave -> dialog is dismissed without dispatching cancel event
    await tester.tap(find.byKey(const ValueKey('cancel_dialog_keep_button')));
    await tester.pumpAndSettle();

    expect(find.text('Cancel Leave Request?'), findsNothing);
    verifyNever(() => mockLeaveBloc.add(any(that: isA<CancelLeaveSubmitted>())));
  });

  testWidgets(
      'tapping Yes, Cancel in alert box confirms and dispatches CancelLeaveSubmitted',
      (tester) async {
    final sampleRequest = LeaveRequest(
      localId: 'leave_202',
      employeeId: 'EMP001',
      leaveType: LeaveType.casual,
      startDate: DateTime(2026, 11, 19),
      endDate: DateTime(2026, 11, 20),
      isHalfDay: false,
      reason: 'I need leave for urgent work',
      approvalStatus: LeaveApprovalStatus.pending,
      syncStatus: RecordSyncStatus.synced,
      createdAt: DateTime(2026, 11, 19, 9, 0),
      updatedAt: DateTime(2026, 11, 19, 9, 0),
    );

    when(() => mockLeaveBloc.state).thenReturn(
      LeaveState(
        status: LeaveViewStatus.loaded,
        balances: [
          LeaveBalance(
            leaveType: LeaveType.casual,
            totalDays: 6.0,
            usedDays: 1.0,
            pendingDays: 2.0,
            updatedAt: DateTime(2026, 11, 19),
          ),
        ],
        requests: [sampleRequest],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<LeaveBloc>.value(
          value: mockLeaveBloc,
          child: const LeavePage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Tap Cancel Request to open alert box
    await tester.tap(find.text('Cancel Request'));
    await tester.pumpAndSettle();

    expect(find.text('Cancel Leave Request?'), findsOneWidget);

    // Tap Yes, Cancel
    await tester.tap(find.byKey(const ValueKey('cancel_dialog_confirm_button')));
    await tester.pumpAndSettle();

    expect(find.text('Cancel Leave Request?'), findsNothing);
    verify(() => mockLeaveBloc.add(const CancelLeaveSubmitted('leave_202'))).called(1);
  });
}
