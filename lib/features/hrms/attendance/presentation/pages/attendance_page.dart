import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../../../core/config/app_config.dart';
import '../../../../../core/di/injection_container.dart';
import '../../../../../core/location/location_service.dart';
import '../../../../../core/location/location_simulator_sheet.dart';
import '../../../../../core/location/office_range_control.dart';
import '../../../../../core/sync/sync_status.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/time/company_clock.dart';
import '../../../../../core/widgets/attendance_feedback_handler.dart';
import '../../../../../core/widgets/sync_status_chip.dart';
import '../../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../../auth/presentation/bloc/auth_state.dart';
import '../../domain/entities/attendance_record.dart';
import '../bloc/attendance_bloc.dart';
import '../bloc/attendance_event.dart';
import '../bloc/attendance_state.dart';
import '../widgets/attendance_detail_sheet.dart';

class AttendancePage extends StatefulWidget {
  const AttendancePage({super.key});

  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage> {
  @override
  void initState() {
    super.initState();
    context
        .read<AttendanceBloc>()
        .add(const LoadAttendanceRequested(refreshRemote: true));
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;
    final employee =
        authState is AuthAuthenticated ? authState.session.employee : null;
    final defaults = sl<AppConfig>().employeeConfig;
    final locationService = sl<LocationService>();
    final officeName = employee?.officeName ?? defaults.officeName;
    final officeLat = employee?.officeLatitude ?? defaults.officeLatitude;
    final officeLng = employee?.officeLongitude ?? defaults.officeLongitude;
    final companyTimezone =
        employee?.companyTimezone ?? defaults.companyTimezone;

    return BlocConsumer<AttendanceBloc, AttendanceState>(
      listenWhen: (prev, curr) =>
          curr.feedbackSequence != prev.feedbackSequence,
      listener: (context, state) {
        AttendanceFeedbackHandler.show(
          context: context,
          locationService: locationService,
          officeName: officeName,
          officeLatitude: officeLat,
          officeLongitude: officeLng,
          errorMessage: state.errorMessage,
          failure: state.lastFailure,
          feedbackMessage: state.feedbackMessage,
        );
      },
      builder: (context, state) {
        final totalLogged = state.history.length;
        final pendingCount = state.history
            .where((r) => r.syncStatus == RecordSyncStatus.pending)
            .length;

        return SafeArea(
          top: false,
          child: RefreshIndicator(
            onRefresh: () async {
              context
                  .read<AttendanceBloc>()
                  .add(const LoadAttendanceRequested(refreshRemote: true));
            },
            child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
            children: [
              _AttendanceHeroCard(
                record: state.todayRecord,
                officeName: officeName,
                companyTimezone: companyTimezone,
                locationService: locationService,
                onConfigureLocation: () => LocationSimulatorSheet.show(
                  context,
                  locationService: locationService,
                  officeName: officeName,
                  officeLatitude: officeLat,
                  officeLongitude: officeLng,
                ),
                isSubmitting: state.status == AttendanceViewStatus.submitting,
                onCheckIn: () {
                  context.read<AttendanceBloc>().add(
                        CheckInSubmitted(workLocation: officeName),
                      );
                },
                onCheckOut: () {
                  context
                      .read<AttendanceBloc>()
                      .add(const CheckOutSubmitted());
                },
              ),
              const SizedBox(height: 16),
              // Quick summary pills strip
              Row(
                children: [
                  Expanded(
                    child: _StatPillCard(
                      label: 'Logged Days',
                      value: '$totalLogged',
                      icon: Icons.event_available_rounded,
                      iconColor: AppTheme.primary,
                      iconBg: AppTheme.primarySoft,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatPillCard(
                      label: 'Pending Sync',
                      value: '$pendingCount',
                      icon: Icons.cloud_upload_outlined,
                      iconColor: pendingCount > 0
                          ? const Color(0xFFD97706)
                          : const Color(0xFF10B981),
                      iconBg: pendingCount > 0
                          ? const Color(0xFFFFFBEB)
                          : const Color(0xFFECFDF5),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Text(
                'Attendance History',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 12),
              if (state.status == AttendanceViewStatus.loading &&
                  state.history.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  ),
                )
              else if (state.history.isEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 28,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.border),
                    boxShadow: AppTheme.cardShadow,
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: const BoxDecoration(
                          color: Color(0xFFF1F5F9),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.schedule_outlined,
                          size: 22,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'No attendance logs yet',
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Check in above to record today\'s attendance. Offline check-ins sync automatically when connected.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.border),
                    boxShadow: AppTheme.cardShadow,
                  ),
                  child: Column(
                    children: [
                      for (var i = 0; i < state.history.length; i++) ...[
                        if (i > 0)
                          const Divider(
                            height: 1,
                            indent: 70,
                            endIndent: 16,
                            color: AppTheme.border,
                          ),
                        _AttendanceHistoryRow(
                          record: state.history[i],
                          companyTimezone: companyTimezone,
                          onTap: () => AttendanceDetailSheet.show(
                            context,
                            state.history[i],
                            companyTimezone: companyTimezone,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
            ],
          ),
          ),
        );
      },
    );
  }
}

class _AttendanceHeroCard extends StatelessWidget {
  const _AttendanceHeroCard({
    required this.record,
    required this.officeName,
    required this.companyTimezone,
    required this.locationService,
    required this.onConfigureLocation,
    required this.isSubmitting,
    required this.onCheckIn,
    required this.onCheckOut,
  });

  final AttendanceRecord? record;
  final String officeName;
  final String companyTimezone;
  final LocationService locationService;
  final VoidCallback onConfigureLocation;
  final bool isSubmitting;
  final VoidCallback onCheckIn;
  final VoidCallback onCheckOut;

  @override
  Widget build(BuildContext context) {
    final companyNow = sl<CompanyClock>().nowInTimezone(companyTimezone);
    final dateLabel = DateFormat('EEEE, d MMM yyyy').format(companyNow);
    final timeFormat = DateFormat('hh:mm a');
    final isCheckedIn = record?.isCheckedIn ?? false;
    final isCompleted = record?.isCompleted ?? false;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.inkDark,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.inkDark.withValues(alpha: 0.16),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Daily Attendance',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      dateLabel,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: Colors.white.withValues(alpha: 0.68),
                      ),
                    ),
                  ],
                ),
              ),
              if (record != null) SyncStatusChip(status: record!.syncStatus),
            ],
          ),
          const SizedBox(height: 14),
          OfficeRangeControl(
            locationService: locationService,
            officeName: officeName,
            onOpenMoreOptions: onConfigureLocation,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _TimeBlock(
                  label: 'Check In',
                  value: record?.checkInAt != null
                      ? timeFormat.format(
                          CompanyClock.toCompanyTimezone(
                            record!.checkInAt!,
                            companyTimezone,
                          ),
                        )
                      : '--:--',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _TimeBlock(
                  label: 'Check Out',
                  value: record?.checkOutAt != null
                      ? timeFormat.format(
                          CompanyClock.toCompanyTimezone(
                            record!.checkOutAt!,
                            companyTimezone,
                          ),
                        )
                      : '--:--',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton.icon(
              onPressed: isSubmitting || isCompleted
                  ? null
                  : (isCheckedIn ? onCheckOut : onCheckIn),
              style: FilledButton.styleFrom(
                backgroundColor: isCompleted
                    ? Colors.white.withValues(alpha: 0.14)
                    : (isCheckedIn ? const Color(0xFFEF4444) : Colors.white),
                foregroundColor: isCompleted
                    ? Colors.white.withValues(alpha: 0.6)
                    : (isCheckedIn ? Colors.white : AppTheme.inkDark),
                disabledBackgroundColor: Colors.white.withValues(alpha: 0.12),
                disabledForegroundColor: Colors.white.withValues(alpha: 0.55),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: isSubmitting
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: isCheckedIn ? Colors.white : AppTheme.inkDark,
                      ),
                    )
                  : Icon(
                      isCompleted
                          ? Icons.check_circle_outline_rounded
                          : (isCheckedIn
                              ? Icons.logout_rounded
                              : Icons.login_rounded),
                      size: 19,
                    ),
              label: Text(
                isCompleted
                    ? 'Checked Out for Today'
                    : (isCheckedIn ? 'Check Out' : 'Check In'),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatPillCard extends StatelessWidget {
  const _StatPillCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.iconColor,
    required this.iconBg,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color iconColor;
  final Color iconBg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                ),
              ),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11.5,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TimeBlock extends StatelessWidget {
  const _TimeBlock({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.white.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _AttendanceHistoryRow extends StatelessWidget {
  const _AttendanceHistoryRow({
    required this.record,
    required this.companyTimezone,
    required this.onTap,
  });

  final AttendanceRecord record;
  final String companyTimezone;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dayNum = DateFormat('dd').format(record.date);
    final monthShort = DateFormat('MMM').format(record.date).toUpperCase();
    final weekday = DateFormat('EEEE').format(record.date);
    final timeFormat = DateFormat('hh:mm a');
    final inText = record.checkInAt != null
        ? timeFormat.format(
            CompanyClock.toCompanyTimezone(record.checkInAt!, companyTimezone),
          )
        : '--:--';
    final outText = record.checkOutAt != null
        ? timeFormat.format(
            CompanyClock.toCompanyTimezone(record.checkOutAt!, companyTimezone),
          )
        : '--:--';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  dayNum,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                    height: 1.05,
                  ),
                ),
                Text(
                  monthShort,
                  style: const TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textSecondary,
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  weekday,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '$inText  →  $outText',
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppTheme.textSecondary,
                  ),
                ),
                if (record.checkInLatitude != null &&
                    record.checkInLongitude != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    'GPS: ${record.checkInLatitude!.toStringAsFixed(4)}, ${record.checkInLongitude!.toStringAsFixed(4)}'
                    '${record.checkInDistanceMeters != null ? ' • ${record.checkInDistanceMeters!.round()}m' : ''}',
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: AppTheme.textMuted,
                    ),
                  ),
                ],
                if (record.syncError != null && record.syncError!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    record.syncError!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFFB91C1C),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          SyncStatusChip(status: record.syncStatus),
        ],
      ),
      ),
    );
  }
}
