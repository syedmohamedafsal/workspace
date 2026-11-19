import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/api_client.dart';
import '../models/employee_model.dart';

/// Remote REST data source for employee and office configuration.
abstract interface class AuthRemoteDataSource {
  /// Fetches employee identity and office geofence configuration from `GET /employee/me`.
  Future<EmployeeModel> fetchCurrentEmployee();
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  AuthRemoteDataSourceImpl(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<EmployeeModel> fetchCurrentEmployee() async {
    final response = await _apiClient.get(ApiEndpoints.employeeMe);
    final data = response['data'] is Map<String, dynamic>
        ? response['data'] as Map<String, dynamic>
        : response;
    return EmployeeModel.fromApiJson(data);
  }
}
