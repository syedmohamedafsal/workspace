import 'package:equatable/equatable.dart';

sealed class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => const [];
}

/// Triggered on app launch to check for an existing persisted employee session.
final class AuthSessionRestoreRequested extends AuthEvent {
  const AuthSessionRestoreRequested();
}

/// Triggered when the employee submits credentials on the login screen.
final class AuthSessionSignInRequested extends AuthEvent {
  const AuthSessionSignInRequested({
    required this.employeeId,
    required this.password,
  });

  final String employeeId;
  final String password;

  @override
  List<Object?> get props => [employeeId, password];
}

/// Triggered for one-tap offline demo sign-in using the preconfigured employee.
final class AuthSessionInitializeRequested extends AuthEvent {
  const AuthSessionInitializeRequested();
}

/// Triggered when the user taps Retry after an initialization error on Splash.
final class AuthSessionRetryRequested extends AuthEvent {
  const AuthSessionRetryRequested();
}

/// Triggered to sign out and clear the persisted employee session.
final class AuthSessionClearRequested extends AuthEvent {
  const AuthSessionClearRequested();
}
