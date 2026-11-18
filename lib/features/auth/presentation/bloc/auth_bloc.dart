import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/usecases/usecase.dart';
import '../../domain/usecases/clear_employee_session.dart';
import '../../domain/usecases/initialize_employee_session.dart';
import '../../domain/usecases/restore_employee_session.dart';
import '../../domain/usecases/sign_in_employee.dart';
import 'auth_event.dart';
import 'auth_state.dart';

/// Manages employee authentication and local session lifecycle.
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc({
    required SignInEmployee signInEmployee,
    required InitializeEmployeeSession initializeEmployeeSession,
    required RestoreEmployeeSession restoreEmployeeSession,
    required ClearEmployeeSession clearEmployeeSession,
  })  : _signInEmployee = signInEmployee,
        _initializeEmployeeSession = initializeEmployeeSession,
        _restoreEmployeeSession = restoreEmployeeSession,
        _clearEmployeeSession = clearEmployeeSession,
        super(const AuthInitial()) {
    on<AuthSessionRestoreRequested>(_onRestoreSession);
    on<AuthSessionRetryRequested>(_onRetryRestore);
    on<AuthSessionSignInRequested>(_onSignIn);
    on<AuthSessionInitializeRequested>(_onInitializeDemoSession);
    on<AuthSessionClearRequested>(_onClearSession);
  }

  final SignInEmployee _signInEmployee;
  final InitializeEmployeeSession _initializeEmployeeSession;
  final RestoreEmployeeSession _restoreEmployeeSession;
  final ClearEmployeeSession _clearEmployeeSession;

  Future<void> _onRestoreSession(
    AuthSessionRestoreRequested event,
    Emitter<AuthState> emit,
  ) async {
    await _runRestore(emit);
  }

  Future<void> _onRetryRestore(
    AuthSessionRetryRequested event,
    Emitter<AuthState> emit,
  ) async {
    await _runRestore(emit);
  }

  Future<void> _runRestore(Emitter<AuthState> emit) async {
    emit(const AuthLoading());
    final result = await _restoreEmployeeSession(const NoParams());
    result.fold(
      onSuccess: (session) {
        if (session != null) {
          emit(AuthAuthenticated(session));
        } else {
          emit(const AuthUnauthenticated());
        }
      },
      onFailure: (failure) => emit(AuthError(failure.message)),
    );
  }

  Future<void> _onSignIn(
    AuthSessionSignInRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    final result = await _signInEmployee(
      SignInEmployeeParams(
        employeeId: event.employeeId,
        password: event.password,
      ),
    );
    result.fold(
      onSuccess: (session) => emit(AuthAuthenticated(session)),
      onFailure: (failure) => emit(AuthError(failure.message)),
    );
  }

  Future<void> _onInitializeDemoSession(
    AuthSessionInitializeRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    final result = await _initializeEmployeeSession(const NoParams());
    result.fold(
      onSuccess: (session) => emit(AuthAuthenticated(session)),
      onFailure: (failure) => emit(AuthError(failure.message)),
    );
  }

  Future<void> _onClearSession(
    AuthSessionClearRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    final result = await _clearEmployeeSession(const NoParams());
    result.fold(
      onSuccess: (_) => emit(const AuthUnauthenticated()),
      onFailure: (failure) => emit(AuthError(failure.message)),
    );
  }
}
