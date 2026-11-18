import 'package:flutter/material.dart';

import '../sync/sync_manager.dart';
import '../sync/sync_status.dart';

/// Understated top status bar showing offline state, pending sync count,
/// or actionable sync retry.
class SyncStatusBanner extends StatelessWidget {
  const SyncStatusBanner({
    super.key,
    required this.syncManager,
  });

  final SyncManager syncManager;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<SyncSnapshot>(
      stream: syncManager.statusStream,
      initialData: syncManager.currentSnapshot,
      builder: (context, snapshot) {
        final state = snapshot.data ?? const SyncSnapshot();

        if (state.isOnline && !state.isSyncing && state.totalUnsynced == 0) {
          return const SizedBox.shrink();
        }

        final (bgColor, borderColor, fgColor, icon, message, actionLabel, onAction) =
            _resolveBannerStyle(state);

        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: bgColor,
            border: Border(
              bottom: BorderSide(color: borderColor, width: 1),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              if (state.isSyncing)
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: fgColor,
                  ),
                )
              else
                Icon(icon, size: 16, color: fgColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: fgColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (actionLabel != null && onAction != null)
                TextButton(
                  onPressed: onAction,
                  style: TextButton.styleFrom(
                    foregroundColor: fgColor,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, 28),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    textStyle: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  child: Text(actionLabel),
                ),
            ],
          ),
        );
      },
    );
  }

  (Color, Color, Color, IconData, String, String?, VoidCallback?)
      _resolveBannerStyle(SyncSnapshot state) {
    if (!state.isOnline) {
      final suffix = state.totalUnsynced > 0
          ? ' • ${state.totalUnsynced} pending sync'
          : ' • Showing cached data';
      return (
        const Color(0xFFFFFBEB),
        const Color(0xFFFDE68A),
        const Color(0xFF92400E),
        Icons.wifi_off_rounded,
        'Offline$suffix',
        null,
        null,
      );
    }

    if (state.isSyncing) {
      return (
        const Color(0xFFEFF6FF),
        const Color(0xFFBFDBFE),
        const Color(0xFF1E40AF),
        Icons.sync_rounded,
        'Syncing ${state.pendingCount} pending event(s)...',
        null,
        null,
      );
    }

    if (state.hasIssues) {
      final issueCount = state.failedCount + state.conflictCount;
      return (
        const Color(0xFFFEF2F2),
        const Color(0xFFFECACA),
        const Color(0xFF991B1B),
        Icons.error_outline_rounded,
        '$issueCount event(s) rejected or failed to sync',
        'Retry',
        () => syncManager.retryFailed(),
      );
    }

    return (
      const Color(0xFFF8FAFC),
      const Color(0xFFE2E8F0),
      const Color(0xFF334155),
      Icons.cloud_upload_outlined,
      '${state.pendingCount} event(s) waiting to sync',
      'Sync Now',
      () => syncManager.syncNow(forceDue: true),
    );
  }
}
