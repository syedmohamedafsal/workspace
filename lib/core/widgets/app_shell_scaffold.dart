import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../sync/sync_manager.dart';
import '../sync/sync_status.dart';
import '../theme/app_theme.dart';
import 'sync_feedback_handler.dart';
import 'sync_status_banner.dart';

/// Persistent navigation shell for the REBS employee workspace.
class AppShellScaffold extends StatelessWidget {
  const AppShellScaffold({
    super.key,
    required this.navigationShell,
    required this.syncManager,
  });

  final StatefulNavigationShell navigationShell;
  final SyncManager syncManager;

  static const _titles = [
    'Workspace',
    'Attendance',
    'Leave',
  ];

  @override
  Widget build(BuildContext context) {
    final currentIndex = navigationShell.currentIndex;
    final isDashboardTab = currentIndex == 0;

    return Scaffold(
      backgroundColor: isDashboardTab
          ? const Color(0xFF1575C8)
          : AppTheme.background,
      appBar: isDashboardTab
          ? null
          : AppBar(
              title: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0A0B0D),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Image.asset(
                      'assets/images/teqbae_mark.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(_titles[currentIndex]),
                ],
              ),
              actions: [
                StreamBuilder<SyncSnapshot>(
                  stream: syncManager.statusStream,
                  initialData: syncManager.currentSnapshot,
                  builder: (context, snapshot) {
                    final state = snapshot.data ?? const SyncSnapshot();
                    final hasPending = state.pendingCount > 0;
                    return Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Material(
                        color: hasPending
                            ? const Color(0xFFEFF6FF)
                            : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(999),
                        child: InkWell(
                          onTap: state.isSyncing
                              ? null
                              : () => SyncFeedbackHandler.performSync(
                                    context: context,
                                    syncManager: syncManager,
                                  ),
                          borderRadius: BorderRadius.circular(999),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 7,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (state.isSyncing)
                                  const SizedBox(
                                    width: 13,
                                    height: 13,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                else
                                  Icon(
                                    Icons.sync_rounded,
                                    size: 16,
                                    color: hasPending
                                        ? AppTheme.primary
                                        : AppTheme.textSecondary,
                                  ),
                                const SizedBox(width: 6),
                                Text(
                                  state.isSyncing
                                      ? 'Syncing...'
                                      : (hasPending
                                          ? 'Sync (${state.pendingCount})'
                                          : 'Sync Now'),
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: hasPending
                                        ? AppTheme.primary
                                        : AppTheme.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
      body: isDashboardTab
          ? SafeArea(
              bottom: false,
              child: navigationShell,
            )
          : Column(
              children: [
                SyncStatusBanner(syncManager: syncManager),
                Expanded(child: navigationShell),
              ],
            ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppTheme.surface,
          border: Border(
            top: BorderSide(color: AppTheme.border, width: 1),
          ),
        ),
        child: NavigationBar(
          selectedIndex: currentIndex,
          height: 66,
          onDestinationSelected: (index) {
            navigationShell.goBranch(
              index,
              initialLocation: index == currentIndex,
            );
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.space_dashboard_outlined),
              selectedIcon: Icon(Icons.space_dashboard_rounded),
              label: 'Dashboard',
            ),
            NavigationDestination(
              icon: Icon(Icons.schedule_outlined),
              selectedIcon: Icon(Icons.schedule_rounded),
              label: 'Attendance',
            ),
            NavigationDestination(
              icon: Icon(Icons.event_note_outlined),
              selectedIcon: Icon(Icons.event_note_rounded),
              label: 'Leave',
            ),
          ],
        ),
      ),
    );
  }
}
