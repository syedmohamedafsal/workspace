import 'package:flutter/material.dart';

import '../time/company_clock.dart';

/// Interactive alert dialogs and welcome popups for attendance check-in and check-out.
abstract final class AttendanceDialogs {
  /// Displays a sweet, contextual check-out alert box that checks whether
  /// office hours are over or still ongoing.
  ///
  /// Returns `true` if the user confirms check-out, `false` or `null` otherwise.
  static Future<bool?> showCheckOutConfirmation({
    required BuildContext context,
    required String employeeName,
    required String companyTimezone,
    DateTime? checkInAt,
    DateTime? checkOutAt,
    Duration? workedDuration,
    String? officeName,
  }) {
    if (checkOutAt != null) {
      showAttendanceCompletedDialog(
        context: context,
        employeeName: employeeName,
        companyTimezone: companyTimezone,
        checkInAt: checkInAt,
        checkOutAt: checkOutAt,
        workedDuration: workedDuration,
        officeName: officeName,
      );
      return Future.value(null);
    }

    final companyNow =
        CompanyClock.toCompanyTimezone(DateTime.now(), companyTimezone);

    // Standard company office hours are 09:00 AM to 05:00 PM (17:00), or 8 working hours.
    final autoIsOfficeHoursOver = companyNow.hour >= 17 ||
        (workedDuration != null && workedDuration.inHours >= 8);

    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => _CheckOutAlertDialog(
        employeeName: employeeName,
        companyNow: companyNow,
        initialIsOfficeHoursOver: autoIsOfficeHoursOver,
        checkInAt: checkInAt,
        workedDuration: workedDuration,
      ),
    );
  }

  /// Displays a completed attendance summary popup when the employee has both
  /// checked in and checked out for today. Action buttons are hidden, and the
  /// dialog displays check-in time, check-out time, and total worked duration.
  static Future<void> showAttendanceCompletedDialog({
    required BuildContext context,
    required String employeeName,
    DateTime? checkInAt,
    DateTime? checkOutAt,
    Duration? workedDuration,
    String companyTimezone = 'Asia/Kolkata',
    String? officeName,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => _AttendanceCompletedDialog(
        employeeName: employeeName,
        checkInAt: checkInAt,
        checkOutAt: checkOutAt,
        workedDuration: workedDuration,
        companyTimezone: companyTimezone,
        officeName: officeName ?? 'Teqbae Innovations',
      ),
    );
  }

  /// Displays a warm welcome dialog upon successful check-in.
  static Future<void> showCheckInWelcomeDialog({
    required BuildContext context,
    required String employeeName,
    DateTime? checkInAt,
    double? distanceMeters,
    String? officeName,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => _CheckInWelcomeDialog(
        employeeName: employeeName,
        checkInAt: checkInAt ?? DateTime.now(),
        distanceMeters: distanceMeters,
        officeName: officeName ?? 'Teqbae Innovations',
      ),
    );
  }

  /// Displays an alert dialog when the user attempts to check out without checking in first.
  /// Explains that check-in is required before check-out, with an option to check in immediately.
  static Future<bool?> showCheckInRequiredDialog({
    required BuildContext context,
    required String employeeName,
    VoidCallback? onCheckIn,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => _CheckInRequiredDialog(
        employeeName: employeeName,
        onCheckIn: onCheckIn,
      ),
    );
  }

  /// Displays a floating warning SnackBar informing the user that check-in is required before check-out.
  static void showCheckInRequiredSnackBar(
    BuildContext context, {
    VoidCallback? onCheckIn,
  }) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        duration: const Duration(seconds: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        backgroundColor: const Color(0xFFDC2626),
        content: const Row(
          children: [
            Icon(Icons.info_outline_rounded, color: Colors.white, size: 20),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'You have to check in before you check out.',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        action: onCheckIn != null
            ? SnackBarAction(
                label: 'Check In',
                textColor: Colors.white,
                onPressed: onCheckIn,
              )
            : null,
      ),
    );
  }

  static String extractFirstName(String fullName) {
    final trimmed = fullName.trim();
    if (trimmed.isEmpty) return 'bro';
    return trimmed.split(' ').first;
  }
}

class _CheckOutAlertDialog extends StatefulWidget {
  const _CheckOutAlertDialog({
    required this.employeeName,
    required this.companyNow,
    required this.initialIsOfficeHoursOver,
    this.checkInAt,
    this.workedDuration,
  });

