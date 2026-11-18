import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../sync/sync_manager.dart';
import 'sync_status_banner.dart';

/// Persistent navigation shell for the REBS multi-module platform.
class AppShellScaffold extends StatelessWidget {
  const AppShellScaffold({
    super.key,
    required this.navigationShell,
    required this.syncManager,
  });

  final StatefulNavigationShell navigationShell;
  final SyncManager syncManager;

  static const _titles = [
    'REBS • Attendance',
    'REBS • Leave',
    'REBS • CRM',
    'REBS • Accounts',
  ];

  @override
  Widget build(BuildContext context) {
    final currentIndex = navigationShell.currentIndex;

    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[currentIndex]),
        actions: [
          IconButton(
            tooltip: 'Sync now',
            icon: const Icon(Icons.sync_rounded),
            onPressed: () => syncManager.syncNow(forceDue: true),
          ),
        ],
      ),
      body: Column(
        children: [
          SyncStatusBanner(syncManager: syncManager),
          Expanded(child: navigationShell),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: (index) {
          navigationShell.goBranch(
            index,
            initialLocation: index == currentIndex,
          );
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.fingerprint_outlined),
            selectedIcon: Icon(Icons.fingerprint_rounded),
            label: 'Attendance',
          ),
          NavigationDestination(
            icon: Icon(Icons.event_available_outlined),
            selectedIcon: Icon(Icons.event_available_rounded),
            label: 'Leave',
          ),
          NavigationDestination(
            icon: Icon(Icons.handshake_outlined),
            selectedIcon: Icon(Icons.handshake_rounded),
            label: 'CRM',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(Icons.account_balance_wallet_rounded),
            label: 'Accounts',
          ),
        ],
      ),
    );
  }
}
