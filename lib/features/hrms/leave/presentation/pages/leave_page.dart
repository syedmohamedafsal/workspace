import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../../../core/widgets/sync_status_chip.dart';
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
            (curr.errorMessage != null && curr.errorMessage != prev.errorMessage) ||
            (curr.feedbackMessage != null &&
                curr.feedbackMessage != prev.feedbackMessage),
        listener: (context, state) {
          final msg = state.errorMessage ?? state.feedbackMessage;
          if (msg == null) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(msg),
              backgroundColor: state.errorMessage != null
                  ? Theme.of(context).colorScheme.error
                  : null,
            ),
          );
        },
        builder: (context, state) {
          return RefreshIndicator(
            onRefresh: () async {
              context
                  .read<LeaveBloc>()
                  .add(const LoadLeaveDataRequested(refreshRemote: true));
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
              children: [
                Text(
                  'Leave Balances',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 10),
                if (state.balances.isNotEmpty)
                  SizedBox(
                    height: 116,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: state.balances.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 10),
                      itemBuilder: (context, index) =>
                          _LeaveBalanceCard(balance: state.balances[index]),
                    ),
                  ),
                const SizedBox(height: 20),
                Text(
                  'My Leave Requests',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 10),
                if (state.status == LeaveViewStatus.loading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (state.requests.isEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          Icon(
                            Icons.beach_access_outlined,
                            size: 36,
                            color: Theme.of(context).colorScheme.outline,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'No leave requests yet',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Tap "Apply Leave" below. Requests can be created offline and will sync when connected.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ...state.requests.map(
                    (request) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _LeaveRequestCard(
                        request: request,
                        onCancel: request.canCancel
                            ? () => context
                                .read<LeaveBloc>()
                                .add(CancelLeaveSubmitted(request.localId))
                            : null,
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openApplySheet,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Apply Leave'),
      ),
    );
  }
}

class _LeaveBalanceCard extends StatelessWidget {
  const _LeaveBalanceCard({required this.balance});

  final LeaveBalance balance;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 168,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                balance.leaveType.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                '${balance.remainingDays.toStringAsFixed(balance.remainingDays % 1 == 0 ? 0 : 1)} days',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.primary,
                ),
              ),
              Text(
                'Used ${balance.usedDays.toStringAsFixed(0)} • Pending ${balance.pendingDays.toStringAsFixed(balance.pendingDays % 1 == 0 ? 0 : 1)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall,
              ),
            ],
          ),
        ),
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
    final theme = Theme.of(context);
    final fmt = DateFormat('d MMM yyyy');
    final dateRange = request.startDate == request.endDate
        ? fmt.format(request.startDate)
        : '${fmt.format(request.startDate)} – ${fmt.format(request.endDate)}';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${request.leaveType.label} (${request.requestedDays}d)',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                SyncStatusChip(status: request.syncStatus),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '$dateRange • ${request.approvalStatus.label}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 6),
            Text(request.reason),
            if (onCancel != null) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: onCancel,
                  child: const Text('Cancel Request'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
