import 'package:flutter/material.dart';

import '../sync/sync_status.dart';

/// Compact indicator badge showing an individual record's offline sync state.
class SyncStatusChip extends StatelessWidget {
  const SyncStatusChip({
    super.key,
    required this.status,
  });

  final RecordSyncStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, icon, bg, fg) = switch (status) {
      RecordSyncStatus.synced => (
          'Synced',
          Icons.cloud_done_outlined,
          const Color(0xFFDCFCE7),
          const Color(0xFF166534),
        ),
      RecordSyncStatus.pending => (
          'Queued',
          Icons.schedule_rounded,
          const Color(0xFFFEF3C7),
          const Color(0xFF92400E),
        ),
      RecordSyncStatus.syncing => (
          'Syncing',
          Icons.sync_rounded,
          const Color(0xFFDBEAFE),
          const Color(0xFF1E40AF),
        ),
      RecordSyncStatus.conflict => (
          'Conflict',
          Icons.warning_amber_rounded,
          const Color(0xFFFEE2E2),
          const Color(0xFF991B1B),
        ),
      RecordSyncStatus.failed => (
          'Sync Failed',
          Icons.error_outline_rounded,
          const Color(0xFFFEE2E2),
          const Color(0xFF991B1B),
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: fg),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: fg,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}
