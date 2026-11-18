import 'package:flutter_test/flutter_test.dart';
import 'package:rebs/core/location/geo_distance_calculator.dart';
import 'package:rebs/core/time/company_clock.dart';

void main() {
  test('CompanyClock calculates working day in configurable company timezone',
      () {
    // 2026-11-18 20:00 UTC is 2026-11-19 01:30 in Asia/Kolkata (+05:30)
    final clock = CompanyClock(
      utcClock: () => DateTime.utc(2026, 11, 18, 20, 0),
    );

    expect(clock.workingDate('UTC'), DateTime(2026, 11, 18));
    expect(clock.workingDate('Asia/Kolkata'), DateTime(2026, 11, 19));
    expect(clock.workingDate('America/New_York'), DateTime(2026, 11, 18));
    expect(clock.workingDate('UTC+08:00'), DateTime(2026, 11, 19));

    final utcInstant = CompanyClock.fromCompanyTimezone(
      year: 2026,
      month: 11,
      day: 18,
      hour: 9,
      minute: 6,
      timezone: 'Asia/Kolkata',
    );
    expect(utcInstant, DateTime.utc(2026, 11, 18, 3, 36));
    final istWall = CompanyClock.toCompanyTimezone(utcInstant, 'Asia/Kolkata');
    expect(istWall.hour, 9);
    expect(istWall.minute, 6);
  });

  test('GeoDistanceCalculator accurately measures inside/outside 200m radius',
      () {
    const officeLat = 10.0159;
    const officeLng = 76.3419;

    final inside = GeoDistanceCalculator.offsetNorth(
      latitude: officeLat,
      longitude: officeLng,
      northMeters: 25,
    );
    final outside = GeoDistanceCalculator.offsetNorth(
      latitude: officeLat,
      longitude: officeLng,
      northMeters: 450,
    );

    final insideDist = GeoDistanceCalculator.distanceInMeters(
      startLatitude: inside.latitude,
      startLongitude: inside.longitude,
      endLatitude: officeLat,
      endLongitude: officeLng,
    );
    final outsideDist = GeoDistanceCalculator.distanceInMeters(
      startLatitude: outside.latitude,
      startLongitude: outside.longitude,
      endLatitude: officeLat,
      endLongitude: officeLng,
    );

    expect(insideDist, closeTo(25, 2));
    expect(outsideDist, closeTo(450, 5));
  });
}
