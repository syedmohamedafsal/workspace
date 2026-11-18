import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../features/accounts/presentation/pages/accounts_placeholder_page.dart';
import '../../features/crm/presentation/pages/crm_placeholder_page.dart';
import '../../features/hrms/attendance/presentation/bloc/attendance_bloc.dart';
import '../../features/hrms/attendance/presentation/pages/attendance_page.dart';
import '../../features/hrms/leave/presentation/bloc/leave_bloc.dart';
import '../../features/hrms/leave/presentation/pages/leave_page.dart';
import '../di/injection_container.dart';
import '../sync/sync_manager.dart';
import '../widgets/app_shell_scaffold.dart';

abstract final class AppRoutes {
  static const String attendance = '/hrms/attendance';
  static const String leave = '/hrms/leave';
  static const String crm = '/crm';
  static const String accounts = '/accounts';
}

GoRouter createAppRouter() {
  return GoRouter(
    initialLocation: AppRoutes.attendance,
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return AppShellScaffold(
            navigationShell: navigationShell,
            syncManager: sl<SyncManager>(),
          );
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.attendance,
                builder: (context, state) => BlocProvider(
                  create: (_) => sl<AttendanceBloc>(),
                  child: const AttendancePage(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.leave,
                builder: (context, state) => BlocProvider(
                  create: (_) => sl<LeaveBloc>(),
                  child: const LeavePage(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.crm,
                builder: (context, state) => const CrmPlaceholderPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.accounts,
                builder: (context, state) => const AccountsPlaceholderPage(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}
