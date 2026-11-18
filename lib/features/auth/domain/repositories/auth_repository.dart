import '../../../../core/error/result.dart';
import '../entities/employee_session.dart';

/// Domain contract for employee authentication and session management.
abstract interface class AuthRepository {
  /// Signs in an employee with credentials and persists the active session.
  Future<Result<EmployeeSession>> signIn({
    required String employeeId,
    required String password,
  });

  /// Restores an existing valid local session, or creates and persists one
  /// from the configured preconfigured employee profile if none exists.
  Future<Result<EmployeeSession>> initializeSession();

  /// Restores the currently persisted valid employee session, if available.
  Future<Result<EmployeeSession?>> restoreSession();

  /// Clears any locally persisted employee session.
  Future<Result<void>> clearSession();
}
