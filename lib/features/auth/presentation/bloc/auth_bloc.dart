import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/usecases/usecase.dart';
import '../../domain/usecases/clear_employee_session.dart';
import '../../domain/usecases/initialize_employee_session.dart';
import '../../domain/usecases/restore_employee_session.dart';
import 'auth_event.dart';
import 'auth_state.dart';

/// Manages the lifecycle of the preconfigured REBS employee session.
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc({
    required InitializeEmployeeSession initializeEmployeeSession,
    required RestoreEmployeeSession restoreEmployeeSession,
    required ClearEmployeeSession clearEmployeeSession,
  })  : _initializeEmployeeSession = initializeEmployeeSession,
        _restoreEmployeeSession = restoreEmployeeSession,
        _clearEmployeeSession = clearEmployeeSession,
        super(const AuthInitial()) {
    on<AuthSessionInitializeRequested>(_onInitializeSession);
    on<AuthSessionRetryRequested>(_onRetryInitialization);
    on<AuthSessionRestoreRequested>(_onRestoreSession);
    on<AuthSessionClearRequested>(_onClearSession);
  }

  final InitializeEmployeeSession _initializeEmployeeSession;
  final RestoreEmployeeSession _restoreEmployeeSession;
  final ClearEmployeeSession _clearEmployeeSession;

  Future<void> _onInitializeSession(
    AuthSessionInitializeRequested event,
    Emitter<AuthState> emit,
  ) async {
    await _runInitialization(emit);
  }

  Future<void> _onRetryInitialization(
    AuthSessionRetryRequested event,
    Emitter<AuthState> emit,
  ) async {
    await _runInitialization(emit);
  }

  Future<void> _runInitialization(Emitter<AuthState> emit) async {
    emit(const AuthLoading());
    final result = await _initializeEmployeeSession(const NoParams());
    result.fold(
      onSuccess: (session) => emit(AuthAuthenticated(session)),
      onFailure: (failure) => emit(AuthError(failure.message)),
    );
  }

  Future<void> _onRestoreSession(
    AuthSessionRestoreRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    final result = await _restoreEmployeeSession(const NoParams());
    result.fold(
      onSuccess: (session) {
        if (session != null) {
          emit(AuthAuthenticated(session));
        } else {
          emit(const AuthInitial());
        }
      },
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
      onSuccess: (_) => emit(const AuthInitial()),
      onFailure: (failure) => emit(AuthError(failure.message)),
    );
  }
}
