import 'package:critalarm/core/alarm/quiet_hours.dart';

/// When a reminder may land. All times are wall-clock.
///
/// Three rules: never 22:00 to 08:00, never inside the user's quiet hours
/// when they are on, and never within 2 hours after a ring that is known
/// when the plan is made.
final class LocalReminderTimeRules {
  const LocalReminderTimeRules({
    required this.quietHours,
    this.ringsAt = const [],
  });

  static const int dayStartHour = 8;
  static const int dayEndHour = 22;

  /// Where a moved reminder lands first.
  static const int defaultHour = 10;

  static const Duration quietAfterRing = Duration(hours: 2);

  final QuietHours quietHours;

  /// When known incidents rang.
  final List<DateTime> ringsAt;

  bool allows(DateTime at) {
    if (at.hour < dayStartHour || at.hour >= dayEndHour) return false;
    if (quietHours.isEnabled &&
        quietHours.containsMinute(QuietHours.minuteOf(at))) {
      return false;
    }
    for (final ring in ringsAt) {
      if (!at.isBefore(ring) && at.difference(ring) < quietAfterRing) {
        return false;
      }
    }
    return true;
  }

  /// [at] when it is allowed. Otherwise the first allowed whole hour from
  /// [hour] to 21:00 on the same day, then on the day [stepDays] later, and
  /// so on for [maxSteps] steps. Null when nothing in reach is allowed.
  DateTime? nextAllowed(
    DateTime at, {
    int hour = defaultHour,
    int stepDays = 1,
    int maxSteps = 8,
  }) {
    if (allows(at)) return at;
    var day = DateTime(at.year, at.month, at.day);
    for (var step = 0; step <= maxSteps; step++) {
      for (var h = hour; h < dayEndHour; h++) {
        final candidate = DateTime(day.year, day.month, day.day, h);
        if (candidate.isBefore(at)) continue;
        if (allows(candidate)) return candidate;
      }
      day = DateTime(day.year, day.month, day.day + stepDays);
    }
    return null;
  }
}
