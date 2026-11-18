import 'package:flutter/material.dart';

import '../error/failures.dart';
import '../location/location_service.dart';
import '../location/location_simulator_sheet.dart';
import '../theme/app_theme.dart';

/// Displays contextual feedback for attendance check-in/out actions, including
/// direct actions for permanently denied location permissions, disabled GPS,
/// and outside-geofence errors.
abstract final class AttendanceFeedbackHandler {
  static void show({
    required BuildContext context,
    required LocationService locationService,
    required String officeName,
    required double officeLatitude,
    required double officeLongitude,
    String? errorMessage,
    Failure? failure,
    String? feedbackMessage,
  }) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();

    if (errorMessage != null) {
      SnackBarAction? action;
      if (failure is LocationPermissionPermanentlyDeniedFailure) {
        action = SnackBarAction(
          label: 'Settings',
          textColor: Colors.white,
          onPressed: () => locationService.openAppSettings(),
        );
      } else if (failure is LocationUnavailableFailure) {
        action = SnackBarAction(
          label: 'GPS',
          textColor: Colors.white,
          onPressed: () => locationService.openLocationSettings(),
        );
      } else if (failure is OutsideGeofenceFailure) {
        action = SnackBarAction(
          label: 'Simulate',
          textColor: Colors.white,
          onPressed: () => LocationSimulatorSheet.show(
            context,
            locationService: locationService,
            officeName: officeName,
            officeLatitude: officeLatitude,
            officeLongitude: officeLongitude,
          ),
        );
      }

      messenger.showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          backgroundColor: const Color(0xFFB91C1C),
          content: Text(errorMessage),
          action: action,
        ),
      );
      return;
    }

    if (feedbackMessage != null) {
      messenger.showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          backgroundColor: AppTheme.inkDark,
          content: Text(feedbackMessage),
        ),
      );
    }
  }
}
