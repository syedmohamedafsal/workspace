import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../../core/config/app_config.dart';
import '../../../../../core/di/injection_container.dart';
import '../../../../../core/location/location_service.dart';
import '../../../../../core/location/location_simulator_sheet.dart';
import '../../../../../core/location/office_geofence_map.dart';
import '../../../../../core/location/office_range_control.dart';
import '../../../../../core/router/app_router.dart';
import '../../../../../core/sync/sync_manager.dart';
import '../../../../../core/sync/sync_status.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/time/company_clock.dart';
import '../../../../../core/widgets/attendance_dialogs.dart';
import '../../../../../core/widgets/attendance_feedback_handler.dart';
import '../../../../../core/widgets/sync_feedback_handler.dart';
import '../../../../../core/widgets/sync_status_banner.dart';
import '../../../../../core/widgets/sync_status_chip.dart';
import '../../../../auth/domain/entities/employee.dart';
import '../../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../../auth/presentation/bloc/auth_state.dart';
import '../../../attendance/domain/entities/attendance_record.dart';
import '../../../attendance/presentation/bloc/attendance_bloc.dart';
import '../../../attendance/presentation/bloc/attendance_event.dart';
import '../../../attendance/presentation/bloc/attendance_state.dart';
import '../../../attendance/presentation/widgets/attendance_detail_sheet.dart';
import '../../../leave/domain/entities/leave_balance.dart';
import '../../../leave/domain/entities/leave_request.dart';
import '../../../leave/presentation/bloc/leave_bloc.dart';
import '../../../leave/presentation/bloc/leave_event.dart';
import '../../../leave/presentation/bloc/leave_state.dart';

/// Employee Dashboard styled with the curved corporate blue top header,
/// Online/Sync status pill, employee profile bar, overlapping dark-navy office
/// summary card (Presence / Sick / Casual), green Check In & orange Check Out
/// tiles, Inside-200m office range control, and latest five attendance records.
class EmployeeDashboardPage extends StatefulWidget {
  const EmployeeDashboardPage({super.key});

  @override
  State<EmployeeDashboardPage> createState() => _EmployeeDashboardPageState();
}

class _EmployeeDashboardPageState extends State<EmployeeDashboardPage> {
  Timer? _elapsedTicker;

  @override
  void initState() {
    super.initState();
    _loadData();
    _elapsedTicker = Timer.periodic(
      const Duration(seconds: 30),
      (_) {
        if (mounted) setState(() {});
      },
    );
  }

  @override
  void dispose() {
    _elapsedTicker?.cancel();
    super.dispose();
  }

