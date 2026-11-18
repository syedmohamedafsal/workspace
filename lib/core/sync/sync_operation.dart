import 'dart:convert';

import 'package:equatable/equatable.dart';

import 'sync_status.dart';

/// Represents a durable outbox mutation queued for eventual server delivery.
class SyncOperation extends Equatable {
  const SyncOperation({
    required this.id,
    required this.entityType,
    required this.entityId,
    required this.operationType,
    required this.payload,
    required this.idempotencyKey,
    required this.status,
    required this.retryCount,
    required this.createdAt,
    required this.updatedAt,
    this.nextRetryAt,
    this.lastError,
  });

  final String id;

  /// Module + aggregate key, e.g. `hrms.attendance` or `hrms.leave`.
  final String entityType;

  /// Local record identifier associated with this mutation.
  final String entityId;

  /// Action identifier, e.g. `check_in`, `check_out`, `apply_leave`, `cancel_leave`.
  final String operationType;

  /// JSON-serializable mutation payload.
  final Map<String, dynamic> payload;

  /// Unique key sent via `X-Idempotency-Key` so retries never duplicate writes.
  final String idempotencyKey;

  final SyncQueueStatus status;
  final int retryCount;
  final DateTime? nextRetryAt;
  final String? lastError;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, dynamic> toDbMap() {
    return {
      'id': id,
      'entity_type': entityType,
      'entity_id': entityId,
      'operation_type': operationType,
      'payload': jsonEncode(payload),
      'idempotency_key': idempotencyKey,
      'status': status.name,
      'retry_count': retryCount,
      'next_retry_at': nextRetryAt?.toIso8601String(),
      'last_error': lastError,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory SyncOperation.fromDbMap(Map<String, dynamic> map) {
    final decoded = jsonDecode(map['payload'] as String);
    return SyncOperation(
      id: map['id'] as String,
      entityType: map['entity_type'] as String,
      entityId: map['entity_id'] as String,
      operationType: map['operation_type'] as String,
      payload: decoded is Map<String, dynamic> ? decoded : const {},
      idempotencyKey: map['idempotency_key'] as String,
      status: SyncQueueStatus.fromString(map['status'] as String),
      retryCount: map['retry_count'] as int,
      nextRetryAt: map['next_retry_at'] != null
          ? DateTime.parse(map['next_retry_at'] as String)
          : null,
      lastError: map['last_error'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  @override
  List<Object?> get props => [
        id,
        entityType,
        entityId,
        operationType,
        payload,
        idempotencyKey,
        status,
        retryCount,
        nextRetryAt,
        lastError,
        createdAt,
        updatedAt,
      ];
}
