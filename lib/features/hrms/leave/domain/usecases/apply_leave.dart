import 'package:equatable/equatable.dart';

import '../../../../../core/error/failures.dart';
import '../../../../../core/error/result.dart';
import '../../../../../core/usecases/usecase.dart';
import '../entities/leave_request.dart';
import '../repositories/leave_repository.dart';

class ApplyLeave implements UseCase<LeaveRequest, ApplyLeaveParams> {
  const ApplyLeave(this._repository);

  final LeaveRepository _repository;

  @override
  Future<Result<LeaveRequest>> call(ApplyLeaveParams params) async {
    final trimmedReason = params.reason.trim();
    if (trimmedReason.isEmpty) {
      return const FailureResult(
        ValidationFailure('Please provide a reason for your leave request.'),
      );
    }

    final start = DateTime(
      params.startDate.year,
      params.startDate.month,
      params.startDate.day,
    );
    final end = DateTime(
      params.endDate.year,
      params.endDate.month,
      params.endDate.day,
    );

    if (end.isBefore(start)) {
      return const FailureResult(
        ValidationFailure('End date cannot be earlier than start date.'),
      );
    }

    if (params.isHalfDay && start != end) {
      return const FailureResult(
        ValidationFailure('Half-day leave must start and end on the same day.'),
      );
    }

    return _repository.applyLeave(
      leaveType: params.leaveType,
      startDate: start,
      endDate: end,
      isHalfDay: params.isHalfDay,
      reason: trimmedReason,
    );
  }
}

class ApplyLeaveParams extends Equatable {
  const ApplyLeaveParams({
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
