import 'package:critalarm/core/time/calendar_days.dart';
import 'package:intl/intl.dart';

/// When something happened, in the one style the app uses for a place that
/// is short on room (a list row, a summary line, a "Made" line).
///
/// - Today: the time alone, 24-hour ("02:41").
/// - The day before: [yesterday], the words the caller got from its strings.
/// - Any earlier day: the day and the month ("8 Oct"), with the year added
///   only when it is not the year of [now] ("8 Oct 2025").
///
/// Both moments are read in the phone's own time. A moment after [now] counts
/// as today, so a clock that runs a little ahead never prints a date.
///
/// A list section header keeps its own long form ("Thursday 8 October").
String formatWhen({
  required DateTime at,
  required DateTime now,
  required String yesterday,
}) {
  final local = at.toLocal();
  final today = now.toLocal();
  final days = calendarDaysBetween(local, today);
  if (days <= 0) return DateFormat.Hm().format(local);
  if (days == 1) return yesterday;
  final pattern = local.year == today.year ? 'd MMM' : 'd MMM y';
  return DateFormat(pattern).format(local);
}
