import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rebs/core/widgets/attendance_dialogs.dart';

void main() {
  group('AttendanceDialogs - First Name Extraction', () {
    test('extracts first name from full name or falls back gracefully', () {
      expect(AttendanceDialogs.extractFirstName('Syed Mohamed Afsal'), equals('Syed'));
      expect(AttendanceDialogs.extractFirstName('Afsal'), equals('Afsal'));
      expect(AttendanceDialogs.extractFirstName(''), equals('bro'));
      expect(AttendanceDialogs.extractFirstName('   '), equals('bro'));
    });
  });

  group('CheckOut Alert Box Tests', () {
    testWidgets('shows sweet after-hours message when office hours are over', (tester) async {
      bool? result;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () async {
                    result = await AttendanceDialogs.showCheckOutConfirmation(
                      context: context,
                      employeeName: 'Syed Mohamed Afsal',
                      companyTimezone: 'Asia/Kolkata',
                      workedDuration: const Duration(hours: 8, minutes: 15),
                    );
                  },
                  child: const Text('Open Check Out'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Check Out'));
      await tester.pumpAndSettle();

      // Verify Alert Box is visible
      expect(find.byKey(const ValueKey('checkout_alert_dialog')), findsOneWidget);

      // Verify Sweet Message for After Hours
      expect(find.text('Time to Have Your Own Time! 🌙'), findsOneWidget);
      expect(
        find.textContaining('Time to have your own time, relax, and recharge'),
        findsOneWidget,
      );
      expect(find.text('Check Out & Relax 🛋️'), findsOneWidget);
      expect(find.text('Stay a Bit'), findsOneWidget);

      // Confirm check out
      await tester.tap(find.byKey(const ValueKey('checkout_confirm_button')));
      await tester.pumpAndSettle();

      expect(result, isTrue);
    });

    testWidgets('shows sweet office-time bro message when office hours are ongoing', (tester) async {
      bool? result;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () async {
                    result = await AttendanceDialogs.showCheckOutConfirmation(
                      context: context,
                      employeeName: 'Syed Mohamed Afsal',
                      companyTimezone: 'Asia/Kolkata',
                      workedDuration: const Duration(hours: 2, minutes: 30),
                    );
                  },
                  child: const Text('Open Check Out'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Check Out'));
      await tester.pumpAndSettle();

      // If current system time in Asia/Kolkata is morning (e.g. 10:45 AM)
      // Toggle explicitly to Office Time View using the Reviewer Switcher
      await tester.tap(find.text('Office Time View'));
      await tester.pumpAndSettle();

      expect(find.text("It's Office Time Bro! ⏳"), findsOneWidget);
      expect(
        find.textContaining("Hey Syed! It's still office time bro!"),
        findsOneWidget,
      );
      expect(find.text('Check Out Early'), findsOneWidget);
      expect(find.text('Keep Working 💻'), findsOneWidget);

      // Cancel check out
      await tester.tap(find.byKey(const ValueKey('checkout_cancel_button')));
      await tester.pumpAndSettle();

      expect(result, isFalse);
    });
  });

  group('CheckIn Welcome Dialog Tests', () {
    testWidgets('renders coffee, code, and commit message properly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    AttendanceDialogs.showCheckInWelcomeDialog(
                      context: context,
                      employeeName: 'Syed Mohamed Afsal',
                      distanceMeters: 22.0,
                      officeName: 'Teqbae Kochi',
                    );
                  },
                  child: const Text('Open Welcome'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Welcome'));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('checkin_welcome_dialog')), findsOneWidget);
      expect(find.text('Welcome to Work, Syed! 💻'), findsOneWidget);
      expect(
        find.text("Hey Syed, take a coffee and code, and don't forget to commit! ☕💻🚀"),
        findsOneWidget,
      );
      expect(find.text('Let\'s Code! 🚀'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('checkin_lets_code_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('checkin_welcome_dialog')), findsNothing);
    });
  });

  group('Attendance Completed Dialog Tests', () {
    testWidgets('displays check-in time, check-out time, hours worked, and hides action buttons', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    AttendanceDialogs.showAttendanceCompletedDialog(
                      context: context,
                      employeeName: 'Syed Mohamed Afsal',
                      companyTimezone: 'Asia/Kolkata',
                      checkInAt: DateTime.utc(2026, 11, 19, 2, 16), // 07:46 AM IST
                      checkOutAt: DateTime.utc(2026, 11, 19, 10, 41), // 04:11 PM IST
                      workedDuration: const Duration(hours: 8, minutes: 25),
                      officeName: 'Teqbae Innovations',
                    );
                  },
                  child: const Text('Open Completed'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Completed'));
      await tester.pumpAndSettle();

      // Verify dialog is visible
      expect(find.byKey(const ValueKey('attendance_completed_dialog')), findsOneWidget);

      // Verify check in and check out labels and values
      expect(find.text('Check In'), findsOneWidget);
      expect(find.text('Check Out'), findsOneWidget);

      // Verify worked duration and hours message
      expect(find.text('Worked Today'), findsOneWidget);
      expect(find.text('08h 25m'), findsOneWidget);
      expect(find.textContaining('You have worked 08h 25m on here today!'), findsOneWidget);

      // Verify action buttons are completely hidden
      expect(find.text('Stay a Bit'), findsNothing);
      expect(find.text('Check Out & Relax 🛋️'), findsNothing);
      expect(find.text('Let\'s Code! 🚀'), findsNothing);
      expect(find.text('Office Time View'), findsNothing);
      expect(find.text('After Hours View'), findsNothing);

      // Verify close button dismisses dialog
      await tester.tap(find.byKey(const ValueKey('completed_dialog_close_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('attendance_completed_dialog')), findsNothing);
    });
  });
}
