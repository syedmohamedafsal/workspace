import 'dart:async';

import 'package:geolocator/geolocator.dart';

import '../config/employee_config.dart';
import '../error/failures.dart';
import '../error/result.dart';
import 'geo_distance_calculator.dart';
import 'location_models.dart';

/// Abstraction over GPS capture, permission handling, and reviewer location
/// simulation.
abstract interface class LocationService {
  LocationSimulationState get simulationState;
  Stream<LocationSimulationState> get simulationStream;

  void updateSimulation(LocationSimulationState state);

  /// Captures the current GPS location (or simulated location if enabled).
  ///
  /// Uses [officeLatitude] and [officeLongitude] as the reference point when
  /// simulating inside/outside office locations.
  Future<Result<LocationCoordinate>> getCurrentLocation({
    double? officeLatitude,
    double? officeLongitude,
  });

  Future<bool> openAppSettings();
  Future<bool> openLocationSettings();

  Future<void> dispose();
}

/// Production implementation using `geolocator` with built-in reviewer
/// simulation modes for effortless geofence and permission-state testing.
class GeolocatorLocationService implements LocationService {
  GeolocatorLocationService({
    required PreconfiguredEmployeeConfig employeeConfig,
    LocationSimulationState? initialSimulation,
  })  : _employeeConfig = employeeConfig,
        _simulationState = initialSimulation ?? _resolveInitialSimulation();

  final PreconfiguredEmployeeConfig _employeeConfig;
  final StreamController<LocationSimulationState> _simulationController =
      StreamController<LocationSimulationState>.broadcast();

  LocationSimulationState _simulationState;

  /// Allows reviewers to launch with `--dart-define=SIMULATE_LOCATION=inside`
  /// or `--dart-define=SIMULATE_LOCATION=outside` right from the CLI.
  static LocationSimulationState _resolveInitialSimulation() {
    const modeFlag = String.fromEnvironment('SIMULATE_LOCATION');
    return switch (modeFlag.toLowerCase()) {
      'inside' => const LocationSimulationState(
          mode: LocationSimulationMode.insideOffice,
        ),
      'outside' => const LocationSimulationState(
          mode: LocationSimulationMode.outsideOffice,
        ),
      'denied' => const LocationSimulationState(
          mode: LocationSimulationMode.permissionDenied,
        ),
      'denied_forever' => const LocationSimulationState(
          mode: LocationSimulationMode.permissionPermanentlyDenied,
        ),
      'unavailable' => const LocationSimulationState(
          mode: LocationSimulationMode.locationUnavailable,
        ),
      _ => const LocationSimulationState(mode: LocationSimulationMode.liveGps),
    };
  }

  @override
  LocationSimulationState get simulationState => _simulationState;

  @override
  Stream<LocationSimulationState> get simulationStream =>
      _simulationController.stream;

  @override
  void updateSimulation(LocationSimulationState state) {
    _simulationState = state;
    if (!_simulationController.isClosed) {
      _simulationController.add(state);
    }
  }

  @override
  Future<Result<LocationCoordinate>> getCurrentLocation({
    double? officeLatitude,
    double? officeLongitude,
  }) async {
    final refLat = officeLatitude ?? _employeeConfig.officeLatitude;
    final refLng = officeLongitude ?? _employeeConfig.officeLongitude;

    switch (_simulationState.mode) {
      case LocationSimulationMode.insideOffice:
        final point = GeoDistanceCalculator.offsetNorth(
          latitude: refLat,
          longitude: refLng,
          northMeters: 25,
        );
        return Success(
          LocationCoordinate(
            latitude: point.latitude,
            longitude: point.longitude,
            accuracyMeters: 5.0,
            capturedAt: DateTime.now().toUtc(),
            isSimulated: true,
          ),
        );
      case LocationSimulationMode.outsideOffice:
        final point = GeoDistanceCalculator.offsetNorth(
          latitude: refLat,
          longitude: refLng,
          northMeters: 450,
        );
        return Success(
          LocationCoordinate(
            latitude: point.latitude,
            longitude: point.longitude,
            accuracyMeters: 8.0,
            capturedAt: DateTime.now().toUtc(),
            isSimulated: true,
          ),
        );
      case LocationSimulationMode.custom:
        final lat = _simulationState.customLatitude;
        final lng = _simulationState.customLongitude;
        if (lat == null ||
            lng == null ||
            lat < -90 ||
            lat > 90 ||
            lng < -180 ||
            lng > 180) {
          return const FailureResult(
            ValidationFailure('Invalid simulated coordinates configured.'),
          );
        }
        return Success(
          LocationCoordinate(
            latitude: lat,
            longitude: lng,
            accuracyMeters: 5.0,
            capturedAt: DateTime.now().toUtc(),
            isSimulated: true,
          ),
        );
      case LocationSimulationMode.permissionDenied:
        return const FailureResult(LocationPermissionDeniedFailure());
      case LocationSimulationMode.permissionPermanentlyDenied:
        return const FailureResult(
          LocationPermissionPermanentlyDeniedFailure(),
        );
      case LocationSimulationMode.locationUnavailable:
        return const FailureResult(LocationUnavailableFailure());
      case LocationSimulationMode.liveGps:
        return _fetchDeviceGpsLocation();
    }
  }

  Future<Result<LocationCoordinate>> _fetchDeviceGpsLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return const FailureResult(LocationUnavailableFailure());
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return const FailureResult(LocationPermissionDeniedFailure());
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return const FailureResult(
          LocationPermissionPermanentlyDeniedFailure(),
        );
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 12),
        ),
      );

      return Success(
        LocationCoordinate(
          latitude: position.latitude,
          longitude: position.longitude,
          accuracyMeters: position.accuracy,
          capturedAt: position.timestamp.toUtc(),
          isSimulated: position.isMocked,
        ),
      );
    } on TimeoutException {
      return const FailureResult(
        LocationUnavailableFailure(
          'Timed out waiting for GPS signal. Please move to an open area and try again.',
        ),
      );
    } on LocationServiceDisabledException {
      return const FailureResult(LocationUnavailableFailure());
    } on PermissionDeniedException {
      return const FailureResult(LocationPermissionDeniedFailure());
    } catch (e) {
      return FailureResult(
        LocationUnavailableFailure(
          'Unable to determine current location. Please check GPS settings.',
        ),
      );
    }
  }

  @override
  Future<bool> openAppSettings() => Geolocator.openAppSettings();

  @override
  Future<bool> openLocationSettings() => Geolocator.openLocationSettings();

  @override
  Future<void> dispose() => _simulationController.close();
}
