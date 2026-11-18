import 'package:flutter/material.dart';

import '../sync/sync_manager.dart';
import '../sync/sync_status.dart';

/// Global banner showing offline status, queued mutations, and manual retry.
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

        if (state.isOnline &&
            !state.isSyncing &&
            state.totalUnsynced == 0) {
          return const SizedBox.shrink();
        }

        final (bgColor, fgColor, icon, message, actionLabel, onAction) =
            _resolveBannerStyle(context, state);

        return Material(
          color: bgColor,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                if (state.isSyncing)
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: fgColor,
                    ),
                  )
                else
                  Icon(icon, size: 18, color: fgColor),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    message,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: fgColor,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
                if (actionLabel != null && onAction != null)
                  TextButton(
                    onPressed: onAction,
                    style: TextButton.styleFrom(
                      foregroundColor: fgColor,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: const Size(0, 32),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(actionLabel),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  (Color, Color, IconData, String, String?, VoidCallback?) _resolveBannerStyle(
    BuildContext context,
    SyncSnapshot state,
  ) {
    final scheme = Theme.of(context).colorScheme;

    if (!state.isOnline) {
      final suffix = state.totalUnsynced > 0
          ? ' • ${state.totalUnsynced} change(s) queued'
          : ' • Working in offline mode';
      return (
        const Color(0xFFFEF3C7),
        const Color(0xFF92400E),
        Icons.cloud_off_rounded,
        'Offline$suffix',
        null,
        null,
      );
    }

    if (state.isSyncing) {
      return (
        scheme.primaryContainer,
        scheme.onPrimaryContainer,
        Icons.sync_rounded,
        'Syncing ${state.pendingCount} pending change(s)...',
        null,
        null,
      );
    }

    if (state.hasIssues) {
      final issueCount = state.failedCount + state.conflictCount;
      return (
        scheme.errorContainer,
        scheme.onErrorContainer,
        Icons.sync_problem_rounded,
        '$issueCount change(s) need attention',
        'Retry',
        () => syncManager.retryFailed(),
      );
    }

    return (
      scheme.secondaryContainer,
      scheme.onSecondaryContainer,
      Icons.cloud_upload_outlined,
      '${state.pendingCount} change(s) waiting to sync',
      'Sync now',
      () => syncManager.syncNow(forceDue: true),
    );
  }
}
