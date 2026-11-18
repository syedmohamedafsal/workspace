import '../../../../../core/error/result.dart';
import '../entities/leave_balance.dart';
import '../entities/leave_request.dart';

/// Domain repository contract for employee leave applications & balances.
abstract interface class LeaveRepository {
  Future<Result<List<LeaveRequest>>> getLeaveRequests({
    bool refreshRemote = false,
  });

  Future<Result<List<LeaveBalance>>> getLeaveBalances({
    bool refreshRemote = false,
  });

  Future<Result<LeaveRequest>> applyLeave({
    required LeaveType leaveType,
    required DateTime startDate,
    required DateTime endDate,
    required bool isHalfDay,
    required String reason,
  });

  Future<Result<LeaveRequest>> cancelLeave(String localId);
}
