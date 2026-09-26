import 'package:critalarm/features/local_reminders/domain/local_reminder_inputs.dart';

/// Calendar helpers on wall-clock times. Days are added through the
/// `DateTime` constructor so the hour stays put across a DST change.
abstract final class LocalReminderDates {
  static DateTime atHour(DateTime day, int hour) =>
      DateTime(day.year, day.month, day.day, hour);

  static DateTime addDays(DateTime at, int days) => DateTime(
    at.year,
    at.month,
    at.day + days,
    at.hour,
    at.minute,
    at.second,
  );

  /// [hour]:00 on the first day whose [hour]:00 is at or after [from].
  static DateTime atHourOnOrAfter(DateTime from, int hour) {
    final same = atHour(from, hour);
    return same.isBefore(from) ? addDays(same, 1) : same;
  }

  /// [hour]:00 on the first [weekday] whose [hour]:00 is at or after [from].
  static DateTime weekdayAtHourOnOrAfter(
    DateTime from,
    int weekday,
    int hour,
  ) {
    var at = atHourOnOrAfter(from, hour);
    while (at.weekday != weekday) {
      at = addDays(at, 1);
    }
    return at;
  }

  /// Whole calendar days from [from] to [to].
  static int daysBetween(DateTime from, DateTime to) => DateTime.utc(
    to.year,
    to.month,
    to.day,
  ).difference(DateTime.utc(from.year, from.month, from.day)).inDays;

  static bool isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// The latest non-null time, or null when there is none.
  static DateTime? latest(Iterable<DateTime?> times) {
    DateTime? best;
    for (final at in times) {
      if (at != null && (best == null || at.isAfter(best))) best = at;
    }
    return best;
  }

  /// The later of two times.
  static DateTime later(DateTime a, DateTime b) => a.isAfter(b) ? a : b;

  /// True when any incident opened inside the [window] that ends at
  /// [before].
  static bool hasRingWithin(
    Iterable<LocalReminderIncident> incidents,
    DateTime before,
    Duration window,
  ) {
    for (final incident in incidents) {
      final opened = incident.openedAt;
      if (opened == null) continue;
      if (opened.isBefore(before) && before.difference(opened) < window) {
        return true;
      }
    }
    return false;
  }
}
