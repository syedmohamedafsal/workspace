import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rebs/core/error/failures.dart';
import 'package:rebs/core/error/result.dart';
import 'package:rebs/core/usecases/usecase.dart';
import 'package:rebs/features/auth/domain/entities/employee.dart';
import 'package:rebs/features/auth/domain/entities/employee_session.dart';
import 'package:rebs/features/auth/domain/usecases/clear_employee_session.dart';
import 'package:rebs/features/auth/domain/usecases/initialize_employee_session.dart';
import 'package:rebs/features/auth/domain/usecases/restore_employee_session.dart';
import 'package:rebs/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:rebs/features/auth/presentation/bloc/auth_event.dart';
import 'package:rebs/features/auth/presentation/bloc/auth_state.dart';

class MockInitializeEmployeeSession extends Mock
    implements InitializeEmployeeSession {}

class MockRestoreEmployeeSession extends Mock
    implements RestoreEmployeeSession {}

class MockClearEmployeeSession extends Mock implements ClearEmployeeSession {}

void main() {
  late MockInitializeEmployeeSession initializeUseCase;
  late MockRestoreEmployeeSession restoreUseCase;
  late MockClearEmployeeSession clearUseCase;

  final testSession = EmployeeSession(
    sessionId: 'session-1',
    employee: const Employee(
      employeeId: 'REBS001',
      employeeName: 'Syed Mohamed Afsal',
      department: 'Engineering',
      designation: 'Flutter Developer',
      officeId: 'OFFICE001',
      officeName: 'REBS Chennai Office',
      officeLatitude: 13.0827,
      officeLongitude: 80.2707,
      companyTimezone: 'Asia/Kolkata',
    ),
    initializedAt: DateTime(2026, 11, 18, 9, 0),
    lastRestoredAt: DateTime(2026, 11, 18, 9, 0),
  );

  setUpAll(() {
    registerFallbackValue(const NoParams());
  });

  setUp(() {
    initializeUseCase = MockInitializeEmployeeSession();
    restoreUseCase = MockRestoreEmployeeSession();
    clearUseCase = MockClearEmployeeSession();
  });

  AuthBloc buildBloc() => AuthBloc(
        initializeEmployeeSession: initializeUseCase,
        restoreEmployeeSession: restoreUseCase,
        clearEmployeeSession: clearUseCase,
      );

  test('initial state is AuthInitial', () {
    final bloc = buildBloc();
    expect(bloc.state, const AuthInitial());
    bloc.close();
  });

  blocTest<AuthBloc, AuthState>(
    'emits [AuthLoading, AuthAuthenticated] on successful session initialization',
    build: () {
      when(() => initializeUseCase(any()))
          .thenAnswer((_) async => Success(testSession));
      return buildBloc();
    },
    act: (bloc) => bloc.add(const AuthSessionInitializeRequested()),
    expect: () => [
      const AuthLoading(),
      AuthAuthenticated(testSession),
    ],
  );

  blocTest<AuthBloc, AuthState>(
    'emits [AuthLoading, AuthError] on initialization failure, then recovers on retry',
    build: () {
      var attempt = 0;
      when(() => initializeUseCase(any())).thenAnswer((_) async {
        attempt++;
        if (attempt == 1) {
          return const FailureResult(CacheFailure('Local database failed'));
        }
        return Success(testSession);
      });
      return buildBloc();
    },
    act: (bloc) async {
      bloc.add(const AuthSessionInitializeRequested());
      await Future<void>.delayed(Duration.zero);
      bloc.add(const AuthSessionRetryRequested());
    },
    expect: () => [
      const AuthLoading(),
      const AuthError('Local database failed'),
      const AuthLoading(),
      AuthAuthenticated(testSession),
    ],
  );

  blocTest<AuthBloc, AuthState>(
    'restores existing session into AuthAuthenticated',
    build: () {
      when(() => restoreUseCase(any()))
          .thenAnswer((_) async => Success(testSession));
      return buildBloc();
    },
    act: (bloc) => bloc.add(const AuthSessionRestoreRequested()),
    expect: () => [
      const AuthLoading(),
      AuthAuthenticated(testSession),
    ],
  );

  blocTest<AuthBloc, AuthState>(
    'clears session and returns to AuthInitial',
    build: () {
      when(() => clearUseCase(any()))
          .thenAnswer((_) async => const Success(null));
      return buildBloc();
    },
    seed: () => AuthAuthenticated(testSession),
    act: (bloc) => bloc.add(const AuthSessionClearRequested()),
    expect: () => [
      const AuthLoading(),
      const AuthInitial(),
    ],
  );
}
