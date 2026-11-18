import '../../../../core/error/result.dart';
import '../../../../core/usecases/usecase.dart';
import '../repositories/auth_repository.dart';

/// Clears the locally persisted employee session.
class ClearEmployeeSession implements UseCase<void, NoParams> {
  const ClearEmployeeSession(this._repository);

  final AuthRepository _repository;

  @override
  Future<Result<void>> call(NoParams params) {
    return _repository.clearSession();
  }
}
