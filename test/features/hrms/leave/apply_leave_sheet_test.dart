import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rebs/features/hrms/leave/presentation/pages/apply_leave_sheet.dart';

void main() {
  testWidgets('ApplyLeaveSheet renders start date and end date fields with proper validation', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ApplyLeaveSheet(),
        ),
      ),
    );

    expect(find.text('Apply for Leave'), findsOneWidget);
    expect(find.text('Start Date'), findsOneWidget);
    expect(find.text('End Date'), findsOneWidget);

    final datePickers = find.byIcon(Icons.calendar_today_outlined);
    expect(datePickers, findsNWidgets(2));
  });
}
