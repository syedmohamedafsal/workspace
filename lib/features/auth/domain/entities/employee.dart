import 'package:equatable/equatable.dart';

/// Immutable domain entity representing an authenticated REBS employee.
class Employee extends Equatable {
  const Employee({
    required this.employeeId,
    required this.employeeName,
    required this.department,
    required this.designation,
    required this.officeId,
    required this.officeName,
    required this.officeLatitude,
    required this.officeLongitude,
    required this.companyTimezone,
  });

  final String employeeId;
  final String employeeName;
  final String department;
  final String designation;
  final String officeId;
  final String officeName;
  final double officeLatitude;
  final double officeLongitude;
  final String companyTimezone;

  bool get hasValidIdentity =>
      employeeId.trim().isNotEmpty &&
      employeeName.trim().isNotEmpty &&
      department.trim().isNotEmpty &&
      designation.trim().isNotEmpty &&
      officeId.trim().isNotEmpty &&
      officeName.trim().isNotEmpty &&
      companyTimezone.trim().isNotEmpty &&
      officeLatitude >= -90.0 &&
      officeLatitude <= 90.0 &&
      officeLongitude >= -180.0 &&
      officeLongitude <= 180.0;

  Employee copyWith({
    String? employeeId,
    String? employeeName,
    String? department,
    String? designation,
    String? officeId,
    String? officeName,
    double? officeLatitude,
    double? officeLongitude,
    String? companyTimezone,
  }) {
    return Employee(
      employeeId: employeeId ?? this.employeeId,
      employeeName: employeeName ?? this.employeeName,
      department: department ?? this.department,
      designation: designation ?? this.designation,
      officeId: officeId ?? this.officeId,
      officeName: officeName ?? this.officeName,
      officeLatitude: officeLatitude ?? this.officeLatitude,
      officeLongitude: officeLongitude ?? this.officeLongitude,
      companyTimezone: companyTimezone ?? this.companyTimezone,
    );
  }

  @override
  List<Object?> get props => [
        employeeId,
        employeeName,
        department,
        designation,
        officeId,
        officeName,
        officeLatitude,
        officeLongitude,
        companyTimezone,
      ];
}
