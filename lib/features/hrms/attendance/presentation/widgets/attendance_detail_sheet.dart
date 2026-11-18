import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/time/company_clock.dart';
import '../../../../../core/widgets/sync_status_chip.dart';
import '../../domain/entities/attendance_record.dart';

/// Detailed bottom sheet for inspecting a single attendance record's timestamps,
/// working duration, captured GPS coordinates, distance from office, and sync state.
class AttendanceDetailSheet extends StatelessWidget {
  const AttendanceDetailSheet({
    super.key,
    required this.record,
    this.companyTimezone = 'Asia/Kolkata',
  });

  final AttendanceRecord record;
  final String companyTimezone;

  static Future<void> show(
    BuildContext context,
    AttendanceRecord record, {
    String companyTimezone = 'Asia/Kolkata',
  }) {
    return showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AttendanceDetailSheet(
        record: record,
        companyTimezone: companyTimezone,
      ),
    );
  }

  String _formatDuration(Duration? duration) {
    if (duration == null) return '--';
    final h = duration.inHours.toString().padLeft(2, '0');
    final m = (duration.inMinutes % 60).toString().padLeft(2, '0');
    return '${h}h ${m}m';
  }

  @override
  Widget build(BuildContext context) {
    final fullDate = DateFormat('EEEE, d MMMM yyyy').format(record.date);
    final timeFmt = DateFormat('hh:mm a');
    final checkInText = record.checkInAt != null
        ? timeFmt.format(
            CompanyClock.toCompanyTimezone(record.checkInAt!, companyTimezone),
          )
        : 'Not recorded';
    final checkOutText = record.checkOutAt != null
        ? timeFmt.format(
            CompanyClock.toCompanyTimezone(record.checkOutAt!, companyTimezone),
          )
        : 'Not recorded';

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
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
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Attendance Details',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      fullDate,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              SyncStatusChip(status: record.syncStatus),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _DetailMetric(
                    label: 'Working Duration',
                    value: _formatDuration(record.workedDuration),
                  ),
                ),
                Container(width: 1, height: 34, color: AppTheme.border),
                Expanded(
                  child: _DetailMetric(
                    label: 'Location',
                    value: record.workLocation ?? 'Office',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _EventDetailRow(
            icon: Icons.login_rounded,
            iconColor: const Color(0xFF0D9488),
            iconBg: const Color(0xFFECFDF5),
            title: 'Check In',
            time: checkInText,
            latitude: record.checkInLatitude,
            longitude: record.checkInLongitude,
            distanceMeters: record.checkInDistanceMeters,
          ),
          const SizedBox(height: 10),
          _EventDetailRow(
            icon: Icons.logout_rounded,
            iconColor: const Color(0xFF4F46E5),
            iconBg: const Color(0xFFEEF2FF),
            title: 'Check Out',
            time: checkOutText,
            latitude: record.checkOutLatitude,
            longitude: record.checkOutLongitude,
            distanceMeters: record.checkOutDistanceMeters,
          ),
          if (record.syncError != null && record.syncError!.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFECACA)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    size: 18,
                    color: Color(0xFFDC2626),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      record.syncError!,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF991B1B),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DetailMetric extends StatelessWidget {
  const _DetailMetric({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11.5,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _EventDetailRow extends StatelessWidget {
  const _EventDetailRow({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.time,
    this.latitude,
    this.longitude,
    this.distanceMeters,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final String time;
  final double? latitude;
  final double? longitude;
  final double? distanceMeters;

  @override
  Widget build(BuildContext context) {
    final hasGps = latitude != null && longitude != null;
    final gpsLine = hasGps
        ? 'GPS: ${latitude!.toStringAsFixed(4)}, ${longitude!.toStringAsFixed(4)}'
            '${distanceMeters != null ? ' • ${distanceMeters!.round()}m from office' : ''}'
        : 'GPS coordinates not captured';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      time,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  gpsLine,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
