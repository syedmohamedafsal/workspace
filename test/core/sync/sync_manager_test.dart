import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:rebs/core/config/app_config.dart';
import 'package:rebs/core/database/app_database.dart';
import 'package:rebs/core/error/exceptions.dart';
import 'package:rebs/core/network/network_info.dart';
import 'package:rebs/core/sync/sync_handler.dart';
import 'package:rebs/core/sync/sync_manager.dart';
import 'package:rebs/core/sync/sync_operation.dart';
import 'package:rebs/core/sync/sync_queue_datasource.dart';
import 'package:rebs/core/sync/sync_status.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class FakeNetworkInfo implements NetworkInfo {
  FakeNetworkInfo({bool initiallyConnected = false})
      : _connected = initiallyConnected;

  bool _connected;
  final _controller = StreamController<bool>.broadcast();

  @override
  Future<bool> get isConnected async => _connected;

  @override
  Stream<bool> get onStatusChange => _controller.stream;

  void setConnected(bool value) {
    _connected = value;
    _controller.add(value);
  }

  Future<void> dispose() => _controller.close();
}

class RecordingSyncHandler implements SyncHandler {
  RecordingSyncHandler({
    this.entityType = 'test.entity',
    this.onHandle,
  });

  @override
  final String entityType;

  final Future<void> Function(SyncOperation op)? onHandle;
  final List<String> handledIds = [];
  final List<String> conflictedIds = [];
  final List<String> failedIds = [];

  @override
  Future<void> handleOperation(SyncOperation operation) async {
    if (onHandle != null) {
      await onHandle!(operation);
    }
    handledIds.add(operation.id);
  }

  @override
  Future<void> onConflict(
    SyncOperation operation,
    ConflictException exception,
  ) async {
    conflictedIds.add(operation.id);
  }

  @override
  Future<void> onPermanentFailure(
    SyncOperation operation,
    String errorMessage,
  ) async {
    failedIds.add(operation.id);
  }
}

void main() {
  sqfliteFfiInit();

  late AppDatabase appDatabase;
  late SyncQueueDataSource queueDataSource;
  late FakeNetworkInfo networkInfo;
  late SyncManager syncManager;
  late DateTime now;

  setUp(() async {
    now = DateTime(2026, 11, 18, 9, 0);
    appDatabase = AppDatabase(
      databaseFactoryOverride: databaseFactoryFfi,
      pathOverride: inMemoryDatabasePath,
    );
    queueDataSource = SyncQueueDataSource(appDatabase);
    networkInfo = FakeNetworkInfo(initiallyConnected: false);
    syncManager = SyncManager(
      queueDataSource: queueDataSource,
      networkInfo: networkInfo,
      config: const AppConfig(
        maxSyncRetries: 2,
        baseRetryDelay: Duration(seconds: 5),
      ),
      clock: () => now,
    );
  });

  tearDown(() async {
    await syncManager.dispose();
    await networkInfo.dispose();
    await appDatabase.close();
  });

  SyncOperation makeOp(String id, {int offsetSeconds = 0}) {
    final ts = now.add(Duration(seconds: offsetSeconds));
    return SyncOperation(
      id: id,
      entityType: 'test.entity',
      entityId: 'rec-$id',
      operationType: 'create',
      payload: {'id': id},
      idempotencyKey: 'idem-$id',
      status: SyncQueueStatus.pending,
      retryCount: 0,
      createdAt: ts,
      updatedAt: ts,
    );
  }

  test('stays queued offline and syncs FIFO when connectivity returns',
      () async {
    final handler = RecordingSyncHandler();
    syncManager.registerHandler(handler);
    await syncManager.initialize();

    await queueDataSource.enqueue(makeOp('op-1', offsetSeconds: 1));
    await queueDataSource.enqueue(makeOp('op-2', offsetSeconds: 2));
    await syncManager.notifyQueueChanged();

    expect(handler.handledIds, isEmpty);
    expect(syncManager.currentSnapshot.isOnline, isFalse);
    expect(syncManager.currentSnapshot.pendingCount, 2);

    // Reconnect and wait for sync loop
    final syncedFuture = syncManager.statusStream.firstWhere(
      (s) => s.isOnline && !s.isSyncing && s.pendingCount == 0,
    );
    networkInfo.setConnected(true);
    await syncedFuture;

    expect(handler.handledIds, ['op-1', 'op-2']);
    expect(syncManager.currentSnapshot.totalUnsynced, 0);
  });

  test('isolates 409 conflicts without blocking subsequent operations',
      () async {
    final handler = RecordingSyncHandler(
      onHandle: (op) async {
        if (op.id == 'op-1') {
          throw const ConflictException('Already exists on server');
        }
      },
    );
    syncManager.registerHandler(handler);
    networkInfo.setConnected(true);
    await syncManager.initialize();

    await queueDataSource.enqueue(makeOp('op-1', offsetSeconds: 1));
    await queueDataSource.enqueue(makeOp('op-2', offsetSeconds: 2));
    await syncManager.syncNow();

    expect(handler.conflictedIds, ['op-1']);
    expect(handler.handledIds, ['op-2']);
    expect(syncManager.currentSnapshot.conflictCount, 1);
    expect(syncManager.currentSnapshot.pendingCount, 0);
  });

  test('retries transient server errors with backoff and fails after max',
      () async {
    final handler = RecordingSyncHandler(
      onHandle: (_) async =>
          throw const ServerException('Service unavailable', statusCode: 503),
    );
    syncManager.registerHandler(handler);
    networkInfo.setConnected(true);
    await syncManager.initialize();

    await queueDataSource.enqueue(makeOp('op-1'));

    // First attempt schedules retry #1
    await syncManager.syncNow();
    expect(syncManager.currentSnapshot.pendingCount, 1);
    expect(syncManager.currentSnapshot.failedCount, 0);

    // Advance clock past backoff window and run attempt #2 -> hits maxSyncRetries (2)
    now = now.add(const Duration(seconds: 10));
    await syncManager.syncNow();

    expect(handler.failedIds, ['op-1']);
    expect(syncManager.currentSnapshot.failedCount, 1);
    expect(syncManager.currentSnapshot.pendingCount, 0);
  });
}
