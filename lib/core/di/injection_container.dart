import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:get_it/get_it.dart';

import '../../features/auth/data/datasources/auth_local_datasource.dart';
import '../../features/auth/data/repositories/auth_repository_impl.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/auth/domain/usecases/clear_employee_session.dart';
import '../../features/auth/domain/usecases/initialize_employee_session.dart';
import '../../features/auth/domain/usecases/restore_employee_session.dart';
import '../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../features/hrms/attendance/data/datasources/attendance_local_datasource.dart';
import '../../features/hrms/attendance/data/datasources/attendance_remote_datasource.dart';
import '../../features/hrms/attendance/data/repositories/attendance_repository_impl.dart';
import '../../features/hrms/attendance/data/sync/attendance_sync_handler.dart';
import '../../features/hrms/attendance/domain/repositories/attendance_repository.dart';
import '../../features/hrms/attendance/domain/usecases/check_in.dart';
import '../../features/hrms/attendance/domain/usecases/check_out.dart';
import '../../features/hrms/attendance/domain/usecases/get_attendance_history.dart';
import '../../features/hrms/attendance/domain/usecases/get_today_attendance.dart';
import '../../features/hrms/attendance/presentation/bloc/attendance_bloc.dart';
import '../../features/hrms/leave/data/datasources/leave_local_datasource.dart';
import '../../features/hrms/leave/data/datasources/leave_remote_datasource.dart';
import '../../features/hrms/leave/data/repositories/leave_repository_impl.dart';
import '../../features/hrms/leave/data/sync/leave_sync_handler.dart';
import '../../features/hrms/leave/domain/repositories/leave_repository.dart';
import '../../features/hrms/leave/domain/usecases/apply_leave.dart';
import '../../features/hrms/leave/domain/usecases/cancel_leave.dart';
import '../../features/hrms/leave/domain/usecases/get_leave_balances.dart';
import '../../features/hrms/leave/domain/usecases/get_leave_requests.dart';
import '../../features/hrms/leave/presentation/bloc/leave_bloc.dart';
import '../config/app_config.dart';
import '../database/app_database.dart';
import '../network/api_client.dart';
import '../network/network_info.dart';
import '../sync/sync_manager.dart';
import '../sync/sync_queue_datasource.dart';

final GetIt sl = GetIt.instance;

/// Initializes all core services, offline storage, sync handlers, and modules.
Future<void> initDependencies({
  AppConfig config = const AppConfig(),
  AppDatabase? databaseOverride,
  NetworkInfo? networkInfoOverride,
  AuthRepository? authRepositoryOverride,
}) async {
  // Core
  sl.registerSingleton<AppConfig>(config);
  sl.registerSingleton<AppDatabase>(databaseOverride ?? AppDatabase());
  sl.registerLazySingleton<Connectivity>(() => Connectivity());
  sl.registerLazySingleton<NetworkInfo>(
    () => networkInfoOverride ?? NetworkInfoImpl(sl()),
  );
  sl.registerLazySingleton<ApiClient>(() => ApiClient(config: sl()));
  sl.registerLazySingleton<SyncQueueDataSource>(
    () => SyncQueueDataSource(sl()),
  );
  sl.registerLazySingleton<SyncManager>(
    () => SyncManager(
      queueDataSource: sl(),
      networkInfo: sl(),
      config: sl(),
    ),
  );

  // Module: Authentication & Employee Session
  _registerAuthModule(authRepositoryOverride: authRepositoryOverride);

  // Module: HRMS - Attendance
  _registerAttendanceModule();

  // Module: HRMS - Leave
  _registerLeaveModule();

  // Wire module sync handlers into the shared outbox sync engine
  final syncManager = sl<SyncManager>();
  syncManager.registerHandler(sl<AttendanceSyncHandler>());
  syncManager.registerHandler(sl<LeaveSyncHandler>());
  await syncManager.initialize();
}

