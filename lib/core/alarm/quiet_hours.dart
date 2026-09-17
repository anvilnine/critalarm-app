import 'package:flutter/foundation.dart';

/// The quiet hours window, and the one decision it drives: does this page ring.
///
/// `ios/Shared/Alarm/QuietHours.swift` is the other half. Two different pieces
/// of code decide to ring, the app on the background-push path and the
/// notification extension on the other one, so each has to reach the same
/// answer on its own. Change the rules in both together.
@immutable
final class QuietHours {
  const QuietHours({
    required this.isEnabled,
    required this.startMinutes,
    required this.endMinutes,
    required this.criticalRingsThrough,
  });

  /// What a device with nothing saved yet runs. The same four values are the
  /// fallback in `QuietHours.swift`, so the app and the extension agree before
  /// the first save has happened.
  static const QuietHours defaults = QuietHours(
    isEnabled: true,
    startMinutes: defaultStartMinutes,
    endMinutes: defaultEndMinutes,
    criticalRingsThrough: true,
  );

  /// 22:00 and 07:00, which is what the settings row read before anything
  /// saved a window.
  static const int defaultStartMinutes = 22 * 60;
  static const int defaultEndMinutes = 7 * 60;

  static const int minutesPerDay = 24 * 60;

  /// A page at this priority or above is critical.
  ///
  /// api.md 1.7: a priority-5 message on a critical topic is what opens,
  /// joins or reopens an incident, so 5 is the pager case. There is no
  /// separate critical flag on the push, and the iOS extension reads the same
  /// number off `IncidentPush.priority`.
  static const int criticalPriority = 5;

  final bool isEnabled;

  /// Minutes from local midnight. 22:00 is 1320.
  final int startMinutes;

  /// Minutes from local midnight. 07:00 is 420.
  final int endMinutes;

  /// The switch that makes quiet hours mean something for a pager. On, a
  /// critical page rings whatever the clock says.
  final bool criticalRingsThrough;

  QuietHours copyWith({
    bool? isEnabled,
    int? startMinutes,
    int? endMinutes,
    bool? criticalRingsThrough,
  }) => QuietHours(
    isEnabled: isEnabled ?? this.isEnabled,
    startMinutes: startMinutes ?? this.startMinutes,
    endMinutes: endMinutes ?? this.endMinutes,
    criticalRingsThrough: criticalRingsThrough ?? this.criticalRingsThrough,
  );

  /// True when [minuteOfDay] falls inside the window.
  ///
  /// A window that wraps past midnight is the normal case: 22:00 to 07:00 is
  /// start 1320 and end 420, and both 23:30 and 02:00 are inside it. The start
  /// minute is inside, the end minute is outside.
  ///
  /// Start equal to end is an empty window, not a whole day. A day of silence
  /// is what the quiet hours switch being off already does, and a slip of the
  /// picker should not be able to mute the pager around the clock.
  bool containsMinute(int minuteOfDay) {
    if (startMinutes == endMinutes) return false;
    if (startMinutes < endMinutes) {
      return minuteOfDay >= startMinutes && minuteOfDay < endMinutes;
    }
    return minuteOfDay >= startMinutes || minuteOfDay < endMinutes;
  }

  /// True when the ring for a page of [priority] is held at [now].
  ///
  /// Only the ring. The incident still opens, the card still shows and the
  /// list still updates; the caller skips the schedule call and nothing else.
  bool holdsRing({required DateTime now, required int priority}) {
    if (!isEnabled) return false;
    if (priority >= criticalPriority && criticalRingsThrough) return false;
    return containsMinute(minuteOf(now));
  }

  /// Minutes from local midnight for [at].
  static int minuteOf(DateTime at) => at.hour * 60 + at.minute;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is QuietHours &&
          runtimeType == other.runtimeType &&
          isEnabled == other.isEnabled &&
          startMinutes == other.startMinutes &&
          endMinutes == other.endMinutes &&
          criticalRingsThrough == other.criticalRingsThrough;

  @override
  int get hashCode => Object.hash(
    isEnabled,
    startMinutes,
    endMinutes,
    criticalRingsThrough,
  );

  @override
  String toString() =>
      'QuietHours(enabled: $isEnabled, start: $startMinutes, '
      'end: $endMinutes, criticalRingsThrough: $criticalRingsThrough)';
}
