import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../features/accounts/presentation/pages/accounts_placeholder_page.dart';
import '../../features/auth/presentation/pages/splash_page.dart';
import '../../features/crm/presentation/pages/crm_placeholder_page.dart';
import '../../features/hrms/attendance/presentation/bloc/attendance_bloc.dart';
import '../../features/hrms/attendance/presentation/pages/attendance_page.dart';
import '../../features/hrms/dashboard/presentation/pages/employee_dashboard_page.dart';
import '../../features/hrms/leave/presentation/bloc/leave_bloc.dart';
import '../../features/hrms/leave/presentation/pages/leave_page.dart';
import '../../features/modules/presentation/pages/rebs_modules_page.dart';
import '../di/injection_container.dart';
import '../sync/sync_manager.dart';
import '../widgets/app_shell_scaffold.dart';

abstract final class AppRoutes {
  static const String splash = '/splash';
  static const String dashboard = '/hrms/dashboard';
  static const String attendance = '/hrms/attendance';
  static const String leave = '/hrms/leave';
  static const String modules = '/modules';
  static const String crm = '/crm';
  static const String accounts = '/accounts';
}

GoRouter createAppRouter() {
  return GoRouter(
    initialLocation: AppRoutes.splash,
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashPage(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return MultiBlocProvider(
            providers: [
              BlocProvider<AttendanceBloc>(
                create: (_) => sl<AttendanceBloc>(),
              ),
              BlocProvider<LeaveBloc>(
                create: (_) => sl<LeaveBloc>(),
              ),
            ],
            child: AppShellScaffold(
              navigationShell: navigationShell,
              syncManager: sl<SyncManager>(),
            ),
          );
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.dashboard,
                builder: (context, state) => const EmployeeDashboardPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.attendance,
                builder: (context, state) => const AttendancePage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.leave,
                builder: (context, state) => const LeavePage(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.modules,
        builder: (context, state) => const RebsModulesPage(),
      ),
      GoRoute(
        path: AppRoutes.crm,
        builder: (context, state) => const CrmPlaceholderPage(),
      ),
      GoRoute(
        path: AppRoutes.accounts,
        builder: (context, state) => const AccountsPlaceholderPage(),
      ),
    ],
  );
}
