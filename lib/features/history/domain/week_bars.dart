import 'package:critalarm/core/models/incident.dart';
import 'package:critalarm/design/faces/face_meaning.dart';
import 'package:critalarm/design/faces/face_state.dart';
import 'package:critalarm/features/history/domain/entities/history_entry.dart';
import 'package:flutter/foundation.dart';

/// How many days the History chart shows.
const int kWeekBarDays = 7;

/// What a past alarm's row says about how it ended.
enum HistoryMark {
  /// Someone acknowledged it. The server only closes an incident that was
  /// acknowledged first, so a closed one counts too.
  answered,

  /// It rang its full time and nobody answered.
  notAnswered,

  /// It is ringing now.
  ringing,
}

/// The mark for an alarm in [state].
HistoryMark historyMarkFor(IncidentState state) => switch (state) {
  IncidentState.acked || IncidentState.closed => HistoryMark.answered,
  IncidentState.expired => HistoryMark.notAnswered,
  IncidentState.open => HistoryMark.ringing,
};

/// One day of the chart.
@immutable
class WeekBarDay {
  const WeekBarDay({
    required this.day,
    required this.alarms,
    required this.unanswered,
    required this.isToday,
    required this.isHidden,
  });

  /// Local midnight of the day.
  final DateTime day;

  /// Alarms that started this day.
  final int alarms;

  /// Of those, how many nobody answered or are still ringing.
  final int unanswered;

  final bool isToday;

  /// True when the plan's window does not reach this day, so it has no bar.
  final bool isHidden;

  @override
  bool operator ==(Object other) =>
      other is WeekBarDay &&
      other.day == day &&
      other.alarms == alarms &&
      other.unanswered == unanswered &&
      other.isToday == isToday &&
      other.isHidden == isHidden;

  @override
  int get hashCode => Object.hash(day, alarms, unanswered, isToday, isHidden);
}

/// The seven days ending today and the two numbers beside them.
@immutable
class WeekBars {
  const WeekBars({
    required this.days,
    required this.alarms,
    required this.unanswered,
    required this.longestAnswered,
    required this.visibleDays,
    required this.mayBeShort,
  });

  /// Seven days, oldest first. The last one is today.
  final List<WeekBarDay> days;

  /// Alarms across the days the plan shows.
  final int alarms;

  /// Of those, how many nobody answered or are still ringing.
  final int unanswered;

  /// The longest an answered alarm rang before it was answered, or null when
  /// none was answered.
  final Duration? longestAnswered;

  /// How many of the seven days the plan shows. Seven, or fewer on a plan
  /// whose history is shorter than a week.
  final int visibleDays;

  /// True when the phone holds more alarms than it has read, and the oldest
  /// one it has read is still inside the week. The count could be higher.
  final bool mayBeShort;

  /// The face for the chart: look if an alarm in it went unanswered, calm
  /// for a quiet week, and the answered face when every alarm was answered.
  FaceState get face {
    if (unanswered > 0) return needsLookFace;
    if (alarms == 0) return FaceState.calm;
    return FaceState.acked;
  }
}

/// Alarms per local day for the [kWeekBarDays] days ending on [now]'s day.
///
/// - [entries]: what the list shows, so a filter narrows the chart too.
/// - [shownDays]: how far back the plan reaches. A day it does not reach has
///   no bar and counts for nothing.
/// - [hasMore] and [oldestLoaded]: the phone reads its copy a page at a time.
///   When there is another page and the oldest alarm read so far is inside
///   the week, [WeekBars.mayBeShort] says the count could be higher.
///
/// Days are calendar days on the local clock, counted back from today's date
/// rather than by 24 hour steps, so a day that is 23 or 25 hours long is one
/// day.
WeekBars buildWeekBars({
  required List<HistoryEntry> entries,
  required DateTime now,
  required int shownDays,
  bool hasMore = false,
  DateTime? oldestLoaded,
}) {
  final today = DateTime(now.year, now.month, now.day);
  final visible = shownDays.clamp(0, kWeekBarDays);

  final days = <DateTime>[
    for (var i = kWeekBarDays - 1; i >= 0; i--)
      DateTime(today.year, today.month, today.day - i),
  ];
  final indexOf = <int, int>{
    for (final (i, day) in days.indexed) _key(day): i,
  };

  final alarms = List<int>.filled(kWeekBarDays, 0);
  final unanswered = List<int>.filled(kWeekBarDays, 0);
  Duration? longest;

  for (final entry in entries) {
    final i = indexOf[_key(entry.day)];
    if (i == null) continue;
    // Index 6 is today, so a day i is (6 - i) days back.
    if (kWeekBarDays - 1 - i >= visible) continue;
    alarms[i]++;
    switch (historyMarkFor(entry.state)) {
      case HistoryMark.answered:
        final ring = entry.ringDuration;
        if (ring != null && (longest == null || ring > longest)) {
          longest = ring;
        }
      case HistoryMark.notAnswered || HistoryMark.ringing:
        unanswered[i]++;
    }
  }

  final firstShown = days[kWeekBarDays - visible.clamp(1, kWeekBarDays)];
  final short =
      hasMore &&
      visible > 0 &&
      (oldestLoaded == null ||
          !DateTime(
            oldestLoaded.year,
            oldestLoaded.month,
            oldestLoaded.day,
          ).isBefore(firstShown));

  return WeekBars(
    days: [
      for (final (i, day) in days.indexed)
        WeekBarDay(
          day: day,
          alarms: alarms[i],
          unanswered: unanswered[i],
          isToday: i == kWeekBarDays - 1,
          isHidden: kWeekBarDays - 1 - i >= visible,
        ),
    ],
    alarms: alarms.fold(0, (a, b) => a + b),
    unanswered: unanswered.fold(0, (a, b) => a + b),
    longestAnswered: longest,
    visibleDays: visible,
    mayBeShort: short,
  );
}

int _key(DateTime day) => day.year * 10000 + day.month * 100 + day.day;
