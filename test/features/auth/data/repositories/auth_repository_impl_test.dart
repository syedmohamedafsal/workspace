import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rebs/core/config/employee_config.dart';
import 'package:rebs/core/error/exceptions.dart';
import 'package:rebs/core/error/failures.dart';
import 'package:rebs/features/auth/data/datasources/auth_local_datasource.dart';
import 'package:rebs/features/auth/data/models/employee_model.dart';
import 'package:rebs/features/auth/data/models/employee_session_model.dart';
import 'package:rebs/features/auth/data/repositories/auth_repository_impl.dart';

class MockAuthLocalDataSource extends Mock implements AuthLocalDataSource {}

void main() {
  late MockAuthLocalDataSource localDataSource;
  late PreconfiguredEmployeeConfig employeeConfig;
  late DateTime currentTime;
  late AuthRepositoryImpl repository;

  setUpAll(() {
    registerFallbackValue(
      EmployeeSessionModel(
        sessionId: 'fallback',
        employee: const EmployeeModel(
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
      ),
    );
  });

  setUp(() {
    localDataSource = MockAuthLocalDataSource();
    employeeConfig = const PreconfiguredEmployeeConfig(
      officeLatitude: 13.0827,
      officeLongitude: 80.2707,
      companyTimezone: 'Asia/Kolkata',
    );
    currentTime = DateTime(2026, 11, 18, 9, 30);
    repository = AuthRepositoryImpl(
      localDataSource: localDataSource,
      employeeConfig: employeeConfig,
      clock: () => currentTime,
    );
  });

  test(
      'initializes and persists preconfigured employee session when none exists',
      () async {
    when(() => localDataSource.getActiveSession())
        .thenAnswer((_) async => null);
    when(() => localDataSource.saveSession(any())).thenAnswer((_) async {});

    final result = await repository.initializeSession();

    expect(result.isSuccess, isTrue);
    final session = result.dataOrNull!;
    expect(session.isValid, isTrue);
    expect(session.sessionId, isNotEmpty);
    expect(session.employee.employeeId, 'REBS001');
    expect(session.employee.employeeName, 'Syed Mohamed Afsal');
    expect(session.employee.department, 'Engineering');
    expect(session.employee.designation, 'Flutter Developer');
    expect(session.employee.officeId, 'OFFICE001');
    expect(session.employee.officeName, 'REBS Chennai Office');
    expect(session.employee.officeLatitude, 13.0827);
    expect(session.employee.officeLongitude, 80.2707);
    expect(session.employee.companyTimezone, 'Asia/Kolkata');
    expect(session.initializedAt, currentTime);
    expect(session.lastRestoredAt, currentTime);

    verify(() => localDataSource.saveSession(any())).called(1);
  });

  test('restores existing valid session without creating a new session id',
      () async {
    final originalInitTime = DateTime(2026, 11, 17, 8, 0);
    final existingSession = EmployeeSessionModel(
      sessionId: 'existing-session-123',
      employee: EmployeeModel.fromConfig(employeeConfig),
      initializedAt: originalInitTime,
      lastRestoredAt: originalInitTime,
      isActive: true,
    );

    when(() => localDataSource.getActiveSession())
        .thenAnswer((_) async => existingSession);
    when(() => localDataSource.saveSession(any())).thenAnswer((_) async {});

    final result = await repository.initializeSession();

    expect(result.isSuccess, isTrue);
    final restored = result.dataOrNull!;
    expect(restored.sessionId, 'existing-session-123');
    expect(restored.initializedAt, originalInitTime);
    expect(restored.lastRestoredAt, currentTime);

    verify(() => localDataSource.saveSession(any())).called(1);
  });

  test('re-initializes session when stored session is invalid', () async {
    final invalidSession = EmployeeSessionModel(
      sessionId: '',
      employee: EmployeeModel.fromConfig(employeeConfig),
      initializedAt: DateTime(2026, 11, 17),
      lastRestoredAt: DateTime(2026, 11, 17),
      isActive: true,
    );

    when(() => localDataSource.getActiveSession())
        .thenAnswer((_) async => invalidSession);
    when(() => localDataSource.saveSession(any())).thenAnswer((_) async {});

    final result = await repository.initializeSession();

    expect(result.isSuccess, isTrue);
    expect(result.dataOrNull!.sessionId, isNotEmpty);
    verify(() => localDataSource.saveSession(any())).called(1);
  });

  test('restoreSession returns null when no active session exists', () async {
    when(() => localDataSource.getActiveSession())
        .thenAnswer((_) async => null);

    final result = await repository.restoreSession();

    expect(result.isSuccess, isTrue);
    expect(result.dataOrNull, isNull);
    verifyNever(() => localDataSource.saveSession(any()));
  });

  test('clearSession clears persisted session via local data source', () async {
    when(() => localDataSource.clearSession()).thenAnswer((_) async {});

    final result = await repository.clearSession();

    expect(result.isSuccess, isTrue);
    verify(() => localDataSource.clearSession()).called(1);
  });

  test('returns CacheFailure when storage fails during initialization',
      () async {
    when(() => localDataSource.getActiveSession())
        .thenThrow(const CacheException('Database unavailable'));

    final result = await repository.initializeSession();

    expect(result.isFailure, isTrue);
    expect(result.failureOrNull, isA<CacheFailure>());
    expect(result.failureOrNull?.message, 'Database unavailable');
  });
}
