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
      final isCheckInRequired = errorMessage.contains('prior check-in') ||
          errorMessage.contains('after checking in') ||
          errorMessage.contains('check in before you check out') ||
          errorMessage.contains('checking in');
      final displayMessage = isCheckInRequired
          ? 'You have to check in before you check out.'
          : errorMessage;

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
          content: Text(displayMessage),
          action: action,
        ),
      );
      return;
    }

    if (feedbackMessage != null) {
      final isCheckInWelcome = feedbackMessage.contains('coffee') ||
          feedbackMessage.contains('commit');
      final isCheckOut = feedbackMessage.contains('Checked out') ||
          feedbackMessage.contains('Office hours') ||
          feedbackMessage.contains('office time');

      final (bgColor, iconEmoji) = isCheckInWelcome
          ? (const Color(0xFF065F46), '☕')
          : isCheckOut
              ? (const Color(0xFF1E1B4B), '🌙')
              : (AppTheme.inkDark, '✨');

      messenger.showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          backgroundColor: bgColor,
          content: Row(
            children: [
              Text(iconEmoji, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  feedbackMessage,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
  }
}
