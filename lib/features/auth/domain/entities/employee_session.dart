import 'package:equatable/equatable.dart';

import 'employee.dart';

/// Immutable domain entity representing a persisted employee workspace session.
class EmployeeSession extends Equatable {
  const EmployeeSession({
    required this.sessionId,
    required this.employee,
    required this.initializedAt,
    required this.lastRestoredAt,
    this.isActive = true,
  });

  final String sessionId;
  final Employee employee;
  final DateTime initializedAt;
  final DateTime lastRestoredAt;
  final bool isActive;

  bool get isValid =>
      isActive && sessionId.trim().isNotEmpty && employee.hasValidIdentity;

  EmployeeSession copyWith({
    String? sessionId,
    Employee? employee,
    DateTime? initializedAt,
    DateTime? lastRestoredAt,
    bool? isActive,
  }) {
    return EmployeeSession(
      sessionId: sessionId ?? this.sessionId,
      employee: employee ?? this.employee,
      initializedAt: initializedAt ?? this.initializedAt,
      lastRestoredAt: lastRestoredAt ?? this.lastRestoredAt,
      isActive: isActive ?? this.isActive,
    );
  }

  @override
  List<Object?> get props => [
        sessionId,
        employee,
        initializedAt,
        lastRestoredAt,
        isActive,
      ];
}