void _registerAuthModule({AuthRepository? authRepositoryOverride}) {
  // Data sources
  sl.registerLazySingleton<AuthLocalDataSource>(
    () => AuthLocalDataSourceImpl(sl()),
  );

  // Repository
  sl.registerLazySingleton<AuthRepository>(
    () =>
        authRepositoryOverride ??
        AuthRepositoryImpl(
          localDataSource: sl(),
          employeeConfig: sl<AppConfig>().employeeConfig,
        ),
  );

  // Use cases
  sl.registerLazySingleton(() => InitializeEmployeeSession(sl()));
  sl.registerLazySingleton(() => RestoreEmployeeSession(sl()));
  sl.registerLazySingleton(() => ClearEmployeeSession(sl()));

  // Presentation BLoC
  sl.registerFactory(
    () => AuthBloc(
      initializeEmployeeSession: sl(),
      restoreEmployeeSession: sl(),
      clearEmployeeSession: sl(),
    ),
  );
}

void _registerAttendanceModule() {
  // Data sources
  sl.registerLazySingleton<AttendanceLocalDataSource>(
    () => AttendanceLocalDataSourceImpl(
      appDatabase: sl(),
      syncQueueDataSource: sl(),
    ),
  );
  sl.registerLazySingleton<AttendanceRemoteDataSource>(
    () => AttendanceRemoteDataSourceImpl(sl()),
  );

  // Sync handler
  sl.registerLazySingleton<AttendanceSyncHandler>(
    () => AttendanceSyncHandler(
      localDataSource: sl(),
      remoteDataSource: sl(),
    ),
  );

  // Repository
  sl.registerLazySingleton<AttendanceRepository>(
    () => AttendanceRepositoryImpl(
      localDataSource: sl(),
      remoteDataSource: sl(),
      networkInfo: sl(),
      syncManager: sl(),
      config: sl(),
    ),
  );

  // Use cases
  sl.registerLazySingleton(() => GetTodayAttendance(sl()));
  sl.registerLazySingleton(() => GetAttendanceHistory(sl()));
  sl.registerLazySingleton(() => CheckIn(sl()));
  sl.registerLazySingleton(() => CheckOut(sl()));

  // Presentation BLoC
  sl.registerFactory(
    () => AttendanceBloc(
      getTodayAttendance: sl(),
      getAttendanceHistory: sl(),
      checkIn: sl(),
      checkOut: sl(),
      syncManager: sl(),
    ),
  );
}

void _registerLeaveModule() {
  // Data sources
  sl.registerLazySingleton<LeaveLocalDataSource>(
    () => LeaveLocalDataSourceImpl(
      appDatabase: sl(),
      syncQueueDataSource: sl(),
    ),
  );
  sl.registerLazySingleton<LeaveRemoteDataSource>(
    () => LeaveRemoteDataSourceImpl(sl()),
  );

  // Sync handler
  sl.registerLazySingleton<LeaveSyncHandler>(
    () => LeaveSyncHandler(
      localDataSource: sl(),
      remoteDataSource: sl(),
    ),
  );

  // Repository
  sl.registerLazySingleton<LeaveRepository>(
    () => LeaveRepositoryImpl(
      localDataSource: sl(),
      remoteDataSource: sl(),
      networkInfo: sl(),
      syncManager: sl(),
      config: sl(),
    ),
  );

  // Use cases
  sl.registerLazySingleton(() => GetLeaveRequests(sl()));
  sl.registerLazySingleton(() => GetLeaveBalances(sl()));
  sl.registerLazySingleton(() => ApplyLeave(sl()));
  sl.registerLazySingleton(() => CancelLeave(sl()));

  // Presentation BLoC
  sl.registerFactory(
    () => LeaveBloc(
      getLeaveRequests: sl(),
      getLeaveBalances: sl(),
      applyLeave: sl(),
      cancelLeave: sl(),
      syncManager: sl(),
    ),
  );
}
