import '../../../../core/error/result.dart';
import '../entities/employee_session.dart';

/// Domain contract for preconfigured employee session management.
abstract interface class AuthRepository {
  /// Restores an existing valid local session, or creates and persists one
  /// from the configured preconfigured employee profile if none exists.
  Future<Result<EmployeeSession>> initializeSession();

  /// Restores the currently persisted valid employee session, if available.
  Future<Result<EmployeeSession?>> restoreSession();

  /// Clears any locally persisted employee session.
  Future<Result<void>> clearSession();
}
