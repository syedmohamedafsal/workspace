import '../../../../../core/constants/api_endpoints.dart';
import '../../../../../core/network/api_client.dart';
import '../models/attendance_record_model.dart';

/// Remote REST data source for HRMS attendance endpoints.
abstract interface class AttendanceRemoteDataSource {
  /// Fetches monthly attendance history via `GET /attendance?month=YYYY-MM`.
  Future<List<AttendanceRecordModel>> fetchHistory({
    required String employeeId,
    int limit = 30,
    String? month,
  });

  /// Submits a check-in event via `POST /attendance/events`.
  Future<AttendanceRecordModel> sendCheckIn({
    required Map<String, dynamic> payload,
    required String idempotencyKey,
  });

  /// Submits a check-out event via `POST /attendance/events`.
  Future<AttendanceRecordModel> sendCheckOut({
    required Map<String, dynamic> payload,
    required String idempotencyKey,
  });
}

class AttendanceRemoteDataSourceImpl implements AttendanceRemoteDataSource {
  AttendanceRemoteDataSourceImpl(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<List<AttendanceRecordModel>> fetchHistory({
    required String employeeId,
    int limit = 30,
    String? month,
  }) async {
    final response = await _apiClient.get(
      ApiEndpoints.attendance,
      queryParameters: {
        'employee_id': employeeId,
        'limit': limit,
        'month': ?month,
      },
    );
    final rawItems = response['items'] ?? response['data'];
    if (rawItems is! List) return const [];
    return rawItems
        .whereType<Map<String, dynamic>>()
        .map(AttendanceRecordModel.fromApiJson)
        .toList();
  }

  @override
  Future<AttendanceRecordModel> sendCheckIn({
    required Map<String, dynamic> payload,
    required String idempotencyKey,
  }) async {
    final response = await _apiClient.post(
      ApiEndpoints.attendanceEvents,
      body: payload,
      idempotencyKey: idempotencyKey,
    );
    final data = response['data'] is Map<String, dynamic>
        ? response['data'] as Map<String, dynamic>
        : response;
    return AttendanceRecordModel.fromApiJson(data);
  }

  @override
  Future<AttendanceRecordModel> sendCheckOut({
    required Map<String, dynamic> payload,
    required String idempotencyKey,
  }) async {
    final response = await _apiClient.post(
      ApiEndpoints.attendanceEvents,
      body: payload,
      idempotencyKey: idempotencyKey,
    );
    final data = response['data'] is Map<String, dynamic>
        ? response['data'] as Map<String, dynamic>
        : response;
    return AttendanceRecordModel.fromApiJson(data);
  }
}
