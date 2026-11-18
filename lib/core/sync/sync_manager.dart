import 'dart:async';
import 'dart:math' as math;

import '../config/app_config.dart';
import '../error/exceptions.dart';
import '../network/network_info.dart';
import 'sync_handler.dart';
import 'sync_operation.dart';
import 'sync_queue_datasource.dart';
import 'sync_status.dart';

/// Coordinates reliable offline-first synchronization across all REBS modules.
///
/// Key reliability guarantees:
/// - Durable SQLite outbox queue survives app restarts and crashes.
/// - Single-flight execution prevents duplicate concurrent sync loops.
/// - Automatic recovery when device connectivity returns.
/// - Exponential backoff for transient network/server errors.
/// - Conflict isolation so one conflicting record does not block the queue.
class SyncManager {
  SyncManager({
    required SyncQueueDataSource queueDataSource,
    required NetworkInfo networkInfo,
    required AppConfig config,
    DateTime Function()? clock,
  })  : _queueDataSource = queueDataSource,
        _networkInfo = networkInfo,
        _config = config,
        _clock = clock ?? DateTime.now;

  final SyncQueueDataSource _queueDataSource;
  final NetworkInfo _networkInfo;
  final AppConfig _config;
  final DateTime Function() _clock;

  final Map<String, SyncHandler> _handlers = {};
  final StreamController<SyncSnapshot> _statusController =
      StreamController<SyncSnapshot>.broadcast();

  StreamSubscription<bool>? _connectivitySubscription;
  Timer? _retryTimer;
  SyncSnapshot _currentSnapshot = const SyncSnapshot();
  Completer<void>? _activeSyncCompleter;
  bool _isSyncing = false;
  bool _resyncRequested = false;
  bool _resyncForceDue = false;
  bool _initialized = false;
  bool _disposed = false;

  SyncSnapshot get currentSnapshot => _currentSnapshot;
  Stream<SyncSnapshot> get statusStream => _statusController.stream;

  void registerHandler(SyncHandler handler) {
    _handlers[handler.entityType] = handler;
  }

  /// Starts connectivity monitoring, recovers interrupted queue items, and
  /// performs an initial sync check.
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    await _queueDataSource.recoverInterruptedOperations();
    final connected = await _networkInfo.isConnected;
    await _refreshSnapshot(isOnline: connected);

    _connectivitySubscription = _networkInfo.onStatusChange.listen((online) {
      _updateSnapshot(_currentSnapshot.copyWith(isOnline: online));
      if (online) {
        unawaited(syncNow());
      }
    });

