import 'package:equatable/equatable.dart';

/// Captured GPS coordinate attached to an attendance check-in or check-out event.
class LocationCoordinate extends Equatable {
  const LocationCoordinate({
    required this.latitude,
    required this.longitude,
    required this.capturedAt,
    this.accuracyMeters,
    this.isSimulated = false,
  });

  final double latitude;
  final double longitude;
  final DateTime capturedAt;
  final double? accuracyMeters;
  final bool isSimulated;

  @override
  List<Object?> get props => [
        latitude,
        longitude,
        capturedAt,
        accuracyMeters,
        isSimulated,
      ];
}

/// Reviewer-friendly location source modes for testing geofence and error flows.
enum LocationSimulationMode {
  liveGps('Live Device GPS'),
  insideOffice('Simulate: Inside Office (~25m)'),
  outsideOffice('Simulate: Outside Office (~450m)'),
  permissionDenied('Simulate: Permission Denied'),
  permissionPermanentlyDenied('Simulate: Permanently Denied'),
  locationUnavailable('Simulate: Location Unavailable'),
  custom('Simulate: Custom Coordinates');

  const LocationSimulationMode(this.label);

  final String label;

  bool get isSimulated => this != LocationSimulationMode.liveGps;
}

class LocationSimulationState extends Equatable {
  const LocationSimulationState({
    this.mode = LocationSimulationMode.liveGps,
    this.customLatitude,
    this.customLongitude,
  });

  final LocationSimulationMode mode;
  final double? customLatitude;
  final double? customLongitude;

  @override
  List<Object?> get props => [mode, customLatitude, customLongitude];
}
