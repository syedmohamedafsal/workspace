import 'package:equatable/equatable.dart';

import '../../../../../core/config/app_config.dart';
import '../../../../../core/error/failures.dart';
import '../../../../../core/error/result.dart';
import '../../../../../core/time/company_clock.dart';
import '../../../../../core/usecases/usecase.dart';
import '../entities/leave_request.dart';
import '../repositories/leave_repository.dart';

/// Applies for employee leave with strict enforcement of Section 4 rules:
/// 1. Leave type must be Casual or Sick.
/// 2. Start date cannot be before the current company date.
/// 3. End date cannot be before the start date.
/// 4. Reason must contain at least 10 non-whitespace characters.
/// 5. Requested days cannot exceed the available balance.
/// 6. Dates cannot overlap an existing Pending or Approved request.
/// All calendar days count as leave days; weekends and holidays are ignored.
class ApplyLeave implements UseCase<LeaveRequest, ApplyLeaveParams> {
  const ApplyLeave({
    required LeaveRepository repository,
    required CompanyClock companyClock,
    required AppConfig config,
  })  : _repository = repository,
        _companyClock = companyClock,
        _config = config;

  final LeaveRepository _repository;
  final CompanyClock _companyClock;
  final AppConfig _config;

  @override
  Future<Result<LeaveRequest>> call(ApplyLeaveParams params) async {
    // Rule 1: Leave type must be Casual or Sick
    if (params.leaveType != LeaveType.casual &&
        params.leaveType != LeaveType.sick) {
      return const FailureResult(
        ValidationFailure('Only Casual and Sick leave types are permitted.'),
      );
    }

    // Normalize dates to midnight
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

    // Rule 2: Start date cannot be before current company date
    final companyToday = _companyClock.workingDate(
      _config.employeeConfig.companyTimezone,
    );
    if (start.isBefore(companyToday)) {
      return const FailureResult(
        ValidationFailure(
          'Start date cannot be before the current company date.',
        ),
      );
    }

    // Rule 3: End date cannot be before start date
    if (end.isBefore(start)) {
      return const FailureResult(
        ValidationFailure('End date cannot be before the start date.'),
      );
    }

    // Rule 4: Reason must contain at least 10 non-whitespace characters
    final nonWhitespace = params.reason.replaceAll(RegExp(r'\s+'), '');
    if (nonWhitespace.length < 10) {
      return const FailureResult(
        ValidationFailure(
          'Reason must contain at least 10 non-whitespace characters.',
        ),
      );
    }

    // Rule 5: Requested days cannot exceed available balance (all calendar days count)
    final requestedDays = (end.difference(start).inDays + 1).toDouble();
    final balanceResult = await _repository.getLeaveBalances();
    if (balanceResult.isFailure) {
      return FailureResult(balanceResult.failureOrNull!);
    }
    final balances = balanceResult.dataOrNull ?? [];
    final matchingBalance = balances
        .where((b) => b.leaveType == params.leaveType)
        .firstOrNull;

    if (matchingBalance != null &&
        requestedDays > matchingBalance.remainingDays) {
      return FailureResult(
        ValidationFailure(
          'Requested days (${requestedDays.toInt()}) exceed available balance (${matchingBalance.remainingDays.toStringAsFixed(0)} days).',
        ),
      );
    }

    // Rule 6: Dates cannot overlap an existing Pending or Approved request
    final requestsResult = await _repository.getLeaveRequests();
    if (requestsResult.isFailure) {
      return FailureResult(requestsResult.failureOrNull!);
    }
    final existingRequests = requestsResult.dataOrNull ?? [];
    final hasOverlap = existingRequests.any((r) {
      if (r.approvalStatus != LeaveApprovalStatus.pending &&
          r.approvalStatus != LeaveApprovalStatus.approved) {
        return false;
      }
      final rStart =
          DateTime(r.startDate.year, r.startDate.month, r.startDate.day);
      final rEnd = DateTime(r.endDate.year, r.endDate.month, r.endDate.day);
      return !start.isAfter(rEnd) && !rStart.isAfter(end);
    });

    if (hasOverlap) {
      return const FailureResult(
        ValidationFailure(
          'Selected dates overlap with an existing Pending or Approved leave request.',
        ),
      );
    }

    return _repository.applyLeave(
      leaveType: params.leaveType,
      startDate: start,
      endDate: end,
      isHalfDay: params.isHalfDay,
      reason: params.reason.trim(),
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
