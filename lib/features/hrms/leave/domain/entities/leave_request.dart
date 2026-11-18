import 'package:equatable/equatable.dart';

import '../../../../../core/sync/sync_status.dart';

enum LeaveType {
  annual('Annual Leave'),
  sick('Sick Leave'),
  casual('Casual Leave'),
  unpaid('Unpaid Leave');

  const LeaveType(this.label);

  final String label;

  static LeaveType fromString(String value) {
    return LeaveType.values.firstWhere(
      (type) => type.name == value,
      orElse: () => LeaveType.annual,
    );
  }
}

enum LeaveApprovalStatus {
  pending('Pending'),
  approved('Approved'),
  rejected('Rejected'),
  cancelled('Cancelled');

  const LeaveApprovalStatus(this.label);

  final String label;

  static LeaveApprovalStatus fromString(String value) {
    return LeaveApprovalStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => LeaveApprovalStatus.pending,
    );
  }
}

/// Core domain entity representing an employee leave application.
class LeaveRequest extends Equatable {
  const LeaveRequest({
    required this.localId,
    required this.employeeId,
    required this.leaveType,
    required this.startDate,
    required this.endDate,
    required this.isHalfDay,
    required this.reason,
    required this.approvalStatus,
    required this.syncStatus,
    required this.createdAt,
    required this.updatedAt,
    this.serverId,
    this.approverComment,
    this.syncError,
  });

  final String localId;
  final String? serverId;
  final String employeeId;
  final LeaveType leaveType;
  final DateTime startDate;
  final DateTime endDate;
  final bool isHalfDay;
  final String reason;
  final LeaveApprovalStatus approvalStatus;
  final String? approverComment;
  final RecordSyncStatus syncStatus;
  final String? syncError;
  final DateTime createdAt;
  final DateTime updatedAt;

  double get requestedDays {
    if (isHalfDay) return 0.5;
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    final end = DateTime(endDate.year, endDate.month, endDate.day);
    final diff = end.difference(start).inDays + 1;
    return diff < 1 ? 1.0 : diff.toDouble();
  }

  bool get canCancel => approvalStatus == LeaveApprovalStatus.pending;
  bool get needsSync => syncStatus != RecordSyncStatus.synced;

  LeaveRequest copyWith({
    String? localId,
    String? serverId,
    String? employeeId,
    LeaveType? leaveType,
    DateTime? startDate,
    DateTime? endDate,
    bool? isHalfDay,
    String? reason,
    LeaveApprovalStatus? approvalStatus,
    String? approverComment,
    RecordSyncStatus? syncStatus,
    String? syncError,
    bool clearSyncError = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return LeaveRequest(
      localId: localId ?? this.localId,
      serverId: serverId ?? this.serverId,
      employeeId: employeeId ?? this.employeeId,
      leaveType: leaveType ?? this.leaveType,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      isHalfDay: isHalfDay ?? this.isHalfDay,
      reason: reason ?? this.reason,
      approvalStatus: approvalStatus ?? this.approvalStatus,
      approverComment: approverComment ?? this.approverComment,
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
        leaveType,
        startDate,
        endDate,
        isHalfDay,
        reason,
        approvalStatus,
        approverComment,
        syncStatus,
        syncError,
        createdAt,
        updatedAt,
      ];
}
