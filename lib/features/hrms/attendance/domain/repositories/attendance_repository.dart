import '../../../../../core/error/result.dart';
import '../entities/attendance_record.dart';

/// Domain repository contract for employee attendance management.
abstract interface class AttendanceRepository {
  Future<Result<AttendanceRecord?>> getTodayAttendance();

  Future<Result<List<AttendanceRecord>>> getAttendanceHistory({
    int limit = 30,
    bool refreshRemote = false,
  });

  Future<Result<AttendanceRecord>> checkIn({
    String? workLocation,
    String? note,
  });

  Future<Result<AttendanceRecord>> checkOut({
    String? note,
  });
}
