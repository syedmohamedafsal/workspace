import '../../../../../core/error/result.dart';
import '../../../../../core/usecases/usecase.dart';
import '../entities/attendance_record.dart';
import '../repositories/attendance_repository.dart';

class GetTodayAttendance implements UseCase<AttendanceRecord?, NoParams> {
  const GetTodayAttendance(this._repository);

  final AttendanceRepository _repository;

  @override
  Future<Result<AttendanceRecord?>> call(NoParams params) {
    return _repository.getTodayAttendance();
  }
}
