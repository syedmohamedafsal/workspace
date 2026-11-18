import '../../../../../core/constants/api_endpoints.dart';
import '../../../../../core/network/api_client.dart';
import '../models/attendance_record_model.dart';

/// Remote REST data source for HRMS attendance endpoints.
abstract interface class AttendanceRemoteDataSource {
  Future<List<AttendanceRecordModel>> fetchHistory({
    required String employeeId,
    int limit = 30,
  });

  Future<AttendanceRecordModel> sendCheckIn({
    required Map<String, dynamic> payload,
    required String idempotencyKey,
  });

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
  }) async {
    final response = await _apiClient.get(
      ApiEndpoints.attendanceHistory,
      queryParameters: {
        'employee_id': employeeId,
        'limit': limit,
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
      ApiEndpoints.attendanceCheckIn,
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
      ApiEndpoints.attendanceCheckOut,
      body: payload,
      idempotencyKey: idempotencyKey,
    );
    final data = response['data'] is Map<String, dynamic>
        ? response['data'] as Map<String, dynamic>
        : response;
    return AttendanceRecordModel.fromApiJson(data);
  }
}
