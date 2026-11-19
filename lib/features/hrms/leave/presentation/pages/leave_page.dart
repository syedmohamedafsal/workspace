import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../domain/entities/leave_balance.dart';
import '../../domain/entities/leave_request.dart';
import '../bloc/leave_bloc.dart';
import '../bloc/leave_event.dart';
import '../bloc/leave_state.dart';
import 'apply_leave_sheet.dart';

class LeavePage extends StatefulWidget {
  const LeavePage({super.key});

  @override
  State<LeavePage> createState() => _LeavePageState();
}

class _LeavePageState extends State<LeavePage> {
  LeaveApprovalStatus? _statusFilter;

  @override
  void initState() {
    super.initState();
    context
        .read<LeaveBloc>()
        .add(const LoadLeaveDataRequested(refreshRemote: true));
  }

  Future<void> _openApplySheet() async {
    final result = await showModalBottomSheet<ApplyLeaveFormResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const ApplyLeaveSheet(),
    );

    if (!mounted || result == null) return;
    context.read<LeaveBloc>().add(
          ApplyLeaveSubmitted(
            leaveType: result.leaveType,
            startDate: result.startDate,
            endDate: result.endDate,
            isHalfDay: result.isHalfDay,
            reason: result.reason,
          ),
        );
  }

  Future<void> _confirmCancelLeave(LeaveRequest request) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (dialogCtx) => _CancelLeaveConfirmationDialog(request: request),
    );

    if (confirmed == true && mounted) {
      context.read<LeaveBloc>().add(CancelLeaveSubmitted(request.localId));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocConsumer<LeaveBloc, LeaveState>(
        listenWhen: (prev, curr) =>
            (curr.errorMessage != null &&
                curr.errorMessage != prev.errorMessage) ||
            (curr.feedbackMessage != null &&
                curr.feedbackMessage != prev.feedbackMessage),
        listener: (context, state) {
          final msg = state.errorMessage ?? state.feedbackMessage;
          if (msg == null) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              content: Text(msg),
              backgroundColor: state.errorMessage != null
                  ? const Color(0xFFDC2626)
                  : AppTheme.inkDark,
            ),
          );
        },
        builder: (context, state) {
          final visibleBalances = _selectCasualAndSick(state.balances);
          final filteredRequests = _statusFilter == null
              ? state.requests
              : state.requests
                  .where((r) => r.approvalStatus == _statusFilter)
                  .toList();

          return SafeArea(
            top: false,
            child: RefreshIndicator(
              onRefresh: () async {
                context
                    .read<LeaveBloc>()
                    .add(const LoadLeaveDataRequested(refreshRemote: true));
              },
              child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 92),
              children: [
                const Text(
                  'Leave Balance',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 12),
                if (visibleBalances.isNotEmpty)
                  Row(
                    children: [
                      for (var i = 0; i < visibleBalances.length; i++) ...[
                        if (i > 0) const SizedBox(width: 12),
                        Expanded(
                          child: _LeaveBalanceCard(balance: visibleBalances[i]),
                        ),
                      ],
                    ],
                  ),
                const SizedBox(height: 24),
                const Text(
                  'Leave Requests',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _FilterChipButton(
                        label: 'All',
                        selected: _statusFilter == null,
                        onTap: () => setState(() => _statusFilter = null),
                      ),
                      const SizedBox(width: 8),
                      _FilterChipButton(
                        label: 'Pending',
                        selected: _statusFilter == LeaveApprovalStatus.pending,
                        onTap: () => setState(
                          () => _statusFilter = LeaveApprovalStatus.pending,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _FilterChipButton(
                        label: 'Approved',
                        selected: _statusFilter == LeaveApprovalStatus.approved,
                        onTap: () => setState(
                          () => _statusFilter = LeaveApprovalStatus.approved,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _FilterChipButton(
                        label: 'Rejected',
                        selected: _statusFilter == LeaveApprovalStatus.rejected,
                        onTap: () => setState(
                          () => _statusFilter = LeaveApprovalStatus.rejected,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (state.status == LeaveViewStatus.loading &&
                    state.requests.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Center(
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    ),
                  )
                else if (filteredRequests.isEmpty)
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
                            Icons.event_note_outlined,
                            size: 22,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _statusFilter == null
                              ? 'No leave requests yet'
                              : 'No ${_statusFilter!.label.toLowerCase()} requests',
                          style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Tap "Apply Leave" below to submit a Casual or Sick leave request.',
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
                  Column(
                    children: [
                      for (final request in filteredRequests) ...[
                        _LeaveRequestCard(
                          request: request,
                          onCancel: request.canCancel
                              ? () => _confirmCancelLeave(request)
                              : null,
                        ),
                        const SizedBox(height: 10),
                      ],
                    ],
                  ),
              ],
            ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openApplySheet,
        backgroundColor: AppTheme.inkDark,
        foregroundColor: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        icon: const Icon(Icons.add_rounded, size: 20),
        label: const Text(
          'Apply Leave',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    );
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

class _FilterChipButton extends StatelessWidget {
  const _FilterChipButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppTheme.inkDark : Colors.white,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? AppTheme.inkDark : AppTheme.border,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : AppTheme.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _LeaveBalanceCard extends StatelessWidget {
  const _LeaveBalanceCard({required this.balance});

  final LeaveBalance balance;

  String _fmt(double value) =>
      value % 1 == 0 ? value.toStringAsFixed(0) : value.toStringAsFixed(1);

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

    return Container(
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
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                _fmt(balance.remainingDays),
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
                  'Used ${_fmt(balance.usedDays)} • Pending ${_fmt(balance.pendingDays)}',
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
    );
  }
}

class _LeaveRequestCard extends StatelessWidget {
  const _LeaveRequestCard({
    required this.request,
    this.onCancel,
  });

  final LeaveRequest request;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('d MMM yyyy');
    final dateRange = request.startDate == request.endDate
        ? fmt.format(request.startDate)
        : '${fmt.format(request.startDate)} – ${fmt.format(request.endDate)}';
    final days = request.requestedDays % 1 == 0
        ? request.requestedDays.toStringAsFixed(0)
        : request.requestedDays.toStringAsFixed(1);
    final isSick = request.leaveType == LeaveType.sick;

    final (badgeBg, badgeBorder, badgeFg, dotColor) =
        switch (request.approvalStatus) {
      LeaveApprovalStatus.approved => (
          const Color(0xFFF0FDF4),
          const Color(0xFFBBF7D0),
          const Color(0xFF15803D),
          const Color(0xFF10B981),
        ),
      LeaveApprovalStatus.pending => (
          const Color(0xFFFFFBEB),
          const Color(0xFFFDE68A),
          const Color(0xFFB45309),
          const Color(0xFFF59E0B),
        ),
      LeaveApprovalStatus.rejected => (
          const Color(0xFFFEF2F2),
          const Color(0xFFFECACA),
          const Color(0xFFB91C1C),
          const Color(0xFFEF4444),
        ),
      LeaveApprovalStatus.cancelled => (
          const Color(0xFFF8FAFC),
          const Color(0xFFE2E8F0),
          const Color(0xFF64748B),
          const Color(0xFF94A3B8),
        ),
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFE2E8F0),
          width: 1.0,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Icon + Type + Days Pill + Status Badge
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: isSick
                      ? const Color(0xFFF0F9FF)
                      : const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSick
                        ? const Color(0xFFBAE6FD)
                        : const Color(0xFFBBF7D0),
                    width: 0.8,
                  ),
                ),
                child: Icon(
                  isSick
                      ? Icons.medical_services_rounded
                      : Icons.beach_access_rounded,
                  size: 16,
                  color: isSick
                      ? const Color(0xFF0284C7)
                      : const Color(0xFF059669),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        request.leaveType.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2.5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '$days ${days == '1' ? 'day' : 'days'}',
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF475569),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 9,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: badgeBorder,
                    width: 0.8,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: dotColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      request.approvalStatus.label,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: badgeFg,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Date Range Row
          Row(
            children: [
              const Icon(
                Icons.calendar_today_outlined,
                size: 13.5,
                color: Color(0xFF64748B),
              ),
              const SizedBox(width: 6),
              Text(
                dateRange,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF334155),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Reason Body Text (clean, unboxed typography)
          Text(
            request.reason,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w400,
              color: Color(0xFF475569),
              height: 1.45,
            ),
          ),

          // Cancel Request Action
          if (onCancel != null) ...[
            const SizedBox(height: 12),
            const Divider(
              height: 1,
              thickness: 1,
              color: Color(0xFFF1F5F9),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                key: ValueKey('cancel_leave_button_${request.localId}'),
                onPressed: onCancel,
                icon: const Icon(
                  Icons.close_rounded,
                  size: 14,
                  color: Colors.white,
                ),
                label: const Text(
                  'Cancel Request',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    letterSpacing: -0.1,
                  ),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFDC2626),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 13,
                    vertical: 7,
                  ),
                  minimumSize: const Size(0, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CancelLeaveConfirmationDialog extends StatelessWidget {
  const _CancelLeaveConfirmationDialog({required this.request});

  final LeaveRequest request;

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('d MMM yyyy');
    final dateRange = request.startDate == request.endDate
        ? fmt.format(request.startDate)
        : '${fmt.format(request.startDate)} – ${fmt.format(request.endDate)}';
    final days = request.requestedDays % 1 == 0
        ? request.requestedDays.toStringAsFixed(0)
        : request.requestedDays.toStringAsFixed(1);
    final isSick = request.leaveType == LeaveType.sick;

    return AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
      ),
      contentPadding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Red warning badge
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFFFECACA),
                width: 1.2,
              ),
            ),
            child: const Icon(
              Icons.event_busy_rounded,
              size: 26,
              color: Color(0xFFDC2626),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Cancel Leave Request?',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Are you sure you want to cancel this leave application? Your available balance will be restored immediately.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFF64748B),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),

          // Leave Details Summary Box
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      isSick
                          ? Icons.medical_services_rounded
                          : Icons.beach_access_rounded,
                      size: 16,
                      color: isSick
                          ? const Color(0xFF0284C7)
                          : const Color(0xFF059669),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${request.leaveType.label} • $days ${days == '1' ? 'day' : 'days'}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(
                      Icons.calendar_today_rounded,
                      size: 13,
                      color: Color(0xFF64748B),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      dateRange,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF334155),
                      ),
                    ),
                  ],
                ),
                if (request.reason.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    '"${request.reason}"',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontStyle: FontStyle.italic,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  key: const ValueKey('cancel_dialog_keep_button'),
                  onPressed: () => Navigator.of(context).pop(false),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF475569),
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Keep Leave',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  key: const ValueKey('cancel_dialog_confirm_button'),
                  onPressed: () => Navigator.of(context).pop(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFDC2626),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.close_rounded, size: 16),
                  label: const Text(
                    'Yes, Cancel',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
