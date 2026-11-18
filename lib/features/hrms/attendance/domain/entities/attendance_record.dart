import 'package:equatable/equatable.dart';

import '../../../../../core/sync/sync_status.dart';

enum AttendanceStatus {
  checkedIn,
  checkedOut,
  absent,
  onLeave;

  static AttendanceStatus fromString(String value) {
    return AttendanceStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => AttendanceStatus.checkedIn,
    );
  }
}

/// Core domain entity representing a single day's employee attendance log.
class AttendanceRecord extends Equatable {
  const AttendanceRecord({
    required this.localId,
    required this.employeeId,
    required this.date,
    required this.status,
    required this.syncStatus,
    required this.createdAt,
    required this.updatedAt,
    this.serverId,
    this.checkInAt,
    this.checkOutAt,
    this.checkInNote,
    this.checkOutNote,
    this.workLocation,
    this.syncError,
  });

  final String localId;
  final String? serverId;
  final String employeeId;

  /// Calendar date normalized to `YYYY-MM-DD` (midnight local time).
  final DateTime date;
  final DateTime? checkInAt;
  final DateTime? checkOutAt;
  final String? checkInNote;
  final String? checkOutNote;
  final String? workLocation;
  final AttendanceStatus status;
  final RecordSyncStatus syncStatus;
  final String? syncError;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isCheckedIn => checkInAt != null && checkOutAt == null;
  bool get isCompleted => checkInAt != null && checkOutAt != null;
  bool get needsSync => syncStatus != RecordSyncStatus.synced;

  Duration? get workedDuration {
    if (checkInAt == null) return null;
    final end = checkOutAt ?? DateTime.now();
    if (end.isBefore(checkInAt!)) return Duration.zero;
    return end.difference(checkInAt!);
  }

  AttendanceRecord copyWith({
    String? localId,
    String? serverId,
    String? employeeId,
    DateTime? date,
    DateTime? checkInAt,
    DateTime? checkOutAt,
    String? checkInNote,
    String? checkOutNote,
    String? workLocation,
    AttendanceStatus? status,
    RecordSyncStatus? syncStatus,
    String? syncError,
    bool clearSyncError = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AttendanceRecord(
      localId: localId ?? this.localId,
      serverId: serverId ?? this.serverId,
      employeeId: employeeId ?? this.employeeId,
      date: date ?? this.date,
      checkInAt: checkInAt ?? this.checkInAt,
      checkOutAt: checkOutAt ?? this.checkOutAt,
      checkInNote: checkInNote ?? this.checkInNote,
      checkOutNote: checkOutNote ?? this.checkOutNote,
      workLocation: workLocation ?? this.workLocation,
      status: status ?? this.status,
      syncStatus: syncStatus ?? this.syncStatus,
      syncError: clearSyncError ? null : (syncError ?? this.syncError),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        localId,
        serverId,
        employeeId,
        date,
        checkInAt,
        checkOutAt,
        checkInNote,
        checkOutNote,
        workLocation,
        status,
        syncStatus,
        syncError,
        createdAt,
        updatedAt,
      ];
}
