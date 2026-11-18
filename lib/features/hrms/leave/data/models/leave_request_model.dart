import '../../../../../core/sync/sync_status.dart';
import '../../domain/entities/leave_request.dart';

class LeaveRequestModel extends LeaveRequest {
  const LeaveRequestModel({
    required super.localId,
    required super.employeeId,
    required super.leaveType,
    required super.startDate,
    required super.endDate,
    required super.isHalfDay,
    required super.reason,
    required super.approvalStatus,
    required super.syncStatus,
    required super.createdAt,
    required super.updatedAt,
    super.serverId,
    super.approverComment,
    super.syncError,
  });

  factory LeaveRequestModel.fromEntity(LeaveRequest entity) {
    return LeaveRequestModel(
      localId: entity.localId,
      serverId: entity.serverId,
      employeeId: entity.employeeId,
      leaveType: entity.leaveType,
      startDate: entity.startDate,
      endDate: entity.endDate,
      isHalfDay: entity.isHalfDay,
      reason: entity.reason,
      approvalStatus: entity.approvalStatus,
      approverComment: entity.approverComment,
      syncStatus: entity.syncStatus,
      syncError: entity.syncError,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
    );
  }

  factory LeaveRequestModel.fromDbMap(Map<String, dynamic> map) {
    return LeaveRequestModel(
      localId: map['local_id'] as String,
      serverId: map['server_id'] as String?,
      employeeId: map['employee_id'] as String,
      leaveType: LeaveType.fromString(map['leave_type'] as String),
      startDate: DateTime.parse(map['start_date'] as String),
      endDate: DateTime.parse(map['end_date'] as String),
      isHalfDay: (map['is_half_day'] as int) == 1,
      reason: map['reason'] as String,
      approvalStatus:
          LeaveApprovalStatus.fromString(map['approval_status'] as String),
      approverComment: map['approver_comment'] as String?,
      syncStatus: RecordSyncStatus.fromString(map['sync_status'] as String),
      syncError: map['sync_error'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  factory LeaveRequestModel.fromApiJson(Map<String, dynamic> json) {
    final now = DateTime.now();
    final serverId = json['id']?.toString();
    return LeaveRequestModel(
      localId: (json['client_id'] as String?) ?? serverId ?? '',
      serverId: serverId,
      employeeId: json['employee_id'] as String? ?? '',
      leaveType: LeaveType.fromString(json['leave_type'] as String? ?? 'annual'),
      startDate: DateTime.parse(json['start_date'] as String),
      endDate: DateTime.parse(json['end_date'] as String),
      isHalfDay: json['is_half_day'] as bool? ?? false,
      reason: json['reason'] as String? ?? '',
      approvalStatus: LeaveApprovalStatus.fromString(
        json['status'] as String? ?? LeaveApprovalStatus.pending.name,
      ),
      approverComment: json['approver_comment'] as String?,
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
      'leave_type': leaveType.name,
      'start_date': _formatDate(startDate),
      'end_date': _formatDate(endDate),
      'is_half_day': isHalfDay ? 1 : 0,
      'reason': reason,
      'approval_status': approvalStatus.name,
      'approver_comment': approverComment,
      'sync_status': syncStatus.name,
      'sync_error': syncError,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  Map<String, dynamic> toApiPayload() {
    return {
      'client_id': localId,
      'employee_id': employeeId,
      'leave_type': leaveType.name,
      'start_date': _formatDate(startDate),
      'end_date': _formatDate(endDate),
      'is_half_day': isHalfDay,
      'reason': reason,
    };
  }

  static String _formatDate(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}