  void _loadData({bool refreshRemote = true}) {
    context
        .read<AttendanceBloc>()
        .add(LoadAttendanceRequested(refreshRemote: refreshRemote));
    context
        .read<LeaveBloc>()
        .add(LoadLeaveDataRequested(refreshRemote: refreshRemote));
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;
    final employee =
        authState is AuthAuthenticated ? authState.session.employee : null;
    final defaults = sl<AppConfig>().employeeConfig;
    final locationService = sl<LocationService>();
    final syncManager = sl<SyncManager>();

    final officeName = employee?.officeName ?? defaults.officeName;
    final officeLat = employee?.officeLatitude ?? defaults.officeLatitude;
    final officeLng = employee?.officeLongitude ?? defaults.officeLongitude;
    final allowedRadiusMeters = sl<AppConfig>().allowedAttendanceRadiusMeters;
    final companyTimezone =
        employee?.companyTimezone ?? defaults.companyTimezone;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: BlocConsumer<AttendanceBloc, AttendanceState>(
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
        builder: (context, attendanceState) {
          return BlocBuilder<LeaveBloc, LeaveState>(
            builder: (context, leaveState) {
              final isInitialLoading =
                  attendanceState.status == AttendanceViewStatus.loading &&
                      attendanceState.history.isEmpty &&
                      attendanceState.todayRecord == null;

              if (isInitialLoading) {
                return const SafeArea(
                  child: _DashboardLoadingView(),
                );
              }

              if (attendanceState.status == AttendanceViewStatus.failure &&
                  attendanceState.history.isEmpty) {
                return SafeArea(
                  child: _DashboardErrorState(
                    message: attendanceState.errorMessage ??
                        'Unable to load dashboard data.',
                    onRetry: () => _loadData(),
                  ),
                );
              }

              final latestFive = attendanceState.history.take(5).toList();
              final visibleBalances = _selectCasualAndSick(leaveState.balances);
              final sickBalance = _findBalance(
                leaveState.balances,
                LeaveType.sick,
              );
              final casualBalance = _findBalance(
                leaveState.balances,
                LeaveType.casual,
              );

              return SafeArea(
                bottom: false,
                child: Container(
                  color: AppTheme.background,
                  child: RefreshIndicator(
                    onRefresh: () async => _loadData(refreshRemote: true),
                    child: ListView(
                      padding: const EdgeInsets.only(bottom: 28),
                      children: [
                        // Curved blue top header + overlapping office & check-in/out card
                        _TopHeaderAndOverviewStack(
                          employee: employee,
                      officeName: officeName,
                      officeLatitude: officeLat,
                      officeLongitude: officeLng,
                      allowedRadiusMeters: allowedRadiusMeters,
                      companyTimezone: companyTimezone,
                      syncManager: syncManager,
                      locationService: locationService,
                      todayRecord: attendanceState.todayRecord,
                      presenceDays: attendanceState.history.length,
                      sickDays: sickBalance?.remainingDays ?? 0,
                      casualDays: casualBalance?.remainingDays ?? 0,
                      isSubmitting: attendanceState.status ==
                          AttendanceViewStatus.submitting,
                      onCheckIn: () {
                        context.read<AttendanceBloc>().add(
                              CheckInSubmitted(
                                workLocation: officeName,
                                employeeName: employee?.employeeName ??
                                    defaults.employeeName,
                              ),
                            );
                      },
                      onCheckOut: () async {
                        final confirmed =
                            await AttendanceDialogs.showCheckOutConfirmation(
                          context: context,
                          employeeName:
                              employee?.employeeName ?? defaults.employeeName,
                          companyTimezone: companyTimezone,
                          checkInAt: attendanceState.todayRecord?.checkInAt,
                          workedDuration:
                              attendanceState.todayRecord?.workedDuration,
                        );
                        if (confirmed == true && context.mounted) {
                          context.read<AttendanceBloc>().add(
                                CheckOutSubmitted(
                                  employeeName: employee?.employeeName ??
                                      defaults.employeeName,
                                ),
                              );
                        }
                      },
                      onOpenLocationSimulator: () =>
                          LocationSimulatorSheet.show(
                        context,
                        locationService: locationService,
                        officeName: officeName,
                        officeLatitude: officeLat,
                        officeLongitude: officeLng,
                      ),
                      onResetToday: () {
                        context.read<AttendanceBloc>().add(
                              ResetTodayAttendanceRequested(
                                employeeName: employee?.employeeName ??
                                    defaults.employeeName,
                              ),
                            );
                      },
                    ),
                    // Offline / pending sync banner when applicable
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: SyncStatusBanner(syncManager: syncManager),
                      ),
                    ),
                    // Available Leave Balance cards
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                      child: _SectionHeader(
                        title: 'Available Leave Balance',
                        actionLabel: 'Apply Leave',
                        onAction: () => context.go(AppRoutes.leave),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: visibleBalances.isEmpty
                          ? const _EmptyBlockCard(
                              icon: Icons.event_available_outlined,
                              title: 'Leave balance unavailable',
                              subtitle:
                                  'Pull down to refresh once connectivity returns.',
                            )
                          : Row(
                              children: [
                                for (var i = 0;
                                    i < visibleBalances.length;
                                    i++) ...[
                                  if (i > 0) const SizedBox(width: 12),
                                  Expanded(
                                    child: _LeaveBalanceQuotaCard(
                                      balance: visibleBalances[i],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                    ),
                    // Latest five attendance records
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 22, 16, 0),
                      child: _SectionHeader(
                        title: 'Recent Attendance',
                        actionLabel: 'View all',
                        onAction: () => context.go(AppRoutes.attendance),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: latestFive.isEmpty
                          ? _EmptyBlockCard(
                              icon: Icons.schedule_outlined,
                              title: 'No attendance records yet',
                              subtitle:
                                  'Tap Check In above to start logging your workday.',
                              actionLabel: 'Refresh',
                              onAction: () => _loadData(refreshRemote: true),
                            )
                          : Column(
                              children: [
                                for (var i = 0; i < latestFive.length; i++) ...[
                                  if (i > 0) const SizedBox(height: 10),
                                  _RecentAttendanceRow(
                                    record: latestFive[i],
                                    companyTimezone: companyTimezone,
                                    onTap: () => AttendanceDetailSheet.show(
                                      context,
                                      latestFive[i],
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
            ),
          );
        },
          );
        },
      ),
    );
  }

  LeaveBalance? _findBalance(List<LeaveBalance> all, LeaveType type) {
    for (final b in all) {
      if (b.leaveType == type) return b;
    }
    return null;
  }

  List<LeaveBalance> _selectCasualAndSick(List<LeaveBalance> all) {
    final preferred = all
        .where(
          (b) => b.leaveType == LeaveType.casual || b.leaveType == LeaveType.sick,
        )
        .toList();
    if (preferred.isNotEmpty) return preferred;
    return all.take(2).toList();
  }
}

class _TopHeaderAndOverviewStack extends StatelessWidget {
  const _TopHeaderAndOverviewStack({
    required this.employee,
    required this.officeName,
    required this.officeLatitude,
    required this.officeLongitude,
    required this.allowedRadiusMeters,
    required this.companyTimezone,
    required this.syncManager,
    required this.locationService,
    required this.todayRecord,
    required this.presenceDays,
    required this.sickDays,
    required this.casualDays,
    required this.isSubmitting,
    required this.onCheckIn,
    required this.onCheckOut,
    required this.onOpenLocationSimulator,
    required this.onResetToday,
  });

  final Employee? employee;
  final String officeName;
  final double officeLatitude;
  final double officeLongitude;
  final double allowedRadiusMeters;
  final String companyTimezone;
  final SyncManager syncManager;
  final LocationService locationService;
  final AttendanceRecord? todayRecord;
  final int presenceDays;
  final double sickDays;
  final double casualDays;
  final bool isSubmitting;
  final VoidCallback onCheckIn;
  final VoidCallback onCheckOut;
  final VoidCallback onOpenLocationSimulator;
  final VoidCallback onResetToday;

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  String _fmtCount(double value) =>
      value % 1 == 0 ? value.toStringAsFixed(0) : value.toStringAsFixed(1);

  String _formatDuration(Duration? duration) {
    if (duration == null) return '00h 00m';
    final h = duration.inHours.toString().padLeft(2, '0');
    final m = (duration.inMinutes % 60).toString().padLeft(2, '0');
    return '${h}h ${m}m';
  }

  @override
  Widget build(BuildContext context) {
    final companyNow = sl<CompanyClock>().nowInTimezone(companyTimezone);
    final dateLabel = DateFormat('d MMMM yyyy').format(companyNow);
    final timeFmt = DateFormat('hh:mm');
    final periodFmt = DateFormat('a');
    final checkInLocal = todayRecord?.checkInAt != null
        ? CompanyClock.toCompanyTimezone(
            todayRecord!.checkInAt!,
            companyTimezone,
          )
        : null;
    final checkOutLocal = todayRecord?.checkOutAt != null
        ? CompanyClock.toCompanyTimezone(
            todayRecord!.checkOutAt!,
            companyTimezone,
          )
        : null;
    final isCheckedIn = todayRecord?.isCheckedIn ?? false;
    final isCheckedOut = todayRecord?.isCompleted ?? false;

    final (statusLabel, statusBg, statusFg) = isCheckedOut
        ? (
            'Checked Out',
            Colors.white.withValues(alpha: 0.16),
            const Color(0xFFE2E8F0),
          )
        : isCheckedIn
            ? (
                'Checked In',
                const Color(0xFF10B981).withValues(alpha: 0.25),
                const Color(0xFF86EFAC),
              )
            : (
                'Not Checked In',
                const Color(0xFFF59E0B).withValues(alpha: 0.24),
                const Color(0xFFFDE68A),
              );

    return Stack(
      children: [
        // Curved corporate blue background
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: 245,
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF1575C8),
                  Color(0xFF147BB8),
                  Color(0xFF1383AD),
                ],
              ),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(28),
                bottomRight: Radius.circular(28),
              ),
            ),
          ),
        ),
        // Foreground content safely inside SafeArea
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Row 1: Official TEQBAE brand logo + Online / Sync pill
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Image.asset(
                    'assets/images/teqbae_logo_transparent.png',
                    height: 30,
                    fit: BoxFit.contain,
                  ),
                  StreamBuilder<SyncSnapshot>(
                    stream: syncManager.statusStream,
                    initialData: syncManager.currentSnapshot,
                    builder: (context, snapshot) {
                      final sync = snapshot.data ?? const SyncSnapshot();
                      final isOnline = sync.isOnline;
                      final bg = isOnline
                          ? const Color(0xFFDDFAC8)
                          : const Color(0xFFFEF3C7);
                      final fg = isOnline
                          ? const Color(0xFF3F7D20)
                          : const Color(0xFF92400E);
                      final label = sync.isSyncing
                          ? 'Syncing...'
                          : isOnline
                              ? (sync.pendingCount > 0
                                  ? 'Sync (${sync.pendingCount})'
                                  : 'Online')
                              : 'Offline';

                      return Material(
                        color: bg,
                        borderRadius: BorderRadius.circular(999),
                        child: InkWell(
                          onTap: sync.isSyncing
                              ? null
                              : () => SyncFeedbackHandler.performSync(
                                    context: context,
                                    syncManager: syncManager,
                                  ),
                          borderRadius: BorderRadius.circular(999),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 6,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (sync.isSyncing)
                                  SizedBox(
                                    width: 13,
                                    height: 13,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: fg,
                                    ),
                                  )
                                else
                                  Icon(
                                    isOnline
                                        ? Icons.swap_vert_rounded
                                        : Icons.wifi_off_rounded,
                                    size: 16,
                                    color: fg,
                                  ),
                                const SizedBox(width: 5),
                                Text(
                                  label,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: fg,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 18),
              // Row 2: Employee Avatar + Name / Department • ID + Quick Action Circle
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.7),
                        width: 2,
                      ),
                    ),
                    child: Text(
                      _initials(employee?.employeeName ?? 'REBS'),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1575C8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          employee?.employeeName ?? 'Employee',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          employee != null
                              ? '${employee!.employeeId} • ${employee!.department}'
                              : '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withValues(alpha: 0.85),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Material(
                    color: Colors.white.withValues(alpha: 0.18),
                    shape: CircleBorder(
                      side: BorderSide(
                        color: Colors.white.withValues(alpha: 0.45),
                        width: 1.2,
                      ),
                    ),
                    child: InkWell(
                      onTap: onOpenLocationSimulator,
                      customBorder: const CircleBorder(),
                      child: const SizedBox(
                        width: 42,
                        height: 42,
                        child: Icon(
                          Icons.my_location_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Row 3: Two-layer stacked Navy Office Banner + White Summary Card
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF162A56),
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0F172A).withValues(alpha: 0.12),
                      blurRadius: 22,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Dark navy top strip with office name & today status
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 14, 12),
                      child: Row(
                        children: [
                          Container(
                            width: 26,
                            height: 26,
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0A0B0D),
                              borderRadius: BorderRadius.circular(7),
                            ),
                            child: Image.asset(
                              'assets/images/teqbae_mark.png',
                              fit: BoxFit.contain,
                            ),
                          ),
                          const SizedBox(width: 9),
                          Expanded(
                            child: Text(
                              officeName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: statusBg,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              statusLabel,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: statusFg,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Crisp white inner card with 3-column metrics + blue Check In / Out panel
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF6FBFF),
                        borderRadius: BorderRadius.circular(22),
                      ),
                      padding: const EdgeInsets.fromLTRB(14, 18, 14, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // 3-Column KPI row: Presence | Sick | Casual
                          IntrinsicHeight(
                            child: Row(
                              children: [
                                Expanded(
                                  child: _KpiColumn(
                                    label: 'Presence',
                                    value: '$presenceDays',
                                    unit: 'Days',
                                  ),
                                ),
                                Container(
                                  width: 1.5,
                                  margin:
                                      const EdgeInsets.symmetric(vertical: 4),
                                  color: const Color(0xFF1E293B),
                                ),
                                Expanded(
                                  child: _KpiColumn(
                                    label: 'Sick',
                                    value: _fmtCount(sickDays),
                                    unit: 'Days',
                                  ),
                                ),
                                Container(
                                  width: 1.5,
                                  margin:
                                      const EdgeInsets.symmetric(vertical: 4),
                                  color: const Color(0xFF1E293B),
                                ),
                                Expanded(
                                  child: _KpiColumn(
                                    label: 'Casual',
                                    value: _fmtCount(casualDays),
                                    unit: 'Days',
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Swipeable Deep-Navy Panel: Attendance Check In/Out <-> 200m Office Map
                          _SwipeableAttendancePanel(
                            dateLabel: dateLabel,
                            durationLabel: _formatDuration(
                              todayRecord?.workedDuration,
                            ),
                            checkInTimeText: checkInLocal != null
                                ? timeFmt.format(checkInLocal)
                                : '--:--',
                            checkInZoneTag: checkInLocal != null
                                ? periodFmt.format(checkInLocal)
                                : '',
                            checkOutTimeText: checkOutLocal != null
                                ? timeFmt.format(checkOutLocal)
                                : '--:--',
                            checkOutZoneTag: checkOutLocal != null
                                ? periodFmt.format(checkOutLocal)
                                : '',
                            todayRecord: todayRecord,
                            isCheckedIn: isCheckedIn,
                            isCheckedOut: isCheckedOut,
                            isSubmitting: isSubmitting,
                            onCheckIn: onCheckIn,
                            onCheckOut: onCheckOut,
                            onResetToday: onResetToday,
                            employeeName: employee?.employeeName ??
                                sl<AppConfig>().employeeConfig.employeeName,
                            officeName: officeName,
                            officeLatitude: officeLatitude,
                            officeLongitude: officeLongitude,
                            allowedRadiusMeters: allowedRadiusMeters,
                            locationService: locationService,
                          ),
                          const SizedBox(height: 12),
                          // Inside 200m toggle + Outside Office warning notice
                          OfficeRangeControl(
                            locationService: locationService,
                            officeName: officeName,
                            officeLatitude: officeLatitude,
                            officeLongitude: officeLongitude,
                            allowedRadiusMeters: allowedRadiusMeters,
                            isLightSurface: true,
                            onOpenMoreOptions: onOpenLocationSimulator,
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
    );
  }
}

class _SwipeableAttendancePanel extends StatefulWidget {
  const _SwipeableAttendancePanel({
    required this.dateLabel,
    required this.durationLabel,
    required this.checkInTimeText,
    required this.checkInZoneTag,
    required this.checkOutTimeText,
    required this.checkOutZoneTag,
    required this.todayRecord,
    required this.isCheckedIn,
    required this.isCheckedOut,
    required this.isSubmitting,
    required this.onCheckIn,
    required this.onCheckOut,
    required this.onResetToday,
    required this.employeeName,
    required this.officeName,
    required this.officeLatitude,
    required this.officeLongitude,
    required this.allowedRadiusMeters,
    required this.locationService,
  });

  final String dateLabel;
  final String durationLabel;
  final String checkInTimeText;
  final String checkInZoneTag;
  final String checkOutTimeText;
  final String checkOutZoneTag;
  final AttendanceRecord? todayRecord;
  final bool isCheckedIn;
  final bool isCheckedOut;
  final bool isSubmitting;
  final VoidCallback onCheckIn;
  final VoidCallback onCheckOut;
  final VoidCallback onResetToday;
  final String employeeName;
  final String officeName;
  final double officeLatitude;
  final double officeLongitude;
  final double allowedRadiusMeters;
  final LocationService locationService;

  @override
  State<_SwipeableAttendancePanel> createState() =>
      _SwipeableAttendancePanelState();
}

class _SwipeableAttendancePanelState extends State<_SwipeableAttendancePanel> {
  late final PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goToPage(int index) {
    if (index == _currentPage) return;
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMapPage = _currentPage == 1;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF132245),
            Color(0xFF1E3261),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Panel Header: Date/Duration (Page 0) or Office Geofence (Page 1) + Switcher Pill
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isMapPage ? 'Office Geofence' : widget.dateLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isMapPage
                          ? '${widget.allowedRadiusMeters.round()}m Permitted Radius'
                          : widget.durationLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: isMapPage
                            ? const Color(0xFF6EE7B7)
                            : Colors.white.withValues(alpha: 0.78),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Compact Frosted Switcher Pill: Clock | Map
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.14),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _PanelTabChip(
                      key: const ValueKey('panel_tab_attendance'),
                      icon: Icons.access_time_filled_rounded,
                      label: 'Clock',
                      isSelected: !isMapPage,
                      onTap: () => _goToPage(0),
                    ),
                    const SizedBox(width: 2),
                    _PanelTabChip(
                      key: const ValueKey('panel_tab_map'),
                      icon: Icons.map_rounded,
                      label: 'Map',
                      isSelected: isMapPage,
                      onTap: () => _goToPage(1),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Swipeable Content: Page 0 = Check In / Out Tiles, Page 1 = 200m Office Map
          AnimatedContainer(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            height: isMapPage ? 208 : 142,
            child: PageView(
              key: const ValueKey('attendance_map_page_view'),
              controller: _pageController,
              onPageChanged: (index) {
                if (_currentPage != index) {
                  setState(() => _currentPage = index);
                }
              },
              children: [
                // Page 0: Check In / Check Out gradient tiles + swipe hint / sync chip
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _AttendanceColorTile(
                            key: const ValueKey('dashboard_check_in_tile'),
                            timeText: widget.checkInTimeText,
                            zoneTag: widget.checkInZoneTag,
                            label: 'Check In',
                            icon: Icons.login_rounded,
                            gradientColors: const [
                              Color(0xFF22C58B),
                              Color(0xFF0D9488),
                              Color(0xFF0E7490),
                            ],
                            disabledGradientColors: const [
                              Color(0xFF14B8A6),
                              Color(0xFF0F766E),
                              Color(0xFF155E75),
                            ],
                            isLoading:
                                widget.isSubmitting && !widget.isCheckedIn,
                            isDisabled: widget.isCheckedIn ||
                                widget.isCheckedOut,
                            onTap: () {
                              if (!widget.isCheckedIn && !widget.isCheckedOut) {
                                widget.onCheckIn();
                              } else {
                                AttendanceDialogs.showCheckInWelcomeDialog(
                                  context: context,
                                  employeeName: widget.employeeName,
                                  checkInAt: widget.todayRecord?.checkInAt,
                                  officeName: widget.officeName,
                                  distanceMeters: widget
                                      .todayRecord?.checkInDistanceMeters,
                                );
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _AttendanceColorTile(
                            key: const ValueKey('dashboard_check_out_tile'),
                            timeText: widget.checkOutTimeText,
                            zoneTag: widget.checkOutZoneTag,
                            label: 'Check Out',
                            icon: Icons.launch_rounded,
                            gradientColors: const [
                              Color(0xFF8B5CF6),
                              Color(0xFF6366F1),
                              Color(0xFF2563EB),
                            ],
                            disabledGradientColors: const [
                              Color(0xFF6D4AFF),
                              Color(0xFF4338CA),
                              Color(0xFF1E3A8A),
                            ],
                            isLoading:
                                widget.isSubmitting && widget.isCheckedIn,
                            isDisabled: !widget.isCheckedIn ||
                                widget.isCheckedOut,
                            onTap: () {
                              if (widget.isCheckedIn && !widget.isCheckedOut) {
                                widget.onCheckOut();
                              } else {
                                AttendanceDialogs.showCheckOutConfirmation(
                                  context: context,
                                  employeeName: widget.employeeName,
                                  companyTimezone: 'Asia/Kolkata',
                                  checkInAt: widget.todayRecord?.checkInAt,
                                  workedDuration:
                                      widget.todayRecord?.workedDuration,
                                );
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: InkWell(
                              onTap: () => _goToPage(1),
                              borderRadius: BorderRadius.circular(8),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 3,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.location_on_outlined,
                                      size: 13,
                                      color: Color(0xFF6EE7B7),
                                    ),
                                    const SizedBox(width: 4),
                                    Flexible(
                                      child: Text(
                                        'Swipe for 200m map',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white
                                              .withValues(alpha: 0.76),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 2),
                                    Icon(
                                      Icons.chevron_right_rounded,
                                      size: 14,
                                      color:
                                          Colors.white.withValues(alpha: 0.72),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        if (widget.todayRecord != null)
                          InkWell(
                            onLongPress: widget.onResetToday,
                            borderRadius: BorderRadius.circular(6),
                            child: SyncStatusChip(
                              status: widget.todayRecord!.syncStatus,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
                // Page 1: Interactive 200m Office Geofence Map
                OfficeGeofenceMap(
                  officeName: widget.officeName,
                  officeLatitude: widget.officeLatitude,
                  officeLongitude: widget.officeLongitude,
                  allowedRadiusMeters: widget.allowedRadiusMeters,
                  locationService: widget.locationService,
                  height: 206,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PanelTabChip extends StatelessWidget {
  const _PanelTabChip({
    super.key,
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.white.withValues(alpha: 0.2)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13,
              color: isSelected
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.62),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: isSelected
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.65),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _KpiColumn extends StatelessWidget {
  const _KpiColumn({
    required this.label,
    required this.value,
    required this.unit,
  });

  final String label;
  final String value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: Color(0xFF334155),
          ),
        ),
        const SizedBox(height: 8),
        RichText(
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          text: TextSpan(
            children: [
              TextSpan(
                text: value,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              TextSpan(
                text: ' $unit',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF334155),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AttendanceColorTile extends StatelessWidget {
  const _AttendanceColorTile({
    super.key,
    required this.timeText,
    required this.zoneTag,
    required this.label,
    required this.icon,
    required this.gradientColors,
    required this.disabledGradientColors,
    required this.isLoading,
    required this.isDisabled,
    required this.onTap,
  });

  final String timeText;
  final String zoneTag;
  final String label;
  final IconData icon;
  final List<Color> gradientColors;
  final List<Color> disabledGradientColors;
  final bool isLoading;
  final bool isDisabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final activeColors =
        isDisabled && !isLoading ? disabledGradientColors : gradientColors;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: isLoading ? null : onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          padding: const EdgeInsets.fromLTRB(12, 10, 10, 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: activeColors,
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: Colors.white.withValues(alpha: isDisabled ? 0.25 : 0.45),
              width: 1.2,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Align(
                alignment: Alignment.topRight,
                child: isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Icon(
                        icon,
                        size: 18,
                        color: Colors.white.withValues(alpha: 0.92),
                      ),
              ),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      timeText,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      zoneTag,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.92),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LeaveBalanceQuotaCard extends StatelessWidget {
  const _LeaveBalanceQuotaCard({required this.balance});

  final LeaveBalance balance;

  String _fmtDays(double days) =>
      days % 1 == 0 ? days.toStringAsFixed(0) : days.toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    final isSick = balance.leaveType == LeaveType.sick;
    final primaryColor =
        isSick ? const Color(0xFF0284C7) : const Color(0xFF059669);
    final secondaryColor =
        isSick ? const Color(0xFF38BDF8) : const Color(0xFF34D399);
    final borderColor =
        isSick ? const Color(0xFFBAE6FD) : const Color(0xFFBBF7D0);
    final icon = isSick
        ? Icons.medical_services_rounded
        : Icons.beach_access_rounded;
    final ratio = balance.totalDays > 0
        ? (balance.remainingDays / balance.totalDays).clamp(0.0, 1.0)
        : 0.0;
    final percent = (ratio * 100).round();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.go(AppRoutes.leave),
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isSick
                  ? const [
                      Color(0xFFF0F9FF),
                      Color(0xFFF8FAFC),
                      Colors.white,
                    ]
                  : const [
                      Color(0xFFF0FDF4),
                      Color(0xFFF8FAFC),
                      Colors.white,
                    ],
              stops: const [0.0, 0.45, 1.0],
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borderColor, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: primaryColor.withValues(alpha: 0.08),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Vibrant Gradient Icon + Label + Percent Pill
              Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [primaryColor, secondaryColor],
                      ),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: primaryColor.withValues(alpha: 0.28),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(icon, size: 17, color: Colors.white),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      balance.leaveType.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: primaryColor.withValues(alpha: 0.22),
                        width: 0.8,
                      ),
                    ),
                    child: Text(
                      '$percent%',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        color: primaryColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Hero Number & "days left"
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    _fmtDays(balance.remainingDays),
                    style: const TextStyle(
                      fontSize: 27,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0F172A),
                      letterSpacing: -0.8,
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(width: 5),
                  const Text(
                    'days left',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Gradient Progress Bar
              Container(
                height: 6,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final fillWidth = (constraints.maxWidth * ratio)
                        .clamp(6.0, constraints.maxWidth);
                    return Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        width: fillWidth,
                        height: 6,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [primaryColor, secondaryColor],
                          ),
                          borderRadius: BorderRadius.circular(999),
                          boxShadow: [
                            BoxShadow(
                              color: primaryColor.withValues(alpha: 0.35),
                              blurRadius: 3,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),

              // Breakdown Footnote
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      color: primaryColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      'Used ${_fmtDays(balance.usedDays)} of ${_fmtDays(balance.totalDays)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF475569),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentAttendanceRow extends StatelessWidget {
  const _RecentAttendanceRow({
    required this.record,
    required this.companyTimezone,
    required this.onTap,
  });

  final AttendanceRecord record;
  final String companyTimezone;
  final VoidCallback onTap;

  String _formatDuration(Duration? duration) {
    if (duration == null) return '--';
    final h = duration.inHours.toString().padLeft(2, '0');
    final m = (duration.inMinutes % 60).toString().padLeft(2, '0');
    return '${h}h ${m}m';
  }

  @override
  Widget build(BuildContext context) {
    final dayNum = DateFormat('dd').format(record.date);
    final monthShort = DateFormat('MMM').format(record.date).toUpperCase();
    final weekday = DateFormat('EEEE').format(record.date);
    final timeFmt = DateFormat('hh:mm a');
    final inText = record.checkInAt != null
        ? timeFmt.format(
            CompanyClock.toCompanyTimezone(record.checkInAt!, companyTimezone),
          )
        : '--:--';
    final outText = record.checkOutAt != null
        ? timeFmt.format(
            CompanyClock.toCompanyTimezone(record.checkOutAt!, companyTimezone),
          )
        : '--:--';
    final durationText = _formatDuration(record.workedDuration);
    final distText = record.checkInDistanceMeters != null
        ? ' • ${record.checkInDistanceMeters!.round()}m'
        : '';

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white,
            Color(0xFFF3F8FF),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD6E4F5)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D1575C8),
            blurRadius: 14,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(13),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Two-tone mini calendar badge matching dashboard blue palette
                Container(
                  width: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF3FF),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFC5DCF7)),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 3.5),
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFF1575C8), Color(0xFF162A56)],
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          monthShort,
                          style: const TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 7),
                        child: Text(
                          dayNum,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF162A56),
                            height: 1.0,
                          ),
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
                      // Weekday + duration badge + Sync pill
                      Row(
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    weekday,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF132245),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE0EEFF),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    durationText,
                                    style: const TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF1575C8),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          SyncStatusChip(status: record.syncStatus),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Balanced Check-in -> Check-out cool-tinted timeline bar
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEBF3FC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: const Color(0xFFD2E3F7),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.login_rounded,
                                    size: 14,
                                    color: Color(0xFF0D9488),
                                  ),
                                  const SizedBox(width: 5),
                                  Flexible(
                                    child: Text(
                                      inText,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF132245),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 6),
                              child: Icon(
                                Icons.east_rounded,
                                size: 14,
                                color: Color(0xFF64748B),
                              ),
                            ),
                            Expanded(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.logout_rounded,
                                    size: 14,
                                    color: Color(0xFF4F46E5),
                                  ),
                                  const SizedBox(width: 5),
                                  Flexible(
                                    child: Text(
                                      outText,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF132245),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (record.workLocation != null) ...[
                        const SizedBox(height: 7),
                        Row(
                          children: [
                            const Icon(
                              Icons.location_on_outlined,
                              size: 13,
                              color: Color(0xFF1575C8),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                '${record.workLocation!}$distText',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF475569),
                                ),
                              ),
                            ),
                            const Icon(
                              Icons.chevron_right_rounded,
                              size: 16,
                              color: Color(0xFF64748B),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DashboardLoadingView extends StatelessWidget {
  const _DashboardLoadingView();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
        children: const [
          _SkeletonBox(height: 210, radius: 22),
          SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: _SkeletonBox(height: 112, radius: 16)),
              SizedBox(width: 12),
              Expanded(child: _SkeletonBox(height: 112, radius: 16)),
            ],
          ),
          SizedBox(height: 20),
          _SkeletonBox(height: 260, radius: 16),
          SizedBox(height: 16),
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 10),
                Text(
                  'Loading workspace...',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SkeletonBox extends StatelessWidget {
  const _SkeletonBox({
    required this.height,
    required this.radius,
  });

  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFE2E8F0).withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

class _ElevatedSurface extends StatelessWidget {
  const _ElevatedSurface({
    required this.child,
    this.padding,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
        boxShadow: AppTheme.cardShadow,
      ),
      child: child,
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
              letterSpacing: -0.3,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onAction,
            borderRadius: BorderRadius.circular(999),
            child: Ink(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: const Color(0xFFBFDBFE),
                  width: 0.8,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    actionLabel,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1D4ED8),
                    ),
                  ),
                  const SizedBox(width: 3),
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 15,
                    color: Color(0xFF1D4ED8),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _EmptyBlockCard extends StatelessWidget {
  const _EmptyBlockCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return _ElevatedSurface(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              color: Color(0xFFF1F5F9),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 22, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12.5,
              color: AppTheme.textSecondary,
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}

class _DashboardErrorState extends StatelessWidget {
  const _DashboardErrorState({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: const BoxDecoration(
                  color: Color(0xFFFEF2F2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.error_outline_rounded,
                  size: 28,
                  color: Color(0xFFDC2626),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Could not load dashboard',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13.5,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Try Again'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
