import 'package:critalarm/core/alarm/ring_claim.dart';
import 'package:flutter/foundation.dart';

/// Which phone the priorities page is describing. Each one reads its own
/// lines, so a line for one cannot leak a promise onto another.
enum PriorityPhone {
  /// iOS 26 or later: a critical page is an AlarmKit alarm.
  iosAlarm,

  /// iOS 16 to 25: a critical page is a Time-Sensitive notification with
  /// sound, and the silent switch mutes it.
  iosTimeSensitive,

  /// Android: a critical page opens the full-screen alarm.
  android,
}

/// Picks the phone from values, so no screen asks the platform itself.
/// [claim] is what `RingClaim.forPhone` answered for this phone.
PriorityPhone priorityPhoneFor({
  required TargetPlatform platform,
  required bool isWeb,
  required RingClaim claim,
}) {
  if (!isWeb && platform == TargetPlatform.iOS) {
    return claim == RingClaim.timeSensitive
        ? PriorityPhone.iosTimeSensitive
        : PriorityPhone.iosAlarm;
  }
  return PriorityPhone.android;
}

/// What a priority does on one phone. Each value is one line on the page.
enum PriorityLine {
  /// Android, priority 5 on a critical topic.
  alarmAndroid,

  /// iOS 26 or later, priority 5 on a critical topic.
  alarmIos,

  /// iOS 16 to 25, priority 5 on a critical topic.
  timeSensitiveIos,

  /// Android, priority 4.
  notificationAndroid,

  /// iOS, priority 4. A Time-Sensitive notification on every iOS version.
  notificationIos,

  /// Priority 1 to 3. The server keeps them off the push relay. The app
  /// reads them when it opens or is pulled to refresh.
  historyOnly;

  /// True for the lines that ring. Only these have a sound to hear.
  bool get rings =>
      this == alarmAndroid || this == alarmIos || this == timeSensitiveIos;
}

/// One entry on the page.
@immutable
class PriorityEntry {
  const PriorityEntry(this.priority, this.line);

  /// 1 to 5.
  final int priority;
  final PriorityLine line;

  /// Whether this entry gets the "hear it" control.
  bool get canHearIt => line.rings;

  @override
  bool operator ==(Object other) =>
      other is PriorityEntry &&
      other.priority == priority &&
      other.line == line;

  @override
  int get hashCode => Object.hash(priority, line);

  @override
  String toString() => 'PriorityEntry($priority, $line)';
}

/// The five entries for [phone], priority 5 first.
///
/// From api.md section 1.7: priority 5 on a critical topic opens an incident
/// and repeats. Priority 4 is forwarded as a Time-Sensitive or high priority
/// notification. Priority 1 to 3 never leave the server except through the
/// app's own poll.
List<PriorityEntry> priorityEntriesFor(PriorityPhone phone) {
  final (ring, notify) = switch (phone) {
    PriorityPhone.android => (
      PriorityLine.alarmAndroid,
      PriorityLine.notificationAndroid,
    ),
    PriorityPhone.iosAlarm => (
      PriorityLine.alarmIos,
      PriorityLine.notificationIos,
    ),
    PriorityPhone.iosTimeSensitive => (
      PriorityLine.timeSensitiveIos,
      PriorityLine.notificationIos,
    ),
  };
  return [
    PriorityEntry(5, ring),
    PriorityEntry(4, notify),
    const PriorityEntry(3, PriorityLine.historyOnly),
    const PriorityEntry(2, PriorityLine.historyOnly),
    const PriorityEntry(1, PriorityLine.historyOnly),
  ];
}
