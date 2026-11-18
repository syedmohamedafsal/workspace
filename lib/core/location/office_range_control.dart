import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'geo_distance_calculator.dart';
import 'location_models.dart';
import 'location_service.dart';

/// Tactile inside-200m toggle control with a clear professional warning banner
/// when outside the permitted office geofence.
class OfficeRangeControl extends StatelessWidget {
  const OfficeRangeControl({
    super.key,
    required this.locationService,
    required this.officeName,
    required this.onOpenMoreOptions,
    this.officeLatitude,
    this.officeLongitude,
    this.allowedRadiusMeters = 200.0,
    this.isLightSurface = false,
  });

  final LocationService locationService;
  final String officeName;
  final VoidCallback onOpenMoreOptions;
  final double? officeLatitude;
  final double? officeLongitude;
  final double allowedRadiusMeters;
  final bool isLightSurface;

  double? _customDistanceMeters(LocationSimulationState sim) {
    if (sim.mode != LocationSimulationMode.custom) return null;
    final lat = sim.customLatitude;
    final lng = sim.customLongitude;
    final oLat = officeLatitude;
    final oLng = officeLongitude;
    if (lat == null || lng == null || oLat == null || oLng == null) {
      return null;
    }
    return GeoDistanceCalculator.distanceInMeters(
      startLatitude: lat,
      startLongitude: lng,
      endLatitude: oLat,
      endLongitude: oLng,
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<LocationSimulationState>(
      stream: locationService.simulationStream,
      initialData: locationService.simulationState,
      builder: (context, snapshot) {
        final sim = snapshot.data ?? const LocationSimulationState();
        final customDist = _customDistanceMeters(sim);
        final isCustomInside =
            customDist != null && customDist <= allowedRadiusMeters;
        final isCustomOutside =
            customDist != null && customDist > allowedRadiusMeters;

        final isInsideToggleOn =
            sim.mode == LocationSimulationMode.insideOffice || isCustomInside;
        final isOutsideSimulated =
            sim.mode == LocationSimulationMode.outsideOffice || isCustomOutside;

        final (icon, iconColor, subtitle) = switch (sim.mode) {
          LocationSimulationMode.insideOffice => (
              Icons.verified_outlined,
              isLightSurface
                  ? const Color(0xFF059669)
                  : const Color(0xFF34D399),
              'Within 200m of $officeName (~25m)',
            ),
          LocationSimulationMode.outsideOffice => (
              Icons.location_off_outlined,
              isLightSurface
                  ? const Color(0xFFD97706)
                  : const Color(0xFFFBBF24),
              'Outside 200m office range (~450m)',
            ),
          LocationSimulationMode.custom when customDist != null => (
              isCustomInside
                  ? Icons.verified_outlined
                  : Icons.location_off_outlined,
              isCustomInside
                  ? (isLightSurface
                      ? const Color(0xFF059669)
                      : const Color(0xFF34D399))
                  : (isLightSurface
                      ? const Color(0xFFD97706)
                      : const Color(0xFFFBBF24)),
              isCustomInside
                  ? 'Map pin inside 200m (~${customDist.round()}m)'
                  : 'Map pin outside 200m (~${customDist.round()}m)',
            ),
          LocationSimulationMode.liveGps => (
              Icons.my_location_rounded,
              isLightSurface
                  ? const Color(0xFF1572B6)
                  : const Color(0xFF60A5FA),
              'Live GPS • Toggle ON to simulate inside 200m',
            ),
          _ => (
              Icons.tune_rounded,
              isLightSurface ? AppTheme.primary : const Color(0xFF93C5FD),
              sim.mode.label,
            ),
        };

        final boxBg = isLightSurface
            ? const Color(0xFFF8FAFC)
            : Colors.white.withValues(alpha: 0.08);
        final borderColor = isInsideToggleOn
            ? const Color(0xFF10B981)
                .withValues(alpha: isLightSurface ? 0.45 : 0.4)
            : isOutsideSimulated
                ? const Color(0xFFF59E0B)
                    .withValues(alpha: isLightSurface ? 0.55 : 0.45)
                : (isLightSurface
                    ? AppTheme.border
                    : Colors.white.withValues(alpha: 0.1));
        final titleColor =
            isLightSurface ? AppTheme.textPrimary : Colors.white;
        final subColor = isLightSurface
            ? AppTheme.textSecondary
            : Colors.white.withValues(alpha: 0.72);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: boxBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderColor),
              ),
              child: Row(
                children: [
                  Icon(icon, size: 18, color: iconColor),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Inside 200m Range',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: titleColor,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: subColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch.adaptive(
                    key: const ValueKey('inside_200m_switch'),
                    value: isInsideToggleOn,
                    activeTrackColor: const Color(0xFF10B981),
                    activeThumbColor: Colors.white,
                    onChanged: (inside) {
                      locationService.updateSimulation(
                        LocationSimulationState(
                          mode: inside
                              ? LocationSimulationMode.insideOffice
                              : LocationSimulationMode.outsideOffice,
                        ),
                      );
                    },
                  ),
                  IconButton(
                    tooltip: 'More location options',
                    onPressed: onOpenMoreOptions,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                    icon: Icon(
                      Icons.tune_rounded,
                      size: 17,
                      color: subColor,
                    ),
                  ),
                ],
              ),
            ),
            if (isOutsideSimulated) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isLightSurface
                      ? const Color(0xFFFFFBEB)
                      : const Color(0xFFF59E0B).withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isLightSurface
                        ? const Color(0xFFFCD34D)
                        : const Color(0xFFFBBF24).withValues(alpha: 0.45),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 1),
                      child: Icon(
                        Icons.warning_amber_rounded,
                        size: 18,
                        color: isLightSurface
                            ? const Color(0xFFD97706)
                            : const Color(0xFFFDE68A),
                      ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Outside Office Premises',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: isLightSurface
                                  ? const Color(0xFF92400E)
                                  : const Color(0xFFFEF3C7),
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'You are currently outside the 200m permitted area of $officeName. Please move inside the office premises to check in or check out.',
                            style: TextStyle(
                              fontSize: 11.5,
                              height: 1.38,
                              color: isLightSurface
                                  ? const Color(0xFF78350F)
                                  : Colors.white.withValues(alpha: 0.88),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
