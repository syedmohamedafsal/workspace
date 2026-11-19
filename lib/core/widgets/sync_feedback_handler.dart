import 'package:flutter/material.dart';

import '../sync/sync_manager.dart';

/// Handles manual sync invocation with loading feedback and floating SnackBars
/// for success and failure conditions.
abstract final class SyncFeedbackHandler {
  static Future<void> performSync({
    required BuildContext context,
    required SyncManager syncManager,
    bool retryFailed = false,
  }) async {
    // If sync is already running, prevent duplicate concurrent triggers
    if (syncManager.currentSnapshot.isSyncing) return;

    final messenger = ScaffoldMessenger.of(context);

    // If offline before initiating sync
    if (!syncManager.currentSnapshot.isOnline) {
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          backgroundColor: const Color(0xFFDC2626),
          content: const Row(
            children: [
              Icon(Icons.wifi_off_rounded, color: Colors.white, size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Cannot sync: Device is offline. Please check your connection.',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
      return;
    }

    try {
      // Ensure the loading state is visible for at least 400ms for smooth UX
      final shouldRetryFailed =
          retryFailed || syncManager.currentSnapshot.failedCount > 0;
      final syncFuture = shouldRetryFailed
          ? syncManager.retryFailed()
          : syncManager.syncNow(forceDue: true);

      await Future.wait([
        syncFuture,
        Future<void>.delayed(const Duration(milliseconds: 400)),
      ]);

      if (!context.mounted) return;

      final snapshot = syncManager.currentSnapshot;
      messenger.hideCurrentSnackBar();

      if (!snapshot.isOnline) {
        messenger.showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            backgroundColor: const Color(0xFFDC2626),
            content: const Row(
              children: [
                Icon(Icons.wifi_off_rounded, color: Colors.white, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Sync failed: Device went offline during sync.',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      } else if (snapshot.lastError != null || snapshot.hasIssues) {
        final errorMsg = snapshot.lastError ??
            '${snapshot.failedCount + snapshot.conflictCount} event(s) failed or conflicted.';
        messenger.showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            backgroundColor: const Color(0xFFDC2626),
            content: Row(
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Sync failed: $errorMsg',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      } else {
        // Success floating SnackBar
        messenger.showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            backgroundColor: const Color(0xFF059669), // Crisp emerald green
            content: const Row(
              children: [
                Icon(
                  Icons.check_circle_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'All attendance and leave records synced successfully!',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          backgroundColor: const Color(0xFFDC2626),
          content: Row(
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Sync failed: ${e.toString()}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
  }
}
