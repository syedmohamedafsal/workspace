import '../../../../../core/error/result.dart';
import '../../../../../core/usecases/usecase.dart';
import '../repositories/attendance_repository.dart';

/// Resets today's local attendance record for testing and reviewer demonstration.
class ResetTodayAttendance implements UseCase<void, NoParams> {
  const ResetTodayAttendance(this._repository);

  final AttendanceRepository _repository;

  @override
  Future<Result<void>> call(NoParams params) {
    return _repository.resetTodayAttendance();
  }
}
