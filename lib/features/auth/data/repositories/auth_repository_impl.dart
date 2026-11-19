import 'package:uuid/uuid.dart';

import '../../../../core/config/employee_config.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/error/result.dart';
import '../../domain/entities/employee_session.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_local_datasource.dart';
import '../datasources/auth_remote_datasource.dart';
import '../models/employee_model.dart';
import '../models/employee_session_model.dart';

/// Offline-first repository managing local preconfigured employee sessions.
class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({
    required AuthLocalDataSource localDataSource,
    required PreconfiguredEmployeeConfig employeeConfig,
    AuthRemoteDataSource? remoteDataSource,
    Uuid? uuid,
    DateTime Function()? clock,
  })  : _localDataSource = localDataSource,
        _employeeConfig = employeeConfig,
        _remoteDataSource = remoteDataSource,
        _uuid = uuid ?? const Uuid(),
        _clock = clock ?? DateTime.now;

  final AuthLocalDataSource _localDataSource;
  final PreconfiguredEmployeeConfig _employeeConfig;
  final AuthRemoteDataSource? _remoteDataSource;
  final Uuid _uuid;
  final DateTime Function() _clock;

  @override
  Future<Result<EmployeeSession>> initializeSession() async {
    try {
      final now = _clock();

      // If remote data source is configured, attempt to fetch live employee
      // and office configuration from GET /employee/me.
      EmployeeModel? remoteEmployee;
      if (_remoteDataSource != null) {
        try {
          remoteEmployee = await _remoteDataSource.fetchCurrentEmployee();
        } catch (_) {
          // Graceful fallback: when offline or server is unreachable, continue
          // using persisted cache or preconfigured local profile.
        }
      }

      final persisted = await _localDataSource.getActiveSession();

      if (persisted != null && persisted.isValid) {
        final base = remoteEmployee ?? persisted.employee;
        final refreshedEmployee = base.copyWith(
          officeId: remoteEmployee?.officeId ?? _employeeConfig.officeId,
          officeName: remoteEmployee?.officeName ?? _employeeConfig.officeName,
          officeLatitude: remoteEmployee?.officeLatitude ??
              _employeeConfig.officeLatitude,
          officeLongitude: remoteEmployee?.officeLongitude ??
              _employeeConfig.officeLongitude,
          companyTimezone: remoteEmployee?.companyTimezone ??
              _employeeConfig.companyTimezone,
        );
        final restored = EmployeeSessionModel.fromEntity(
          persisted.copyWith(
            employee: refreshedEmployee,
            lastRestoredAt: now,
          ),
        );
        await _localDataSource.saveSession(restored);
        return Success(restored);
      }

      final employee = remoteEmployee ?? EmployeeModel.fromConfig(_employeeConfig);
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
