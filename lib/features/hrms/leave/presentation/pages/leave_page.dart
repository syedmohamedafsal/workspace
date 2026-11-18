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
                              ? () => context
                                  .read<LeaveBloc>()
                                  .add(CancelLeaveSubmitted(request.localId))
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
    final accent = isSick ? const Color(0xFF0EA5E9) : const Color(0xFF10B981);
    final softBg = isSick ? const Color(0xFFF0F9FF) : const Color(0xFFECFDF5);
    final icon = isSick
        ? Icons.medical_services_outlined
        : Icons.wb_sunny_outlined;
    final ratio = balance.totalDays > 0
        ? (balance.remainingDays / balance.totalDays).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: softBg,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, size: 17, color: accent),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  balance.leaveType.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary,
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
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(width: 5),
              const Text(
                'days left',
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 5,
              backgroundColor: const Color(0xFFF1F5F9),
              valueColor: AlwaysStoppedAnimation<Color>(accent),
            ),
          ),
          const SizedBox(height: 7),
          Text(
            'Used ${_fmt(balance.usedDays)} • Pending ${_fmt(balance.pendingDays)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11.5,
              color: AppTheme.textMuted,
            ),
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

    final (accent, bg, fg) = switch (request.approvalStatus) {
      LeaveApprovalStatus.approved => (
          const Color(0xFF10B981),
          const Color(0xFFF0FDF4),
          const Color(0xFF166534),
        ),
      LeaveApprovalStatus.pending => (
          const Color(0xFFF59E0B),
          const Color(0xFFFFFBEB),
          const Color(0xFF92400E),
        ),
      LeaveApprovalStatus.rejected => (
          const Color(0xFFEF4444),
          const Color(0xFFFEF2F2),
          const Color(0xFF991B1B),
        ),
      LeaveApprovalStatus.cancelled => (
          const Color(0xFF94A3B8),
          const Color(0xFFF1F5F9),
          const Color(0xFF475569),
        ),
    };

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
        boxShadow: AppTheme.cardShadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 4, color: accent),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${request.leaveType.label} • $days ${days == '1' ? 'day' : 'days'}',
                              style: const TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: bg,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              request.approvalStatus.label,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: fg,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          const Icon(
                            Icons.calendar_today_outlined,
                            size: 13,
                            color: AppTheme.textSecondary,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            dateRange,
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        request.reason,
                        style: const TextStyle(
                          fontSize: 13.5,
                          color: AppTheme.textPrimary,
                          height: 1.35,
                        ),
                      ),
                      if (onCancel != null) ...[
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: onCancel,
                            style: TextButton.styleFrom(
                              foregroundColor: AppTheme.textSecondary,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8),
                              minimumSize: const Size(0, 30),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text('Cancel Request'),
                          ),
                        ),
                      ],
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
