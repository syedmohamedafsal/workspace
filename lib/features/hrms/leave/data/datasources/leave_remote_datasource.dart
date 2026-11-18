import '../../../../../core/constants/api_endpoints.dart';
import '../../../../../core/network/api_client.dart';
import '../models/leave_balance_model.dart';
import '../models/leave_request_model.dart';

abstract interface class LeaveRemoteDataSource {
  Future<List<LeaveRequestModel>> fetchLeaveRequests(String employeeId);

  Future<List<LeaveBalanceModel>> fetchLeaveBalances(String employeeId);

  Future<LeaveRequestModel> submitLeave({
    required Map<String, dynamic> payload,
    required String idempotencyKey,
  });

  Future<LeaveRequestModel> cancelLeave({
    required String serverOrClientId,
    required String idempotencyKey,
  });
}

class LeaveRemoteDataSourceImpl implements LeaveRemoteDataSource {
  LeaveRemoteDataSourceImpl(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<List<LeaveRequestModel>> fetchLeaveRequests(String employeeId) async {
    final response = await _apiClient.get(
      ApiEndpoints.leaveRequests,
      queryParameters: {'employee_id': employeeId},
    );
    final rawItems = response['items'] ?? response['data'];
    if (rawItems is! List) return const [];
    return rawItems
        .whereType<Map<String, dynamic>>()
        .map(LeaveRequestModel.fromApiJson)
        .toList();
  }

  @override
  Future<List<LeaveBalanceModel>> fetchLeaveBalances(String employeeId) async {
    final response = await _apiClient.get(
      ApiEndpoints.leaveBalances,
      queryParameters: {'employee_id': employeeId},
    );
    final rawItems = response['items'] ?? response['data'];
    if (rawItems is! List) return const [];
    return rawItems
        .whereType<Map<String, dynamic>>()
        .map(LeaveBalanceModel.fromApiJson)
        .toList();
  }

  @override
  Future<LeaveRequestModel> submitLeave({
    required Map<String, dynamic> payload,
    required String idempotencyKey,
  }) async {
    final response = await _apiClient.post(
      ApiEndpoints.leaveRequests,
      body: payload,
      idempotencyKey: idempotencyKey,
    );
    final data = response['data'] is Map<String, dynamic>
        ? response['data'] as Map<String, dynamic>
        : response;
    return LeaveRequestModel.fromApiJson(data);
  }

  @override
  Future<LeaveRequestModel> cancelLeave({
    required String serverOrClientId,
    required String idempotencyKey,
  }) async {
    final response = await _apiClient.post(
      ApiEndpoints.cancelLeave(serverOrClientId),
      idempotencyKey: idempotencyKey,
    );
    final data = response['data'] is Map<String, dynamic>
        ? response['data'] as Map<String, dynamic>
        : response;
    return LeaveRequestModel.fromApiJson(data);
  }
}
