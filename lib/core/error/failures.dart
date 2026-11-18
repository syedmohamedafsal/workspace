import 'package:equatable/equatable.dart';

/// Domain-layer failures returned inside [Result] instead of throwing.
sealed class Failure extends Equatable {
  const Failure(this.message, {this.code});

  final String message;
  final String? code;

  @override
  List<Object?> get props => [message, code];
}

final class ServerFailure extends Failure {
  const ServerFailure(super.message, {this.statusCode, super.code});

  final int? statusCode;

  @override
  List<Object?> get props => [message, code, statusCode];
}

final class NetworkFailure extends Failure {
  const NetworkFailure([
    super.message = 'You are offline. Changes have been saved locally.',
  ]);
}

final class CacheFailure extends Failure {
  const CacheFailure(super.message);
}

final class ConflictFailure extends Failure {
  const ConflictFailure(super.message, {super.code});
}

final class ValidationFailure extends Failure {
  const ValidationFailure(super.message, {super.code});
}

final class LocationPermissionDeniedFailure extends Failure {
  const LocationPermissionDeniedFailure([
    super.message =
        'Location permission was denied. Please allow location access to mark attendance.',
  ]) : super(code: 'LOCATION_PERMISSION_DENIED');
}

final class LocationPermissionPermanentlyDeniedFailure extends Failure {
  const LocationPermissionPermanentlyDeniedFailure([
    super.message =
        'Location permission is permanently denied. Please enable it in app settings to mark attendance.',
  ]) : super(code: 'LOCATION_PERMISSION_PERMANENTLY_DENIED');
}

final class LocationUnavailableFailure extends Failure {
  const LocationUnavailableFailure([
    super.message =
        'Location is currently unavailable. Please turn on GPS/Location Services and try again.',
  ]) : super(code: 'LOCATION_UNAVAILABLE');
}

final class OutsideGeofenceFailure extends Failure {
  OutsideGeofenceFailure({
    required this.distanceMeters,
    required this.allowedRadiusMeters,
    required this.officeName,
  }) : super(
          'You are ${distanceMeters.round()}m away from $officeName. Please move inside the ${allowedRadiusMeters.round()}m office premises to check in or check out.',
          code: 'OUTSIDE_GEOFENCE',
        );

  final double distanceMeters;
  final double allowedRadiusMeters;
  final String officeName;

  @override
  List<Object?> get props => [
        message,
        code,
        distanceMeters,
        allowedRadiusMeters,
        officeName,
      ];
}

final class UnexpectedFailure extends Failure {
  const UnexpectedFailure(super.message);
}
