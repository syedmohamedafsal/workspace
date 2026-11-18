import 'package:equatable/equatable.dart';

import '../../../../../core/error/result.dart';
import '../../../../../core/usecases/usecase.dart';
import '../entities/leave_request.dart';
import '../repositories/leave_repository.dart';

class CancelLeave implements UseCase<LeaveRequest, CancelLeaveParams> {
  const CancelLeave(this._repository);

  final LeaveRepository _repository;

  @override
  Future<Result<LeaveRequest>> call(CancelLeaveParams params) {
    return _repository.cancelLeave(params.localId);
  }
}

class CancelLeaveParams extends Equatable {
  const CancelLeaveParams(this.localId);

  final String localId;

  @override
  List<Object?> get props => [localId];
}