    if (connected) {
      unawaited(syncNow());
    }
  }

  /// Notifies the manager that a new mutation was added to the outbox.
  Future<void> notifyQueueChanged() async {
    await _refreshSnapshot();
    if (_currentSnapshot.isOnline) {
      unawaited(syncNow());
    }
  }

  /// Retries all previously failed operations immediately.
  Future<void> retryFailed() async {
    await _queueDataSource.resetFailedToPending();
    await _refreshSnapshot(clearLastError: true);
    await syncNow(forceDue: true);
  }

  /// Drains due operations from the outbox sequentially in FIFO order.
  Future<void> syncNow({bool forceDue = false}) async {
    if (_disposed) return;

    if (_isSyncing) {
      _resyncRequested = true;
      if (forceDue) _resyncForceDue = true;
      await _activeSyncCompleter?.future;
      return;
    }

    final connected = await _networkInfo.isConnected;
    if (_disposed) return;
    if (!connected) {
      await _refreshSnapshot(isOnline: false, isSyncing: false);
      return;
    }

    _isSyncing = true;
    _activeSyncCompleter = Completer<void>();
    _retryTimer?.cancel();

    String? lastError;
    DateTime? earliestNextRetry;
    var processedAny = false;
    var currentForceDue = forceDue;

    try {
      await _refreshSnapshot(
        isOnline: true,
        isSyncing: true,
        clearLastError: true,
      );

      do {
        _resyncRequested = false;
        if (_disposed) break;

        final now = _clock();
        final operations = await _queueDataSource.getDueOperations(
          now: currentForceDue ? now.add(const Duration(days: 365)) : now,
        );
        currentForceDue = _resyncForceDue;
        _resyncForceDue = false;

        for (final operation in operations) {
          if (_disposed) break;
          if (!await _networkInfo.isConnected) {
            await _refreshSnapshot(isOnline: false);
            break;
          }

          final handler = _handlers[operation.entityType];
          if (handler == null) {
            final msg =
                'No sync handler registered for ${operation.entityType}.';
            await _queueDataSource.markFailed(
              operationId: operation.id,
              retryCount: operation.retryCount + 1,
              error: msg,
            );
            lastError = msg;
            continue;
          }

          await _queueDataSource.markProcessing(operation.id);

          try {
            await handler.handleOperation(operation);
            await _queueDataSource.markCompleted(operation.id);
            processedAny = true;
          } on ConflictException catch (e) {
            await handler.onConflict(operation, e);
            await _queueDataSource.markConflict(
              operationId: operation.id,
              error: e.message,
            );
            lastError = e.message;
          } on ValidationException catch (e) {
            await handler.onPermanentFailure(operation, e.message);
            await _queueDataSource.markFailed(
              operationId: operation.id,
              retryCount: operation.retryCount + 1,
              error: e.message,
            );
            lastError = e.message;
          } on NetworkException catch (e) {
            final nextRetry = await _handleRetryableFailure(
              operation: operation,
              handler: handler,
              error: e.message,
            );
            if (nextRetry != null) {
              earliestNextRetry = _minDate(earliestNextRetry, nextRetry);
            }
            lastError = e.message;
            // Stop draining further items during a connectivity outage to avoid
            // churning retries on the rest of the queue.
            break;
          } on ServerException catch (e) {
            if (e.isRetryable) {
              final nextRetry = await _handleRetryableFailure(
                operation: operation,
                handler: handler,
                error: e.message,
              );
              if (nextRetry != null) {
                earliestNextRetry = _minDate(earliestNextRetry, nextRetry);
              }
            } else {
              await handler.onPermanentFailure(operation, e.message);
              await _queueDataSource.markFailed(
                operationId: operation.id,
                retryCount: operation.retryCount + 1,
                error: e.message,
              );
            }
            lastError = e.message;
          } catch (e) {
            final errorMsg = e.toString();
            final nextRetry = await _handleRetryableFailure(
              operation: operation,
              handler: handler,
              error: errorMsg,
            );
            if (nextRetry != null) {
              earliestNextRetry = _minDate(earliestNextRetry, nextRetry);
            }
            lastError = errorMsg;
          }
        }
      } while (_resyncRequested && !_disposed);
    } finally {
      _isSyncing = false;
      if (!_disposed) {
        final online = await _networkInfo.isConnected;
        if (!_disposed) {
          await _refreshSnapshot(
            isOnline: online,
            isSyncing: false,
            lastSyncedAt:
                processedAny ? _clock() : _currentSnapshot.lastSyncedAt,
            lastError: lastError,
          );

          if (earliestNextRetry != null && online) {
            final delay = earliestNextRetry.difference(_clock());
            _retryTimer = Timer(
              delay.isNegative ? const Duration(seconds: 1) : delay,
              () => unawaited(syncNow()),
            );
          }
        }
      }

      final completer = _activeSyncCompleter;
      _activeSyncCompleter = null;
      if (completer != null && !completer.isCompleted) {
        completer.complete();
      }
    }
  }

  Future<DateTime?> _handleRetryableFailure({
    required SyncOperation operation,
    required SyncHandler handler,
    required String error,
  }) async {
    final nextRetryCount = operation.retryCount + 1;
    if (nextRetryCount >= _config.maxSyncRetries) {
      await handler.onPermanentFailure(operation, error);
      await _queueDataSource.markFailed(
        operationId: operation.id,
        retryCount: nextRetryCount,
        error: error,
      );
      return null;
    }

    final delay = _calculateBackoff(nextRetryCount);
    final nextRetryAt = _clock().add(delay);
    await _queueDataSource.scheduleRetry(
      operationId: operation.id,
      retryCount: nextRetryCount,
      nextRetryAt: nextRetryAt,
      error: error,
    );
    return nextRetryAt;
  }

  Duration _calculateBackoff(int retryCount) {
    final multiplier = math.pow(2, retryCount - 1).toInt();
    final rawMs = _config.baseRetryDelay.inMilliseconds * multiplier;
    final cappedMs = math.min(rawMs, _config.maxRetryDelay.inMilliseconds);
    return Duration(milliseconds: cappedMs);
  }

  DateTime _minDate(DateTime? current, DateTime candidate) {
    if (current == null || candidate.isBefore(current)) {
      return candidate;
    }
    return current;
  }

  Future<void> _refreshSnapshot({
    bool? isOnline,
    bool? isSyncing,
    DateTime? lastSyncedAt,
    String? lastError,
    bool clearLastError = false,
  }) async {
    final counts = await _queueDataSource.getCounts();
    _updateSnapshot(
      _currentSnapshot.copyWith(
        isOnline: isOnline,
        isSyncing: isSyncing,
        pendingCount: counts.pending,
        failedCount: counts.failed,
        conflictCount: counts.conflict,
        lastSyncedAt: lastSyncedAt,
        lastError: lastError,
        clearLastError: clearLastError,
      ),
    );
  }

  void _updateSnapshot(SyncSnapshot snapshot) {
    _currentSnapshot = snapshot;
    if (!_statusController.isClosed) {
      _statusController.add(snapshot);
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    _retryTimer?.cancel();
    await _connectivitySubscription?.cancel();
    await _activeSyncCompleter?.future;
    await _statusController.close();
  }
}
