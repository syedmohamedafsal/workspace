import 'package:uuid/uuid.dart';

import '../../../../core/config/employee_config.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/error/result.dart';
import '../../domain/entities/employee_session.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_local_datasource.dart';
import '../models/employee_model.dart';
import '../models/employee_session_model.dart';

/// Offline-first repository managing local preconfigured employee sessions.
class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({
    required AuthLocalDataSource localDataSource,
    required PreconfiguredEmployeeConfig employeeConfig,
    Uuid? uuid,
    DateTime Function()? clock,
  })  : _localDataSource = localDataSource,
        _employeeConfig = employeeConfig,
        _uuid = uuid ?? const Uuid(),
        _clock = clock ?? DateTime.now;

  final AuthLocalDataSource _localDataSource;
  final PreconfiguredEmployeeConfig _employeeConfig;
  final Uuid _uuid;
  final DateTime Function() _clock;

  @override
  Future<Result<EmployeeSession>> signIn({
    required String employeeId,
    required String password,
  }) async {
    try {
      final normalizedId = employeeId.trim().toUpperCase();
      if (normalizedId.isEmpty) {
        return const FailureResult(
          ValidationFailure('Employee ID cannot be empty.'),
        );
      }
      if (password.trim().length < 4) {
        return const FailureResult(
          ValidationFailure('Password must be at least 4 characters.'),
        );
      }

      final now = _clock();
      final baseEmployee = EmployeeModel.fromConfig(_employeeConfig);
      final employee = normalizedId == _employeeConfig.employeeId.toUpperCase()
          ? baseEmployee
          : EmployeeModel.fromEntity(
              baseEmployee.copyWith(employeeId: normalizedId),
            );

      if (!employee.hasValidIdentity) {
        return const FailureResult(
          ValidationFailure(
            'Employee configuration is invalid. Please contact support.',
          ),
        );
      }

      final session = EmployeeSessionModel(
        sessionId: _uuid.v4(),
        employee: employee,
        initializedAt: now,
        lastRestoredAt: now,
        isActive: true,
      );

      await _localDataSource.saveSession(session);
      return Success(session);
    } on CacheException catch (e) {
      return FailureResult(CacheFailure(e.message));
    } catch (e) {
      return FailureResult(
        UnexpectedFailure('Failed to sign in: $e'),
      );
    }
  }

  @override
  Future<Result<EmployeeSession>> initializeSession() async {
    try {
      final now = _clock();
      final persisted = await _localDataSource.getActiveSession();

      if (persisted != null && persisted.isValid) {
        final restored = EmployeeSessionModel.fromEntity(
          persisted.copyWith(lastRestoredAt: now),
        );
        await _localDataSource.saveSession(restored);
        return Success(restored);
      }

      final employee = EmployeeModel.fromConfig(_employeeConfig);
      if (!employee.hasValidIdentity) {
        return const FailureResult(
          ValidationFailure(
            'Preconfigured employee configuration is invalid. Please check app configuration.',
          ),
        );
      }

      final newSession = EmployeeSessionModel(
        sessionId: _uuid.v4(),
        employee: employee,
        initializedAt: now,
        lastRestoredAt: now,
        isActive: true,
      );

      await _localDataSource.saveSession(newSession);
      return Success(newSession);
    } on CacheException catch (e) {
      return FailureResult(CacheFailure(e.message));
    } catch (e) {
      return FailureResult(
        UnexpectedFailure('Failed to initialize employee session: $e'),
      );
    }
  }

  @override
  Future<Result<EmployeeSession?>> restoreSession() async {
    try {
      final persisted = await _localDataSource.getActiveSession();
      if (persisted == null || !persisted.isValid) {
        return const Success(null);
      }

      final restored = EmployeeSessionModel.fromEntity(
        persisted.copyWith(lastRestoredAt: _clock()),
      );
      await _localDataSource.saveSession(restored);
      return Success(restored);
    } on CacheException catch (e) {
      return FailureResult(CacheFailure(e.message));
    } catch (e) {
      return FailureResult(
        UnexpectedFailure('Failed to restore employee session: $e'),
      );
    }
  }

  @override
  Future<Result<void>> clearSession() async {
    try {
      await _localDataSource.clearSession();
      return const Success(null);
    } on CacheException catch (e) {
      return FailureResult(CacheFailure(e.message));
    } catch (e) {
      return FailureResult(
        UnexpectedFailure('Failed to clear employee session: $e'),
      );
    }
  }
}
