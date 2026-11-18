import '../../domain/entities/employee_session.dart';
import 'employee_model.dart';

/// Data model for persisting [EmployeeSession] in SQLite.
class EmployeeSessionModel extends EmployeeSession {
  const EmployeeSessionModel({
    required super.sessionId,
    required EmployeeModel employee,
    required super.initializedAt,
    required super.lastRestoredAt,
    super.isActive = true,
  }) : super(employee: employee);

  factory EmployeeSessionModel.fromEntity(EmployeeSession entity) {
    return EmployeeSessionModel(
      sessionId: entity.sessionId,
      employee: EmployeeModel.fromEntity(entity.employee),
      initializedAt: entity.initializedAt,
      lastRestoredAt: entity.lastRestoredAt,
      isActive: entity.isActive,
    );
  }

  factory EmployeeSessionModel.fromDbMap(Map<String, dynamic> map) {
    return EmployeeSessionModel(
      sessionId: map['session_id'] as String,
      employee: EmployeeModel.fromDbMap(map),
      isActive: (map['is_active'] as int) == 1,
      initializedAt: DateTime.parse(map['initialized_at'] as String),
      lastRestoredAt: DateTime.parse(map['last_restored_at'] as String),
    );
  }

  Map<String, dynamic> toDbMap() {
    final employeeModel = EmployeeModel.fromEntity(employee);
    return {
      'session_id': sessionId,
      ...employeeModel.toDbMap(),
      'is_active': isActive ? 1 : 0,
      'initialized_at': initializedAt.toIso8601String(),
      'last_restored_at': lastRestoredAt.toIso8601String(),
    };
  }
}
