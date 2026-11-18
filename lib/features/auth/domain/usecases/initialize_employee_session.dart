import '../../../../core/error/result.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/employee_session.dart';
import '../repositories/auth_repository.dart';

/// Restores an existing valid session or initializes the preconfigured employee.
class InitializeEmployeeSession
    implements UseCase<EmployeeSession, NoParams> {
  const InitializeEmployeeSession(this._repository);

  final AuthRepository _repository;

  @override
  Future<Result<EmployeeSession>> call(NoParams params) {
    return _repository.initializeSession();
  }
}
