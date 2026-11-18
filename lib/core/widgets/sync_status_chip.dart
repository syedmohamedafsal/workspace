import 'package:flutter/material.dart';

import '../sync/sync_status.dart';

/// Compact indicator badge showing an individual record's sync state
/// (Pending Sync, Synced, Syncing, Rejected).
class SyncStatusChip extends StatelessWidget {
  const SyncStatusChip({
    super.key,
    required this.status,
  });

  final RecordSyncStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, dotColor, bg, fg) = switch (status) {
      RecordSyncStatus.synced => (
          'Synced',
          const Color(0xFF16A34A),
          const Color(0xFFF0FDF4),
          const Color(0xFF166534),
        ),
      RecordSyncStatus.pending => (
          'Pending Sync',
          const Color(0xFFD97706),
          const Color(0xFFFFFBEB),
          const Color(0xFF92400E),
        ),
      RecordSyncStatus.syncing => (
          'Syncing',
          const Color(0xFF2563EB),
          const Color(0xFFEFF6FF),
          const Color(0xFF1E40AF),
        ),
      RecordSyncStatus.conflict || RecordSyncStatus.failed => (
          'Rejected',
          const Color(0xFFDC2626),
          const Color(0xFFFEF2F2),
          const Color(0xFF991B1B),
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: dotColor.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: fg,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
