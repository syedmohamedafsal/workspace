import 'package:equatable/equatable.dart';

import '../../domain/entities/leave_request.dart';

sealed class LeaveEvent extends Equatable {
  const LeaveEvent();

  @override
  List<Object?> get props => const [];
}

final class LoadLeaveDataRequested extends LeaveEvent {
  const LoadLeaveDataRequested({this.refreshRemote = false});

  final bool refreshRemote;

  @override
  List<Object?> get props => [refreshRemote];
}

final class ApplyLeaveSubmitted extends LeaveEvent {
  const ApplyLeaveSubmitted({
    required this.leaveType,
    required this.startDate,
    required this.endDate,
    required this.reason,
    this.isHalfDay = false,
  });

  final LeaveType leaveType;
  final DateTime startDate;
  final DateTime endDate;
  final bool isHalfDay;
  final String reason;

  @override
  List<Object?> get props => [
        leaveType,
        startDate,
        endDate,
        isHalfDay,
        reason,
      ];
}

final class CancelLeaveSubmitted extends LeaveEvent {
  const CancelLeaveSubmitted(this.localId);

  final String localId;

  @override
  List<Object?> get props => [localId];
}
