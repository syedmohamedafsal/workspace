import '../../../../core/error/result.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/employee_session.dart';
import '../repositories/auth_repository.dart';

/// Restores a previously persisted employee session if one exists and is valid.
class RestoreEmployeeSession
    implements UseCase<EmployeeSession?, NoParams> {
  const RestoreEmployeeSession(this._repository);

  final AuthRepository _repository;

  @override
  Future<Result<EmployeeSession?>> call(NoParams params) {
    return _repository.restoreSession();
  }
}
