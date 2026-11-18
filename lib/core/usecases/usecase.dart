import 'package:equatable/equatable.dart';

import '../error/result.dart';

/// Base contract for all Clean Architecture domain use cases.
abstract interface class UseCase<T, Params> {
  Future<Result<T>> call(Params params);
}

/// Marker parameter class for use cases that require no input.
final class NoParams extends Equatable {
  const NoParams();

  @override
  List<Object?> get props => const [];
}
