import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/error/result.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/employee_session.dart';
import '../repositories/auth_repository.dart';

/// Authenticates an employee using Employee ID and password and persists
/// the session locally for offline-first access.
class SignInEmployee implements UseCase<EmployeeSession, SignInEmployeeParams> {
  const SignInEmployee(this._repository);

  final AuthRepository _repository;

  @override
  Future<Result<EmployeeSession>> call(SignInEmployeeParams params) async {
    final trimmedId = params.employeeId.trim();
    if (trimmedId.isEmpty) {
      return const FailureResult(
        ValidationFailure('Please enter your Employee ID.'),
      );
    }

    if (params.password.trim().length < 4) {
      return const FailureResult(
        ValidationFailure('Password must be at least 4 characters.'),
      );
    }

    return _repository.signIn(
      employeeId: trimmedId.toUpperCase(),
      password: params.password,
    );
  }
}

class SignInEmployeeParams extends Equatable {
  const SignInEmployeeParams({
    required this.employeeId,
    required this.password,
  });

  final String employeeId;
  final String password;

  @override
  List<Object?> get props => [employeeId, password];
}
