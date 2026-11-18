import 'package:equatable/equatable.dart';

/// Sync lifecycle state stored on every offline-capable domain record.
enum RecordSyncStatus {
  synced,
  pending,
  syncing,
  conflict,
  failed;

  static RecordSyncStatus fromString(String value) {
    return RecordSyncStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => RecordSyncStatus.pending,
    );
  }
}

/// Lifecycle state for an individual outbox item in `sync_queue`.
enum SyncQueueStatus {
  pending,
  processing,
  failed,
  conflict;

  static SyncQueueStatus fromString(String value) {
    return SyncQueueStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => SyncQueueStatus.pending,
    );
  }
}

/// Snapshot broadcast by [SyncManager] to inform the UI about sync health.
class SyncSnapshot extends Equatable {
  const SyncSnapshot({
    this.isOnline = true,
    this.isSyncing = false,
    this.pendingCount = 0,
    this.failedCount = 0,
    this.conflictCount = 0,
    this.lastSyncedAt,
    this.lastError,
  });

  final bool isOnline;
  final bool isSyncing;
  final int pendingCount;
  final int failedCount;
  final int conflictCount;
  final DateTime? lastSyncedAt;
  final String? lastError;

  int get totalUnsynced => pendingCount + failedCount + conflictCount;
  bool get hasPendingWork => pendingCount > 0;
  bool get hasIssues => failedCount > 0 || conflictCount > 0;

  SyncSnapshot copyWith({
    bool? isOnline,
    bool? isSyncing,
    int? pendingCount,
    int? failedCount,
    int? conflictCount,
    DateTime? lastSyncedAt,
    String? lastError,
    bool clearLastError = false,
  }) {
    return SyncSnapshot(
      isOnline: isOnline ?? this.isOnline,
      isSyncing: isSyncing ?? this.isSyncing,
      pendingCount: pendingCount ?? this.pendingCount,
      failedCount: failedCount ?? this.failedCount,
      conflictCount: conflictCount ?? this.conflictCount,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      lastError: clearLastError ? null : (lastError ?? this.lastError),
    );
  }

  @override
  List<Object?> get props => [
        isOnline,
        isSyncing,
        pendingCount,
        failedCount,
        conflictCount,
        lastSyncedAt,
        lastError,
      ];
}
