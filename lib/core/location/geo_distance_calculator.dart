import 'dart:math' as math;

/// Pure-Dart Haversine distance calculator for office geofence checks.
abstract final class GeoDistanceCalculator {
  static const double _earthRadiusMeters = 6371000.0;

  /// Computes great-circle distance in metres between two WGS84 coordinates.
  static double distanceInMeters({
    required double startLatitude,
    required double startLongitude,
    required double endLatitude,
    required double endLongitude,
  }) {
    final dLat = _toRadians(endLatitude - startLatitude);
    final dLon = _toRadians(endLongitude - startLongitude);

    final lat1 = _toRadians(startLatitude);
    final lat2 = _toRadians(endLatitude);

    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) *
            math.cos(lat2) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return _earthRadiusMeters * c;
  }

  /// Returns a coordinate offset [northMeters] north of ([latitude], [longitude]).
  /// Useful for deterministic reviewer location simulation.
  static ({double latitude, double longitude}) offsetNorth({
    required double latitude,
    required double longitude,
    required double northMeters,
  }) {
    const metersPerDegreeLat = 111320.0;
    return (
      latitude: latitude + (northMeters / metersPerDegreeLat),
      longitude: longitude,
    );
  }

  static double _toRadians(double degrees) => degrees * (math.pi / 180.0);
}
