import 'package:equatable/equatable.dart';

sealed class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => const [];
}

/// Triggered on app launch to restore an existing persisted session or
/// initialize the preconfigured employee session.
final class AuthSessionInitializeRequested extends AuthEvent {
  const AuthSessionInitializeRequested();
}

/// Triggered when the user taps Retry after an initialization error.
final class AuthSessionRetryRequested extends AuthEvent {
  const AuthSessionRetryRequested();
}

/// Triggered to explicitly restore an existing persisted session without
/// creating a new one.
final class AuthSessionRestoreRequested extends AuthEvent {
  const AuthSessionRestoreRequested();
}

/// Triggered to clear the persisted employee session.
final class AuthSessionClearRequested extends AuthEvent {
  const AuthSessionClearRequested();
}
