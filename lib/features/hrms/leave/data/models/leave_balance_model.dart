import '../../domain/entities/leave_balance.dart';
import '../../domain/entities/leave_request.dart';

class LeaveBalanceModel extends LeaveBalance {
  const LeaveBalanceModel({
    required super.leaveType,
    required super.totalDays,
    required super.usedDays,
    required super.pendingDays,
    required super.updatedAt,
  });

  factory LeaveBalanceModel.fromDbMap(Map<String, dynamic> map) {
    return LeaveBalanceModel(
      leaveType: LeaveType.fromString(map['leave_type'] as String),
      totalDays: (map['total_days'] as num).toDouble(),
      usedDays: (map['used_days'] as num).toDouble(),
      pendingDays: (map['pending_days'] as num).toDouble(),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  factory LeaveBalanceModel.fromApiJson(Map<String, dynamic> json) {
    return LeaveBalanceModel(
      leaveType: LeaveType.fromString(json['leave_type'] as String? ?? 'annual'),
      totalDays: (json['total_days'] as num?)?.toDouble() ?? 0,
      usedDays: (json['used_days'] as num?)?.toDouble() ?? 0,
      pendingDays: (json['pending_days'] as num?)?.toDouble() ?? 0,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toDbMap() {
    return {
      'leave_type': leaveType.name,
      'total_days': totalDays,
      'used_days': usedDays,
      'pending_days': pendingDays,
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
