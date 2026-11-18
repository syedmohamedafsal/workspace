import 'package:equatable/equatable.dart';

import '../../../../../core/error/result.dart';
import '../../../../../core/usecases/usecase.dart';
import '../entities/leave_request.dart';
import '../repositories/leave_repository.dart';

class GetLeaveRequests
    implements UseCase<List<LeaveRequest>, GetLeaveRequestsParams> {
  const GetLeaveRequests(this._repository);

  final LeaveRepository _repository;

  @override
  Future<Result<List<LeaveRequest>>> call(GetLeaveRequestsParams params) {
    return _repository.getLeaveRequests(refreshRemote: params.refreshRemote);
  }
}

class GetLeaveRequestsParams extends Equatable {
  const GetLeaveRequestsParams({this.refreshRemote = false});

  final bool refreshRemote;

  @override
  List<Object?> get props => [refreshRemote];
}
