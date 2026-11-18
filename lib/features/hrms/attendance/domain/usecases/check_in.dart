import 'package:equatable/equatable.dart';

import '../../../../../core/error/result.dart';
import '../../../../../core/usecases/usecase.dart';
import '../entities/attendance_record.dart';
import '../repositories/attendance_repository.dart';

class CheckIn implements UseCase<AttendanceRecord, CheckInParams> {
  const CheckIn(this._repository);

  final AttendanceRepository _repository;

  @override
  Future<Result<AttendanceRecord>> call(CheckInParams params) {
    return _repository.checkIn(
      workLocation: params.workLocation,
      note: params.note,
    );
  }
}

class CheckInParams extends Equatable {
  const CheckInParams({
    this.workLocation,
    this.note,
  });

  final String? workLocation;
  final String? note;

  @override
  List<Object?> get props => [workLocation, note];
}
