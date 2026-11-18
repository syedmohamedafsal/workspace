/// Configurable defaults for the preconfigured REBS employee session.
///
/// Coordinates and company timezone can be overridden at build/run time via
/// `--dart-define`:
/// ```bash
/// flutter run \
///   --dart-define=OFFICE_LATITUDE=13.0827 \
///   --dart-define=OFFICE_LONGITUDE=80.2707 \
///   --dart-define=COMPANY_TIMEZONE=Asia/Kolkata
/// ```
class PreconfiguredEmployeeConfig {
  const PreconfiguredEmployeeConfig({
    this.employeeId = 'REBS001',
    this.employeeName = 'Syed Mohamed Afsal',
    this.department = 'Engineering',
    this.designation = 'Flutter Developer',
    this.officeId = 'OFFICE001',
    this.officeName = 'REBS Chennai Office',
    double? officeLatitude,
    double? officeLongitude,
    this.companyTimezone = const String.fromEnvironment(
      'COMPANY_TIMEZONE',
      defaultValue: 'Asia/Kolkata',
    ),
  })  : _officeLatitudeOverride = officeLatitude,
        _officeLongitudeOverride = officeLongitude;

  static const String _envOfficeLatitude = String.fromEnvironment(
    'OFFICE_LATITUDE',
    defaultValue: '13.0827',
  );

  static const String _envOfficeLongitude = String.fromEnvironment(
    'OFFICE_LONGITUDE',
    defaultValue: '80.2707',
  );

  static const double _fallbackLatitude = 13.0827;
  static const double _fallbackLongitude = 80.2707;

  final String employeeId;
  final String employeeName;
  final String department;
  final String designation;
  final String officeId;
  final String officeName;
  final double? _officeLatitudeOverride;
  final double? _officeLongitudeOverride;
  final String companyTimezone;

  double get officeLatitude =>
      _officeLatitudeOverride ??
      double.tryParse(_envOfficeLatitude) ??
      _fallbackLatitude;

  double get officeLongitude =>
      _officeLongitudeOverride ??
      double.tryParse(_envOfficeLongitude) ??
      _fallbackLongitude;
}
