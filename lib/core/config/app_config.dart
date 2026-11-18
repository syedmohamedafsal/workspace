import 'employee_config.dart';

/// Application-wide configuration for the REBS platform.
///
/// Values can be overridden at build/run time using `--dart-define`:
/// ```bash
/// flutter run --dart-define=API_BASE_URL=https://api.yourdomain.com/v1
/// ```
class AppConfig {
  const AppConfig({
    this.apiBaseUrl = const String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'https://api.rebs.example.com/v1',
    ),
    this.connectTimeout = const Duration(seconds: 15),
    this.receiveTimeout = const Duration(seconds: 15),
    this.maxSyncRetries = 5,
    this.baseRetryDelay = const Duration(seconds: 5),
    this.maxRetryDelay = const Duration(minutes: 5),
    this.employeeConfig = const PreconfiguredEmployeeConfig(),
  });

  final String apiBaseUrl;
  final Duration connectTimeout;
  final Duration receiveTimeout;
  final int maxSyncRetries;
  final Duration baseRetryDelay;
  final Duration maxRetryDelay;

  /// Preconfigured employee, office coordinates, and company timezone settings.
  final PreconfiguredEmployeeConfig employeeConfig;

  String get defaultEmployeeId => employeeConfig.employeeId;
  String get defaultEmployeeName => employeeConfig.employeeName;
}