  final String employeeName;
  final DateTime companyNow;
  final bool initialIsOfficeHoursOver;
  final DateTime? checkInAt;
  final Duration? workedDuration;

  @override
  State<_CheckOutAlertDialog> createState() => _CheckOutAlertDialogState();
}

class _CheckOutAlertDialogState extends State<_CheckOutAlertDialog> {
  late bool _isOfficeHoursOver;

  @override
  void initState() {
    super.initState();
    _isOfficeHoursOver = widget.initialIsOfficeHoursOver;
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final amPm = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $amPm';
  }

  String _formatDuration(Duration? d) {
    if (d == null) return '00h 00m';
    final hours = d.inHours.toString().padLeft(2, '0');
    final minutes = (d.inMinutes % 60).toString().padLeft(2, '0');
    return '${hours}h ${minutes}m';
  }

  @override
  Widget build(BuildContext context) {
    final firstName = AttendanceDialogs.extractFirstName(widget.employeeName);
    final currentTimeStr = _formatTime(widget.companyNow);

    final (
      gradientColors,
      headerIcon,
      badgeText,
      badgeBg,
      badgeFg,
      titleText,
      sweetMessage,
      confirmLabel,
      cancelLabel,
    ) = _isOfficeHoursOver
        ? (
            const [Color(0xFF6366F1), Color(0xFF4F46E5), Color(0xFF3730A3)],
            Icons.nightlife_rounded,
            'Office Hours Complete 🌙',
            const Color(0xFFEEF2FF),
            const Color(0xFF4338CA),
            'Time to Have Your Own Time! 🌙',
            'Hey $firstName! Office hours are officially over for today! 🌅 Time to have your own time, relax, and recharge for tomorrow. You did an awesome job today, bro! ✨🛋️',
            'Check Out & Relax 🛋️',
            'Stay a Bit',
          )
        : (
            const [Color(0xFFF59E0B), Color(0xFFD97706), Color(0xFFB45309)],
            Icons.schedule_rounded,
            'Office Hours in Progress ⏳',
            const Color(0xFFFFFBEB),
            const Color(0xFF92400E),
            "It's Office Time Bro! ⏳",
            "Hey $firstName! It's still office time bro! 😉 Working hours are usually until 5:00 PM. If you need to step out for personal errands or an emergency, take care and see you soon!",
            'Check Out Early',
            'Keep Working 💻',
          );

    final screenHeight = MediaQuery.sizeOf(context).height;

    return AlertDialog(
      key: const ValueKey('checkout_alert_dialog'),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
      ),
      contentPadding: EdgeInsets.zero,
      content: Container(
        width: 360,
        constraints: BoxConstraints(
          maxHeight: screenHeight * 0.85,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          color: Colors.white,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top Gradient Hero Banner
              Container(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: gradientColors,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(22),
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.28),
                          width: 2,
                        ),
                      ),
                      child: Icon(
                        headerIcon,
                        size: 26,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        badgeText,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: badgeFg,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      titleText,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ],
                ),
              ),

              // Content Body
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
                child: Column(
                  children: [
                    Text(
                      sweetMessage,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 12.5,
                        height: 1.45,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF334155),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Mini Stats Card
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Current Time',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  currentTimeStr,
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 24,
                            color: const Color(0xFFCBD5E1),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Worked Today',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _formatDuration(widget.workedDuration),
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Reviewer Demo State Switcher
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              key: const ValueKey('dialog_switch_office_time'),
                              onTap: () {
                                if (_isOfficeHoursOver) {
                                  setState(() => _isOfficeHoursOver = false);
                                }
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 5),
                                decoration: BoxDecoration(
                                  color: !_isOfficeHoursOver
                                      ? Colors.white
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: !_isOfficeHoursOver
                                      ? [
                                          BoxShadow(
                                            color: Colors.black.withValues(
                                              alpha: 0.05,
                                            ),
                                            blurRadius: 3,
                                            offset: const Offset(0, 1),
                                          ),
                                        ]
                                      : null,
                                ),
                                child: Text(
                                  'Office Time View',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: !_isOfficeHoursOver
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: !_isOfficeHoursOver
                                        ? const Color(0xFFB45309)
                                        : const Color(0xFF64748B),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              key: const ValueKey('dialog_switch_after_hours'),
                              onTap: () {
                                if (!_isOfficeHoursOver) {
                                  setState(() => _isOfficeHoursOver = true);
                                }
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 5),
                                decoration: BoxDecoration(
                                  color: _isOfficeHoursOver
                                      ? Colors.white
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: _isOfficeHoursOver
                                      ? [
                                          BoxShadow(
                                            color: Colors.black.withValues(
                                              alpha: 0.05,
                                            ),
                                            blurRadius: 3,
                                            offset: const Offset(0, 1),
                                          ),
                                        ]
                                      : null,
                                ),
                                child: Text(
                                  'After Hours View',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: _isOfficeHoursOver
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: _isOfficeHoursOver
                                        ? const Color(0xFF4338CA)
                                        : const Color(0xFF64748B),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Dialog Actions
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        key: const ValueKey('checkout_cancel_button'),
                        onPressed: () => Navigator.of(context).pop(false),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Text(
                          cancelLabel,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF475569),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        key: const ValueKey('checkout_confirm_button'),
                        onPressed: () => Navigator.of(context).pop(true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: gradientColors.first,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Text(
                          confirmLabel,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CheckInWelcomeDialog extends StatelessWidget {
  const _CheckInWelcomeDialog({
    required this.employeeName,
    required this.checkInAt,
    this.distanceMeters,
    required this.officeName,
  });

  final String employeeName;
  final DateTime checkInAt;
  final double? distanceMeters;
  final String officeName;

  String _formatTime(DateTime dt) {
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final amPm = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $amPm';
  }

  @override
  Widget build(BuildContext context) {
    final firstName = AttendanceDialogs.extractFirstName(employeeName);
    final screenHeight = MediaQuery.sizeOf(context).height;

    return AlertDialog(
      key: const ValueKey('checkin_welcome_dialog'),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
      ),
      contentPadding: EdgeInsets.zero,
      content: Container(
        width: 350,
        constraints: BoxConstraints(
          maxHeight: screenHeight * 0.85,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          color: Colors.white,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top Emerald Gradient Hero Banner
              Container(
                padding: const EdgeInsets.fromLTRB(18, 20, 18, 16),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color(0xFF10B981),
                      Color(0xFF059669),
                      Color(0xFF047857),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(22),
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.3),
                          width: 2,
                        ),
                      ),
                      child: const Center(
                        child: Text(
                          '☕',
                          style: TextStyle(fontSize: 24),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text(
                        'Ready to Build 🚀',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF065F46),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Welcome to Work, $firstName! 💻',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),

              // Content Body
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
                child: Column(
                  children: [
                    Text(
                      'Hey $firstName, take a coffee and code, and don\'t forget to commit! ☕💻🚀',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.45,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Location and check-in confirmation pill
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFBBF7D0)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.verified_rounded,
                            size: 15,
                            color: Color(0xFF16A34A),
                          ),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              'Checked in at ${_formatTime(checkInAt)}${distanceMeters != null ? ' • ~${distanceMeters!.round()}m from $officeName' : ''}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF166534),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Action Button
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
                child: ElevatedButton(
                  key: const ValueKey('checkin_lets_code_button'),
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF059669),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Let\'s Code! 🚀',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AttendanceCompletedDialog extends StatelessWidget {
  const _AttendanceCompletedDialog({
    required this.employeeName,
    this.checkInAt,
    this.checkOutAt,
    this.workedDuration,
    required this.companyTimezone,
    required this.officeName,
  });

  final String employeeName;
  final DateTime? checkInAt;
  final DateTime? checkOutAt;
  final Duration? workedDuration;
  final String companyTimezone;
  final String officeName;

  String _formatTime(DateTime? dt) {
    if (dt == null) return '--:--';
    final local = CompanyClock.toCompanyTimezone(dt, companyTimezone);
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final amPm = local.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $amPm';
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours.toString().padLeft(2, '0');
    final minutes = (d.inMinutes % 60).toString().padLeft(2, '0');
    return '${hours}h ${minutes}m';
  }

  @override
  Widget build(BuildContext context) {
    final firstName = AttendanceDialogs.extractFirstName(employeeName);
    final screenHeight = MediaQuery.sizeOf(context).height;

    // Calculate effective worked duration
    final effectiveDuration = workedDuration ??
        ((checkInAt != null && checkOutAt != null)
            ? checkOutAt!.difference(checkInAt!)
            : Duration.zero);

    final durationFormatted = _formatDuration(effectiveDuration);
    final checkInStr = _formatTime(checkInAt);
    final checkOutStr = _formatTime(checkOutAt);

    return AlertDialog(
      key: const ValueKey('attendance_completed_dialog'),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
      ),
      contentPadding: EdgeInsets.zero,
      content: Container(
        width: 360,
        constraints: BoxConstraints(
          maxHeight: screenHeight * 0.85,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          color: Colors.white,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top Gradient Hero Banner (Evening / Completed Purple Theme)
              Container(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color(0xFF6366F1),
                      Color(0xFF4F46E5),
                      Color(0xFF3730A3),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(22),
                  ),
                ),
                child: Stack(
                  alignment: Alignment.topCenter,
                  children: [
                    // Top-right close button (clean dismiss, no bottom action buttons)
                    Positioned(
                      top: 0,
                      right: 0,
                      child: InkWell(
                        key: const ValueKey('completed_dialog_close_button'),
                        onTap: () => Navigator.of(context).pop(),
                        borderRadius: BorderRadius.circular(999),
                        child: Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close_rounded,
                            size: 18,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    Column(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.28),
                              width: 2,
                            ),
                          ),
                          child: const Center(
                            child: Text(
                              '🌙',
                              style: TextStyle(fontSize: 24),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 3.5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Text(
                            'Office Hours Complete 🌙',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF4338CA),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Time to Have Your Own Time! 🌙',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Content Body
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 22),
                child: Column(
                  children: [
                    Text(
                      'Hey $firstName! Office hours are officially over for today! 🌅 Time to have your own time, relax, and recharge for tomorrow. You did an awesome job today, bro! ✨🛋️',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 12.5,
                        height: 1.45,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF334155),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Check-in and Check-out Times Display
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          // Check In Block
                          Expanded(
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981)
                                        .withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.login_rounded,
                                    size: 16,
                                    color: Color(0xFF059669),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Check In',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF64748B),
                                        ),
                                      ),
                                      const SizedBox(height: 1),
                                      Text(
                                        checkInStr,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF0F172A),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 32,
                            color: const Color(0xFFCBD5E1),
                          ),
                          const SizedBox(width: 10),
                          // Check Out Block
                          Expanded(
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF6366F1)
                                        .withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.logout_rounded,
                                    size: 16,
                                    color: Color(0xFF4F46E5),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Check Out',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF64748B),
                                        ),
                                      ),
                                      const SizedBox(height: 1),
                                      Text(
                                        checkOutStr,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF0F172A),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Hours Worked Highlight Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFFEEF2FF),
                            Color(0xFFE0E7FF),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFC7D2FE)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.timer_outlined,
                              size: 20,
                              color: Color(0xFF4F46E5),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Worked Today',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF6366F1),
                                    letterSpacing: 0.3,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  durationFormatted,
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF1E1B4B),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'You have worked $durationFormatted on here today! 🎉',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF4338CA),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CheckInRequiredDialog extends StatelessWidget {
  const _CheckInRequiredDialog({
    required this.employeeName,
    this.onCheckIn,
  });

  final String employeeName;
  final VoidCallback? onCheckIn;

  @override
  Widget build(BuildContext context) {
    final firstName = AttendanceDialogs.extractFirstName(employeeName);
    final screenHeight = MediaQuery.sizeOf(context).height;

    return AlertDialog(
      key: const ValueKey('checkin_required_dialog'),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
      ),
      contentPadding: EdgeInsets.zero,
      content: Container(
        width: 350,
        constraints: BoxConstraints(
          maxHeight: screenHeight * 0.85,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          color: Colors.white,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Amber Warning Hero Banner
              Container(
                padding: const EdgeInsets.fromLTRB(18, 20, 18, 16),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color(0xFFF59E0B),
                      Color(0xFFD97706),
                      Color(0xFFB45309),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(22),
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.3),
                          width: 2,
                        ),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.login_rounded,
                          size: 26,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 3.5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text(
                        'Check In Required ⏳',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF92400E),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Check In Required! ⏳',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ],
                ),
              ),

              // Content Body
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                child: Column(
                  children: [
                    Text(
                      'Hey $firstName! You have to check in before you check out.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Your working hours cannot be recorded until you log your check-in for today. Please tap Check In to start your work session.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF64748B),
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),

              // Action Buttons
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 4, 18, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        key: const ValueKey('checkin_required_cancel_button'),
                        onPressed: () => Navigator.of(context).pop(false),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          'Dismiss',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF475569),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        key: const ValueKey('checkin_required_confirm_button'),
                        onPressed: () {
                          Navigator.of(context).pop(true);
                          onCheckIn?.call();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF059669),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          'Check In Now 🚀',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
