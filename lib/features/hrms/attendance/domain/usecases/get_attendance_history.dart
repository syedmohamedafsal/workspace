import 'package:equatable/equatable.dart';

import '../../../../../core/error/result.dart';
import '../../../../../core/usecases/usecase.dart';
import '../entities/attendance_record.dart';
import '../repositories/attendance_repository.dart';

class GetAttendanceHistory
    implements UseCase<List<AttendanceRecord>, GetAttendanceHistoryParams> {
  const GetAttendanceHistory(this._repository);

  final AttendanceRepository _repository;

  @override
  Future<Result<List<AttendanceRecord>>> call(
    GetAttendanceHistoryParams params,
  ) {
    return _repository.getAttendanceHistory(
      limit: params.limit,
      refreshRemote: params.refreshRemote,
    );
  }
}

class GetAttendanceHistoryParams extends Equatable {
  const GetAttendanceHistoryParams({
    this.limit = 30,
    this.refreshRemote = false,
  });

  final int limit;
  final bool refreshRemote;

  @override
  List<Object?> get props => [limit, refreshRemote];
}
