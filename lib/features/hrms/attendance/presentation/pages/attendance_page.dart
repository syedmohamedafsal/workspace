import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../../../core/widgets/sync_status_chip.dart';
import '../../domain/entities/attendance_record.dart';
import '../bloc/attendance_bloc.dart';
import '../bloc/attendance_event.dart';
import '../bloc/attendance_state.dart';

class AttendancePage extends StatefulWidget {
  const AttendancePage({super.key});

  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage> {
  String _selectedLocation = 'Office';
  static const List<String> _locations = ['Office', 'Remote', 'Client Site'];

  @override
  void initState() {
    super.initState();
    context
        .read<AttendanceBloc>()
        .add(const LoadAttendanceRequested(refreshRemote: true));
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AttendanceBloc, AttendanceState>(
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
                .read<AttendanceBloc>()
                .add(const LoadAttendanceRequested(refreshRemote: true));
          },
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _TodayAttendanceCard(
                record: state.todayRecord,
                isSubmitting: state.status == AttendanceViewStatus.submitting,
                selectedLocation: _selectedLocation,
                locations: _locations,
                onLocationChanged: (loc) =>
                    setState(() => _selectedLocation = loc),
                onCheckIn: () {
                  context.read<AttendanceBloc>().add(
                        CheckInSubmitted(workLocation: _selectedLocation),
                      );
                },
                onCheckOut: () {
                  context
                      .read<AttendanceBloc>()
                      .add(const CheckOutSubmitted());
                },
              ),
              const SizedBox(height: 20),
              Text(
                'Attendance History',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 10),
              if (state.status == AttendanceViewStatus.loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (state.history.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Icon(
                          Icons.event_note_outlined,
                          size: 36,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'No attendance logs yet',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Check in above to record today\'s attendance. Logs work offline and sync automatically.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                )
              else
                ...state.history.map(
                  (record) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _AttendanceHistoryTile(record: record),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _TodayAttendanceCard extends StatelessWidget {
  const _TodayAttendanceCard({
    required this.record,
    required this.isSubmitting,
    required this.selectedLocation,
    required this.locations,
    required this.onLocationChanged,
    required this.onCheckIn,
    required this.onCheckOut,
  });

  final AttendanceRecord? record;
  final bool isSubmitting;
  final String selectedLocation;
  final List<String> locations;
  final ValueChanged<String> onLocationChanged;
  final VoidCallback onCheckIn;
  final VoidCallback onCheckOut;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateLabel = DateFormat('EEEE, d MMM yyyy').format(DateTime.now());
    final timeFormat = DateFormat('hh:mm a');

    final isCheckedIn = record?.isCheckedIn ?? false;
    final isCompleted = record?.isCompleted ?? false;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Today\'s Attendance',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        dateLabel,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (record != null) SyncStatusChip(status: record!.syncStatus),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _TimeMetric(
                    label: 'Check In',
                    value: record?.checkInAt != null
                        ? timeFormat.format(record!.checkInAt!)
                        : '--:--',
                    icon: Icons.login_rounded,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _TimeMetric(
                    label: 'Check Out',
                    value: record?.checkOutAt != null
                        ? timeFormat.format(record!.checkOutAt!)
                        : '--:--',
                    icon: Icons.logout_rounded,
                  ),
                ),
              ],
            ),
            if (record == null) ...[
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                children: locations
                    .map(
                      (loc) => ChoiceChip(
                        label: Text(loc),
                        selected: selectedLocation == loc,
                        onSelected: (_) => onLocationChanged(loc),
                      ),
                    )
                    .toList(),
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: isSubmitting || isCompleted
                    ? null
                    : (isCheckedIn ? onCheckOut : onCheckIn),
                icon: isSubmitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        isCompleted
                            ? Icons.check_circle_outline_rounded
                            : (isCheckedIn
                                ? Icons.logout_rounded
                                : Icons.login_rounded),
                      ),
                label: Text(
                  isCompleted
                      ? 'Shift Completed'
                      : (isCheckedIn ? 'Check Out' : 'Check In'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimeMetric extends StatelessWidget {
  const _TimeMetric({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: theme.textTheme.labelSmall),
              Text(
                value,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AttendanceHistoryTile extends StatelessWidget {
  const _AttendanceHistoryTile({required this.record});

  final AttendanceRecord record;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateText = DateFormat('EEE, d MMM yyyy').format(record.date);
    final timeFormat = DateFormat('hh:mm a');
    final inText =
        record.checkInAt != null ? timeFormat.format(record.checkInAt!) : '--';
    final outText =
        record.checkOutAt != null ? timeFormat.format(record.checkOutAt!) : '--';

    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        title: Row(
          children: [
            Expanded(
              child: Text(
                dateText,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            SyncStatusChip(status: record.syncStatus),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            'In: $inText  •  Out: $outText${record.workLocation != null ? '  •  ${record.workLocation}' : ''}',
          ),
        ),
      ),
    );
  }
}
