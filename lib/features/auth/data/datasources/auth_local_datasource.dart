import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../../../core/constants/db_constants.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/error/exceptions.dart';
import '../models/employee_session_model.dart';

/// Local persistence abstraction for the active employee session.
abstract interface class AuthLocalDataSource {
  Future<EmployeeSessionModel?> getActiveSession();

  Future<void> saveSession(EmployeeSessionModel session);

  Future<void> clearSession();
}

/// SQLite-backed implementation reusing [AppDatabase].
class AuthLocalDataSourceImpl implements AuthLocalDataSource {
  AuthLocalDataSourceImpl(this._appDatabase);

  final AppDatabase _appDatabase;

  @override
  Future<EmployeeSessionModel?> getActiveSession() async {
    try {
      final db = await _appDatabase.database;
      final rows = await db.query(
        DbConstants.tableEmployeeSessions,
        where: 'is_active = ?',
        whereArgs: const [1],
        orderBy: 'last_restored_at DESC',
        limit: 1,
      );
      if (rows.isEmpty) {
        return null;
      }
      return EmployeeSessionModel.fromDbMap(rows.first);
    } catch (e) {
      throw CacheException('Failed to read persisted employee session.', cause: e);
    }
  }

  @override
  Future<void> saveSession(EmployeeSessionModel session) async {
    try {
      final db = await _appDatabase.database;
      await db.transaction((txn) async {
        // Maintain a single active employee session row at a time.
        await txn.delete(DbConstants.tableEmployeeSessions);
        await txn.insert(
          DbConstants.tableEmployeeSessions,
          session.toDbMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      });
    } catch (e) {
      throw CacheException('Failed to persist employee session.', cause: e);
    }
  }

  @override
  Future<void> clearSession() async {
    try {
      final db = await _appDatabase.database;
      await db.delete(DbConstants.tableEmployeeSessions);
    } catch (e) {
      throw CacheException('Failed to clear employee session.', cause: e);
    }
  }
}
