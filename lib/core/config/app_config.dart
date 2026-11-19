import '../constants/api_endpoints.dart';
import 'employee_config.dart';

/// Application-wide configuration for the REBS platform.
///
/// Supports dynamic base URL resolution via ternary operator ([ApiConfig.baseUrl]),
/// with optional override at build/run time using `--dart-define`:
/// ```bash
/// flutter run --dart-define=API_BASE_URL=http://127.0.0.1:8080
/// ```
class AppConfig {
  const AppConfig({
    String? apiBaseUrl,
    this.connectTimeout = const Duration(seconds: 15),
    this.receiveTimeout = const Duration(seconds: 15),
    this.maxSyncRetries = 5,
    this.baseRetryDelay = const Duration(seconds: 5),
    this.maxRetryDelay = const Duration(minutes: 5),
    this.allowedAttendanceRadiusMeters = 200.0,
    this.employeeConfig = const PreconfiguredEmployeeConfig(),
  }) : _apiBaseUrl = apiBaseUrl;

  final String? _apiBaseUrl;
  final Duration connectTimeout;
  final Duration receiveTimeout;
  final int maxSyncRetries;
  final Duration baseRetryDelay;
  final Duration maxRetryDelay;
  final double allowedAttendanceRadiusMeters;

  /// Preconfigured employee, office coordinates, and company timezone settings.
  final PreconfiguredEmployeeConfig employeeConfig;

  /// Dynamically resolved base URL.
  /// If not explicitly provided in the constructor, uses [ApiConfig.baseUrl]
  /// which resolves via ternary operator:
  /// `kReleaseMode ? productionBaseUrl : defaultDebugBaseUrl`.
  String get apiBaseUrl => _apiBaseUrl ?? ApiConfig.baseUrl;

  String get defaultEmployeeId => employeeConfig.employeeId;
  String get defaultEmployeeName => employeeConfig.employeeName;
}
