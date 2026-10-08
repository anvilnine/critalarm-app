import 'package:flutter/foundation.dart';

/// The one line under a topic's name: how many messages came today and when
/// the topic last raised an alarm.
@immutable
class TopicSummary {
  const TopicSummary({
    required this.today,
    required this.hasAnyMessage,
    this.lastAlarmAt,
    this.lastAlarmIsToday = false,
  });

  /// Messages that arrived today, by the phone's calendar.
  final int today;

  /// The topic holds at least one message the screen can show.
  final bool hasAnyMessage;

  /// When the topic last raised an alarm, or null if it never has.
  final DateTime? lastAlarmAt;

  /// [lastAlarmAt] falls on today, so the screen shows a clock time and not a
  /// date.
  final bool lastAlarmIsToday;

  /// Nothing to say: no message and no alarm.
  bool get isEmpty => !hasAnyMessage && lastAlarmAt == null;

  @override
  bool operator ==(Object other) =>
      other is TopicSummary &&
      other.today == today &&
      other.hasAnyMessage == hasAnyMessage &&
      other.lastAlarmAt == lastAlarmAt &&
      other.lastAlarmIsToday == lastAlarmIsToday;

  @override
  int get hashCode =>
      Object.hash(today, hasAnyMessage, lastAlarmAt, lastAlarmIsToday);
}

bool _sameDay(DateTime a, DateTime b) {
  final x = a.toLocal();
  final y = b.toLocal();
  return x.year == y.year && x.month == y.month && x.day == y.day;
}

/// The summary at [now].
///
/// - [messageTimes]: when each message the screen holds arrived.
/// - [lastAlarmAt]: the newest incident the topic has raised, or null.
TopicSummary topicSummaryFor({
  required Iterable<DateTime> messageTimes,
  required DateTime? lastAlarmAt,
  required DateTime now,
}) {
  var today = 0;
  var any = false;
  for (final at in messageTimes) {
    any = true;
    if (_sameDay(at, now)) today++;
  }
  return TopicSummary(
    today: today,
    hasAnyMessage: any,
    lastAlarmAt: lastAlarmAt,
    lastAlarmIsToday: lastAlarmAt != null && _sameDay(lastAlarmAt, now),
  );
}
