import 'package:equatable/equatable.dart';

/// Domain-layer failures returned inside [Result] instead of throwing.
sealed class Failure extends Equatable {
  const Failure(this.message, {this.code});

  final String message;
  final String? code;

  @override
  List<Object?> get props => [message, code];
}

final class ServerFailure extends Failure {
  const ServerFailure(super.message, {this.statusCode, super.code});

  final int? statusCode;

  @override
  List<Object?> get props => [message, code, statusCode];
}

final class NetworkFailure extends Failure {
  const NetworkFailure([
    super.message = 'You are offline. Changes have been saved locally.',
  ]);
}

final class CacheFailure extends Failure {
  const CacheFailure(super.message);
}

final class ConflictFailure extends Failure {
  const ConflictFailure(super.message, {super.code});
}

final class ValidationFailure extends Failure {
  const ValidationFailure(super.message, {super.code});
}

final class UnexpectedFailure extends Failure {
  const UnexpectedFailure(super.message);
}
