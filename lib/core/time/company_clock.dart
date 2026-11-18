/// Resolves company working-day dates and timestamps in a configurable
/// company timezone (e.g., `Asia/Kolkata`, `UTC`, or `UTC+05:30`).
class CompanyClock {
  CompanyClock({DateTime Function()? utcClock})
      : _utcClock = utcClock ?? _defaultUtcNow;

  final DateTime Function() _utcClock;

  static DateTime _defaultUtcNow() => DateTime.now().toUtc();

  DateTime nowUtc() => _utcClock().toUtc();

  /// Converts any [instant] to wall-clock date/time components in [timezone].
  static DateTime toCompanyTimezone(DateTime instant, String timezone) {
    final offset = parseTimezoneOffset(timezone);
    final shifted = instant.toUtc().add(offset);
    return DateTime(
      shifted.year,
      shifted.month,
      shifted.day,
      shifted.hour,
      shifted.minute,
      shifted.second,
      shifted.millisecond,
    );
  }

  /// Converts a wall-clock date/time in [timezone] to a UTC [DateTime].
  static DateTime fromCompanyTimezone({
    required int year,
    required int month,
    required int day,
    int hour = 0,
    int minute = 0,
    int second = 0,
    required String timezone,
  }) {
    final offset = parseTimezoneOffset(timezone);
    return DateTime.utc(year, month, day, hour, minute, second)
        .subtract(offset);
  }

  /// Returns wall-clock date/time components representing "now" in [timezone].
  DateTime nowInTimezone(String timezone) {
    return toCompanyTimezone(nowUtc(), timezone);
  }

  /// Returns the normalized calendar date (`YYYY-MM-DD`, midnight) of today's
  /// working day in the configured [timezone].
  DateTime workingDate(String timezone) {
    final companyNow = nowInTimezone(timezone);
    return DateTime(companyNow.year, companyNow.month, companyNow.day);
  }

  /// Resolves common IANA timezone IDs or explicit `UTC±HH:MM` offsets.
  static Duration parseTimezoneOffset(String timezone) {
    final normalized = timezone.trim();
    const knownOffsets = <String, Duration>{
      'UTC': Duration.zero,
      'Etc/UTC': Duration.zero,
      'Asia/Kolkata': Duration(hours: 5, minutes: 30),
      'Asia/Calcutta': Duration(hours: 5, minutes: 30),
      'Asia/Dubai': Duration(hours: 4),
      'Asia/Singapore': Duration(hours: 8),
      'Asia/Tokyo': Duration(hours: 9),
      'Europe/London': Duration.zero,
      'Europe/Berlin': Duration(hours: 1),
      'America/New_York': Duration(hours: -5),
      'America/Chicago': Duration(hours: -6),
      'America/Los_Angeles': Duration(hours: -8),
      'Australia/Sydney': Duration(hours: 10),
    };

    final known = knownOffsets[normalized];
    if (known != null) return known;

    final match = RegExp(r'^(?:UTC|GMT)?([+-])(\d{1,2})(?::?(\d{2}))?$')
        .firstMatch(normalized);
    if (match != null) {
      final sign = match.group(1) == '-' ? -1 : 1;
      final hours = int.parse(match.group(2)!);
      final minutes = int.parse(match.group(3) ?? '0');
      return Duration(minutes: sign * (hours * 60 + minutes));
    }

    // Default fallback to IST if an unrecognized timezone string is supplied.
    return const Duration(hours: 5, minutes: 30);
  }
}
