/// SQLite database schema constants for offline-first persistence.
abstract final class DbConstants {
  static const String databaseName = 'rebs_offline.db';
  static const int databaseVersion = 6;

  // Tables
  static const String tableEmployeeSessions = 'employee_sessions';
  static const String tableAttendance = 'attendance_records';
  static const String tableLeaveRequests = 'leave_requests';
  static const String tableLeaveBalances = 'leave_balances';
  static const String tableSyncQueue = 'sync_queue';

  // Common sync columns
  static const String colLocalId = 'local_id';
  static const String colServerId = 'server_id';
  static const String colSyncStatus = 'sync_status';
  static const String colSyncError = 'sync_error';
  static const String colUpdatedAt = 'updated_at';
  static const String colCreatedAt = 'created_at';
}
