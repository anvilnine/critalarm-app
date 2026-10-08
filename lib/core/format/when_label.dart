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

/// When a message was sent, for a row that must always show the time so two
/// messages from the same day stay in order.
///
/// - Today: the time alone, 24-hour ("06:25").
/// - The day before: [yesterday] and the time ("Yesterday 00:45").
/// - Any earlier day: the day, the month and the time ("8 Oct 00:45"), with
///   the year added only when it is not the year of [now]
///   ("8 Oct 2025 00:45").
///
/// Both moments are read in the phone's own time, and a moment after [now]
/// counts as today, as in [formatWhen].
String formatWhenWithTime({
  required DateTime at,
  required DateTime now,
  required String yesterday,
}) {
  final local = at.toLocal();
  final today = now.toLocal();
  final days = calendarDaysBetween(local, today);
  final time = DateFormat.Hm().format(local);
  if (days <= 0) return time;
  if (days == 1) return '$yesterday $time';
  final pattern = local.year == today.year ? 'd MMM' : 'd MMM y';
  return '${DateFormat(pattern).format(local)} $time';
}
