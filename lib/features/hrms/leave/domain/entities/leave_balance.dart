import 'package:equatable/equatable.dart';

import 'leave_request.dart';

/// Remaining and allocated leave quota for a specific [LeaveType].
class LeaveBalance extends Equatable {
  const LeaveBalance({
    required this.leaveType,
    required this.totalDays,
    required this.usedDays,
    required this.pendingDays,
    required this.updatedAt,
  });

  final LeaveType leaveType;
  final double totalDays;
  final double usedDays;
  final double pendingDays;
  final DateTime updatedAt;

  double get remainingDays {
    final remaining = totalDays - usedDays - pendingDays;
    return remaining < 0 ? 0 : remaining;
  }

  @override
  List<Object?> get props => [
        leaveType,
        totalDays,
        usedDays,
        pendingDays,
        updatedAt,
      ];
}
