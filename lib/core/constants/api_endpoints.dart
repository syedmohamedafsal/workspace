import 'package:flutter/foundation.dart';

/// Centralized API configuration that resolves the base URL dynamically.
///
/// Uses the ternary operator with [kReleaseMode] to select between production
/// and debug base URLs, with support for command-line overrides via
/// `--dart-define=API_BASE_URL=...`.
abstract final class ApiConfig {
  /// Production API Gateway for REBS Enterprise.
  static const String productionBaseUrl = 'https://api.rebs.example.com/v1';

  /// Local mock HTTP API server host (default loopback).
  static const String debugBaseUrl = 'http://127.0.0.1:8080';

  /// Android emulator loopback alias routing to host machine.
  static const String androidEmulatorDebugBaseUrl = 'http://10.0.2.2:8080';

  /// Returns the appropriate debug base URL depending on the platform:
  /// Android emulator uses `http://10.0.2.2:8080`, while macOS / iOS / Web / Linux
  /// use `http://127.0.0.1:8080`.
  static String get defaultDebugBaseUrl {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return androidEmulatorDebugBaseUrl;
    }
    return debugBaseUrl;
  }

  /// Base URL resolved via ternary operator:
  /// Release mode uses [productionBaseUrl], Debug/Profile mode uses [defaultDebugBaseUrl].
  /// Can be overridden at build or run time with `--dart-define=API_BASE_URL=...`.
  static String get baseUrl {
    const envOverride = String.fromEnvironment('API_BASE_URL');
    if (envOverride.isNotEmpty) {
      return envOverride;
    }
    return kReleaseMode ? productionBaseUrl : defaultDebugBaseUrl;
  }
}

/// Centralized REST API endpoints for all REBS modules matching Section 5 specification.
abstract final class ApiEndpoints {
  /// Dynamic base URL for the active environment.
  static String get baseUrl => ApiConfig.baseUrl;

  // 1. Employee & Office Configuration
  // GET /employee/me
  static const String employeeMe = '/employee/me';

  // 2. Attendance History
  // GET /attendance?month=YYYY-MM
  static const String attendance = '/attendance';
  static const String attendanceHistory = '/hrms/attendance/history';

  // 3. Attendance Events
  // POST /attendance/events
  static const String attendanceEvents = '/attendance/events';
  static const String attendanceBase = '/hrms/attendance';
  static const String attendanceCheckIn = '/hrms/attendance/check-in';
  static const String attendanceCheckOut = '/hrms/attendance/check-out';

  // 4. Available Leave Balance
  // GET /leave/balance
  static const String leaveBalances = '/leave/balance';

  // 5. Existing Leave Requests & 6. Submit Leave Application
  // GET /leave/requests & POST /leave/requests
  static const String leaveRequests = '/leave/requests';
  static String cancelLeave(String id) => '/leave/requests/$id/cancel';

  // CRM (Module placeholder endpoints)
  static const String crmLeads = '/crm/leads';
  static const String crmDeals = '/crm/deals';

  // Accounts (Module placeholder endpoints)
  static const String accountsInvoices = '/accounts/invoices';
  static const String accountsExpenses = '/accounts/expenses';

  // Mock Server Scenario & Control Endpoints
  static const String mockScenario = '/mock/scenario';
  static const String mockReset = '/mock/reset';
}
