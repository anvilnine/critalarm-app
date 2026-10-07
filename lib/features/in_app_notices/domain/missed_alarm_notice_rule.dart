import 'package:critalarm/features/reliability/domain/missed_alarm/missed_alarm_reader.dart';
import 'package:critalarm/features/reliability/domain/missed_alarm/missed_alarm_rule.dart';
import 'package:flutter/foundation.dart';

/// What Home's missed alarm entry says: how many, and the newest one.
@immutable
class MissedAlarmNotice {
  const MissedAlarmNotice({
    required this.incidentIds,
    required this.topic,
    required this.at,
    required this.reason,
  });

  /// Every missed alarm the entry stands for. Closing it closes them all.
  final List<String> incidentIds;

  /// The newest one's topic, time and reason.
  final String topic;
  final DateTime at;
  final MissedReason reason;

  int get count => incidentIds.length;

  @override
  bool operator ==(Object other) =>
      other is MissedAlarmNotice &&
      listEquals(other.incidentIds, incidentIds) &&
      other.topic == topic &&
      other.at == at &&
      other.reason == reason;

  @override
  int get hashCode =>
      Object.hash(Object.hashAll(incidentIds), topic, at, reason);
}

/// Answers "should Home show the missed alarm entry, and what does it say".
///
/// It shows when every one of these holds:
///
/// - setup is done (`SetupGate`), like every other notice;
/// - at least one missed alarm ran out in the last [missedAlarmWindow];
/// - that alarm's entry was not closed.
///
/// Several missed alarms are one entry with a count. Closing it stores every
/// id it stood for, and a stored id never shows again.
///
/// It is a card on Home. It is not a notification and it makes no alert.
abstract final class MissedAlarmNoticeRule {
  static MissedAlarmNotice? noticeFor({
    required bool isSetupDone,
    required Iterable<MissedAlarm>? missed,
    required Set<String> dismissedIds,
    required DateTime now,
  }) {
    if (!isSetupDone || missed == null) return null;
    final shown = missedAlarmsToShow(
      missed: missed,
      dismissedIds: dismissedIds,
      now: now,
    );
    if (shown.isEmpty) return null;
    final newest = shown.first;
    return MissedAlarmNotice(
      incidentIds: [for (final alarm in shown) alarm.incidentId],
      topic: newest.topic,
      at: newest.at,
      reason: newest.reason,
    );
  }
}
