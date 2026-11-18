import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'location_models.dart';
import 'location_service.dart';

/// Reviewer-friendly bottom sheet allowing instant simulation of GPS locations
/// (inside/outside 200m office geofence, custom coordinates, and permission errors).
class LocationSimulatorSheet extends StatefulWidget {
  const LocationSimulatorSheet({
    super.key,
    required this.locationService,
    required this.officeName,
    required this.officeLatitude,
    required this.officeLongitude,
  });

  final LocationService locationService;
  final String officeName;
  final double officeLatitude;
  final double officeLongitude;

  static Future<void> show(
    BuildContext context, {
    required LocationService locationService,
    required String officeName,
    required double officeLatitude,
    required double officeLongitude,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => LocationSimulatorSheet(
        locationService: locationService,
        officeName: officeName,
        officeLatitude: officeLatitude,
        officeLongitude: officeLongitude,
      ),
    );
  }

  @override
  State<LocationSimulatorSheet> createState() => _LocationSimulatorSheetState();
}

class _LocationSimulatorSheetState extends State<LocationSimulatorSheet> {
  late LocationSimulationMode _selectedMode;
  late final TextEditingController _latController;
  late final TextEditingController _lngController;
  String? _validationError;

  @override
  void initState() {
    super.initState();
    final current = widget.locationService.simulationState;
    _selectedMode = current.mode;
    _latController = TextEditingController(
      text: (current.customLatitude ?? widget.officeLatitude).toStringAsFixed(6),
    );
    _lngController = TextEditingController(
      text:
          (current.customLongitude ?? widget.officeLongitude).toStringAsFixed(6),
    );
  }

  @override
  void dispose() {
    _latController.dispose();
    _lngController.dispose();
    super.dispose();
  }

  void _apply() {
    if (_selectedMode == LocationSimulationMode.custom) {
      final lat = double.tryParse(_latController.text.trim());
      final lng = double.tryParse(_lngController.text.trim());
      if (lat == null ||
          lng == null ||
          lat < -90 ||
          lat > 90 ||
          lng < -180 ||
          lng > 180) {
        setState(() {
          _validationError =
              'Enter valid latitude (-90..90) and longitude (-180..180).';
        });
        return;
      }
      widget.locationService.updateSimulation(
        LocationSimulationState(
          mode: LocationSimulationMode.custom,
          customLatitude: lat,
          customLongitude: lng,
        ),
      );
    } else {
      widget.locationService.updateSimulation(
        LocationSimulationState(mode: _selectedMode),
      );
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 12, 20, 24 + bottomInset),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Location Mode & Simulator',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Switch between Live GPS and simulated locations for testing',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.border),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.business_rounded,
                    size: 18,
                    color: AppTheme.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${widget.officeName}\n${widget.officeLatitude.toStringAsFixed(4)}, ${widget.officeLongitude.toStringAsFixed(4)} • 200m radius',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            for (final mode in LocationSimulationMode.values)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: InkWell(
                  onTap: () => setState(() {
                    _selectedMode = mode;
                    _validationError = null;
                  }),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: _selectedMode == mode
                          ? AppTheme.primarySoft
                          : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _selectedMode == mode
                            ? AppTheme.primary
                            : AppTheme.border,
                        width: _selectedMode == mode ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _selectedMode == mode
                              ? Icons.radio_button_checked_rounded
                              : Icons.radio_button_off_rounded,
                          size: 18,
                          color: _selectedMode == mode
                              ? AppTheme.primary
                              : AppTheme.textMuted,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            mode.label,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: _selectedMode == mode
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            if (_selectedMode == LocationSimulationMode.custom) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _latController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Latitude',
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _lngController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Longitude',
                      ),
                    ),
                  ),
                ],
              ),
              if (_validationError != null) ...[
                const SizedBox(height: 6),
                Text(
                  _validationError!,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFFDC2626),
                  ),
                ),
              ],
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _apply,
              style: FilledButton.styleFrom(backgroundColor: AppTheme.inkDark),
              child: const Text('Apply Location Mode'),
            ),
          ],
        ),
      ),
    );
  }
}
