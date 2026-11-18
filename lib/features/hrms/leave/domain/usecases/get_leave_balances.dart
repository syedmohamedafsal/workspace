import 'package:equatable/equatable.dart';

import '../../../../../core/error/result.dart';
import '../../../../../core/usecases/usecase.dart';
import '../entities/leave_balance.dart';
import '../repositories/leave_repository.dart';

class GetLeaveBalances
    implements UseCase<List<LeaveBalance>, GetLeaveBalancesParams> {
  const GetLeaveBalances(this._repository);

  final LeaveRepository _repository;

  @override
  Future<Result<List<LeaveBalance>>> call(GetLeaveBalancesParams params) {
    return _repository.getLeaveBalances(refreshRemote: params.refreshRemote);
  }
}

class GetLeaveBalancesParams extends Equatable {
  const GetLeaveBalancesParams({this.refreshRemote = false});

  final bool refreshRemote;

  @override
  List<Object?> get props => [refreshRemote];
}
