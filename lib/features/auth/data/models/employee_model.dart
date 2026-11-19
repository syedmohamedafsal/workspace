import '../../../../core/config/employee_config.dart';
import '../../domain/entities/employee.dart';

/// Data model for serializing [Employee] to and from SQLite and JSON.
class EmployeeModel extends Employee {
  const EmployeeModel({
    required super.employeeId,
    required super.employeeName,
    required super.department,
    required super.designation,
    required super.officeId,
    required super.officeName,
    required super.officeLatitude,
    required super.officeLongitude,
    required super.companyTimezone,
  });

  factory EmployeeModel.fromEntity(Employee entity) {
    return EmployeeModel(
      employeeId: entity.employeeId,
      employeeName: entity.employeeName,
      department: entity.department,
      designation: entity.designation,
      officeId: entity.officeId,
      officeName: entity.officeName,
      officeLatitude: entity.officeLatitude,
      officeLongitude: entity.officeLongitude,
      companyTimezone: entity.companyTimezone,
    );
  }

  factory EmployeeModel.fromConfig(PreconfiguredEmployeeConfig config) {
    return EmployeeModel(
      employeeId: config.employeeId,
      employeeName: config.employeeName,
      department: config.department,
      designation: config.designation,
      officeId: config.officeId,
      officeName: config.officeName,
      officeLatitude: config.officeLatitude,
      officeLongitude: config.officeLongitude,
      companyTimezone: config.companyTimezone,
    );
  }

  factory EmployeeModel.fromDbMap(Map<String, dynamic> map) {
    return EmployeeModel(
      employeeId: map['employee_id'] as String,
      employeeName: map['employee_name'] as String,
      department: map['department'] as String,
      designation: map['designation'] as String,
      officeId: map['office_id'] as String,
      officeName: map['office_name'] as String,
      officeLatitude: (map['office_latitude'] as num).toDouble(),
      officeLongitude: (map['office_longitude'] as num).toDouble(),
      companyTimezone: map['company_timezone'] as String,
    );
  }

  factory EmployeeModel.fromApiJson(Map<String, dynamic> json) {
    return EmployeeModel(
      employeeId: (json['employee_id'] ?? json['id'] ?? '') as String,
      employeeName:
          (json['employee_name'] ?? json['name'] ?? 'Syed Mohamed Afsal')
              as String,
      department: (json['department'] ?? 'Engineering') as String,
      designation:
          (json['designation'] ?? json['role'] ?? 'Flutter Developer') as String,
      officeId: (json['office_id'] ?? 'OFF_KOCHI_01') as String,
      officeName:
          (json['office_name'] ?? 'Teqbae Innovations, Kochi') as String,
      officeLatitude:
          (json['office_latitude'] as num?)?.toDouble() ?? 10.0159,
      officeLongitude:
          (json['office_longitude'] as num?)?.toDouble() ?? 76.3419,
      companyTimezone:
          (json['company_timezone'] ?? 'Asia/Kolkata') as String,
    );
  }

  Map<String, dynamic> toDbMap() {
    return {
      'employee_id': employeeId,
      'employee_name': employeeName,
      'department': department,
      'designation': designation,
      'office_id': officeId,
      'office_name': officeName,
      'office_latitude': officeLatitude,
      'office_longitude': officeLongitude,
      'company_timezone': companyTimezone,
    };
  }
}
