/// Configurable defaults for the preconfigured REBS employee session.
///
/// Defaults point to **Teqbae Innovations & Solutions**
/// (AKL Heights, Seaport-Airport Road, Thrikkakara, Kakkanad, Kochi).
///
/// Coordinates and company timezone can be overridden at build/run time via
/// `--dart-define`:
/// ```bash
/// flutter run \
///   --dart-define=OFFICE_LATITUDE=10.0159 \
///   --dart-define=OFFICE_LONGITUDE=76.3419 \
///   --dart-define=COMPANY_TIMEZONE=Asia/Kolkata
/// ```
class PreconfiguredEmployeeConfig {
  const PreconfiguredEmployeeConfig({
    this.employeeId = 'REBS001',
    this.employeeName = 'Syed Mohamed Afsal',
    this.department = 'Flutter Developer',
    this.designation = 'Flutter Developer',
    this.officeId = 'OFFICE001',
    this.officeName = 'Teqbae Innovations, Kochi',
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
    defaultValue: '10.0159',
  );

  static const String _envOfficeLongitude = String.fromEnvironment(
    'OFFICE_LONGITUDE',
    defaultValue: '76.3419',
  );

  static const double _fallbackLatitude = 10.0159;
  static const double _fallbackLongitude = 76.3419;

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
