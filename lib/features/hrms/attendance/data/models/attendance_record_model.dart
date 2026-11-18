import '../../../../../core/sync/sync_status.dart';
import '../../domain/entities/attendance_record.dart';

/// Data model for SQLite persistence and REST JSON serialization.
class AttendanceRecordModel extends AttendanceRecord {
  const AttendanceRecordModel({
    required super.localId,
    required super.employeeId,
    required super.date,
    required super.status,
    required super.syncStatus,
    required super.createdAt,
    required super.updatedAt,
    super.serverId,
    super.checkInAt,
    super.checkOutAt,
    super.checkInNote,
    super.checkOutNote,
    super.workLocation,
    super.syncError,
  });

  factory AttendanceRecordModel.fromEntity(AttendanceRecord entity) {
    return AttendanceRecordModel(
      localId: entity.localId,
      serverId: entity.serverId,
      employeeId: entity.employeeId,
      date: entity.date,
      checkInAt: entity.checkInAt,
      checkOutAt: entity.checkOutAt,
      checkInNote: entity.checkInNote,
      checkOutNote: entity.checkOutNote,
      workLocation: entity.workLocation,
      status: entity.status,
      syncStatus: entity.syncStatus,
      syncError: entity.syncError,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
    );
  }

  factory AttendanceRecordModel.fromDbMap(Map<String, dynamic> map) {
    return AttendanceRecordModel(
      localId: map['local_id'] as String,
      serverId: map['server_id'] as String?,
      employeeId: map['employee_id'] as String,
      date: DateTime.parse(map['attendance_date'] as String),
      checkInAt: map['check_in_at'] != null
          ? DateTime.parse(map['check_in_at'] as String)
          : null,
      checkOutAt: map['check_out_at'] != null
          ? DateTime.parse(map['check_out_at'] as String)
          : null,
      checkInNote: map['check_in_note'] as String?,
      checkOutNote: map['check_out_note'] as String?,
      workLocation: map['work_location'] as String?,
      status: AttendanceStatus.fromString(map['status'] as String),
      syncStatus: RecordSyncStatus.fromString(map['sync_status'] as String),
      syncError: map['sync_error'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  factory AttendanceRecordModel.fromApiJson(Map<String, dynamic> json) {
    final now = DateTime.now();
    final serverId = json['id']?.toString();
    return AttendanceRecordModel(
      localId: (json['client_id'] as String?) ?? serverId ?? '',
      serverId: serverId,
      employeeId: json['employee_id'] as String? ?? '',
      date: DateTime.parse(json['date'] as String),
      checkInAt: json['check_in_at'] != null
          ? DateTime.parse(json['check_in_at'] as String)
          : null,
      checkOutAt: json['check_out_at'] != null
          ? DateTime.parse(json['check_out_at'] as String)
          : null,
      checkInNote: json['check_in_note'] as String?,
      checkOutNote: json['check_out_note'] as String?,
      workLocation: json['work_location'] as String?,
      status: AttendanceStatus.fromString(
        (json['status'] as String?) ?? AttendanceStatus.checkedIn.name,
      ),
      syncStatus: RecordSyncStatus.synced,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : now,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : now,
    );
  }

  Map<String, dynamic> toDbMap() {
    return {
      'local_id': localId,
      'server_id': serverId,
      'employee_id': employeeId,
      'attendance_date': formatDateKey(date),
      'check_in_at': checkInAt?.toIso8601String(),
      'check_out_at': checkOutAt?.toIso8601String(),
      'check_in_note': checkInNote,
      'check_out_note': checkOutNote,
      'work_location': workLocation,
      'status': status.name,
      'sync_status': syncStatus.name,
      'sync_error': syncError,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  Map<String, dynamic> toCheckInPayload() {
    return {
      'client_id': localId,
      'employee_id': employeeId,
      'date': formatDateKey(date),
      'check_in_at': checkInAt?.toIso8601String(),
      'work_location': workLocation,
      'note': checkInNote,
    };
  }

  Map<String, dynamic> toCheckOutPayload() {
    return {
      'client_id': localId,
      'server_id': serverId,
      'employee_id': employeeId,
      'date': formatDateKey(date),
      'check_out_at': checkOutAt?.toIso8601String(),
      'note': checkOutNote,
    };
  }

  static String formatDateKey(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}
