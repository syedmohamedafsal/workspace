import 'package:flutter_test/flutter_test.dart';
import 'package:rebs/core/config/employee_config.dart';
import 'package:rebs/core/database/app_database.dart';
import 'package:rebs/features/auth/data/datasources/auth_local_datasource.dart';
import 'package:rebs/features/auth/data/models/employee_model.dart';
import 'package:rebs/features/auth/data/models/employee_session_model.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  late AppDatabase appDatabase;
  late AuthLocalDataSourceImpl dataSource;

  setUp(() {
    appDatabase = AppDatabase(
      databaseFactoryOverride: databaseFactoryFfi,
      pathOverride: inMemoryDatabasePath,
    );
    dataSource = AuthLocalDataSourceImpl(appDatabase);
  });

  tearDown(() async {
    await appDatabase.close();
  });

  test('persists, restores, replaces, and clears employee session in SQLite',
      () async {
    // Initially empty
    expect(await dataSource.getActiveSession(), isNull);

    final firstSession = EmployeeSessionModel(
      sessionId: 'sess-001',
      employee: EmployeeModel.fromConfig(const PreconfiguredEmployeeConfig()),
      initializedAt: DateTime(2026, 11, 18, 9, 0),
      lastRestoredAt: DateTime(2026, 11, 18, 9, 0),
      isActive: true,
    );

    // Persist and restore
    await dataSource.saveSession(firstSession);
    final restored = await dataSource.getActiveSession();

    expect(restored, equals(firstSession));
    expect(restored?.employee.employeeId, 'REBS001');
    expect(restored?.employee.employeeName, 'Syed Mohamed Afsal');
    expect(restored?.employee.officeName, 'REBS Chennai Office');

    // Replace with updated timestamp
    final updatedSession = EmployeeSessionModel.fromEntity(
      firstSession.copyWith(lastRestoredAt: DateTime(2026, 11, 18, 12, 0)),
    );
    await dataSource.saveSession(updatedSession);
    final restoredAfterUpdate = await dataSource.getActiveSession();
    expect(restoredAfterUpdate, equals(updatedSession));

    // Clear session
    await dataSource.clearSession();
    expect(await dataSource.getActiveSession(), isNull);
  });
}
