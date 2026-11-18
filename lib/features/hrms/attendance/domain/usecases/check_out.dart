import 'package:equatable/equatable.dart';

import '../../../../../core/error/result.dart';
import '../../../../../core/usecases/usecase.dart';
import '../entities/attendance_record.dart';
import '../repositories/attendance_repository.dart';

class CheckOut implements UseCase<AttendanceRecord, CheckOutParams> {
  const CheckOut(this._repository);

  final AttendanceRepository _repository;

  @override
  Future<Result<AttendanceRecord>> call(CheckOutParams params) {
    return _repository.checkOut(note: params.note);
  }
}

class CheckOutParams extends Equatable {
  const CheckOutParams({this.note});

  final String? note;

  @override
  List<Object?> get props => [note];
}
