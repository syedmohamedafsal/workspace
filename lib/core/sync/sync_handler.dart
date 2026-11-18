import '../error/exceptions.dart';
import 'sync_operation.dart';

/// Module-specific synchronization handler registered with [SyncManager].
///
/// Each REBS module (HRMS Attendance, HRMS Leave, CRM, Accounts) implements this
/// interface to push queued outbox mutations to its remote API and reconcile
/// local state on success, conflict, or permanent failure.
abstract interface class SyncHandler {
  /// Matches [SyncOperation.entityType], e.g. `hrms.attendance`.
  String get entityType;

  /// Sends [operation] to the backend and updates the local record as synced.
  Future<void> handleOperation(SyncOperation operation);

  /// Reconciles local record state when the server responds with 409 Conflict.
  Future<void> onConflict(SyncOperation operation, ConflictException exception);

  /// Updates local record state when an operation permanently fails.
  Future<void> onPermanentFailure(SyncOperation operation, String errorMessage);
}
