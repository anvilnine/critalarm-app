import 'package:flutter/foundation.dart';

/// What one week of the proof card shows.
enum ProofMark {
  /// Nothing was recorded that week.
  none,

  /// A test alarm or a weekly check reached this phone.
  rang,

  /// A test was sent and did not get through.
  failed,
}

/// What the phone wrote down for one week.
///
/// [weekStart] is the Monday of the week as a local date at 00:00. It is
/// built from year, month and day and never by adding hours, so a clock
/// change cannot move it. Times are whole seconds.
@immutable
final class ProofEntry {
  ProofEntry({required DateTime weekStart, this.rangAt, this.failedAt})
    : weekStart = DateTime(weekStart.year, weekStart.month, weekStart.day);

  /// An entry that says something rang at [at], in the week of [at].
  factory ProofEntry.rang(DateTime at) {
    final whole = _wholeSeconds(at);
    return ProofEntry(weekStart: proofWeekStart(whole), rangAt: whole);
  }

  /// An entry that says a test failed at [at], in the week of [at].
  factory ProofEntry.failed(DateTime at) {
    final whole = _wholeSeconds(at);
    return ProofEntry(weekStart: proofWeekStart(whole), failedAt: whole);
  }

  final DateTime weekStart;

  /// The latest time something rang in this week, or null.
  final DateTime? rangAt;

  /// The latest time a test failed in this week, or null.
  final DateTime? failedAt;

  /// `YYYY-MM-DD` of [weekStart]. The key one entry per week is kept under.
  String get key => proofWeekKey(weekStart);

  @override
  bool operator ==(Object other) =>
      other is ProofEntry &&
      other.weekStart == weekStart &&
      other.rangAt == rangAt &&
      other.failedAt == failedAt;

  @override
  int get hashCode => Object.hash(weekStart, rangAt, failedAt);

  @override
  String toString() => 'ProofEntry($key, rang: $rangAt, failed: $failedAt)';
}

/// One of the weeks the proof card draws.
@immutable
final class ProofWeek {
  const ProofWeek({required this.monday, required this.mark});

  /// Local date at 00:00.
  final DateTime monday;
  final ProofMark mark;

  @override
  bool operator ==(Object other) =>
      other is ProofWeek && other.monday == monday && other.mark == mark;

  @override
  int get hashCode => Object.hash(monday, mark);

  @override
  String toString() => 'ProofWeek(${proofWeekKey(monday)}, ${mark.name})';
}

DateTime _wholeSeconds(DateTime at) {
  final local = at.toLocal();
  return DateTime.fromMillisecondsSinceEpoch(
    local.millisecondsSinceEpoch ~/ 1000 * 1000,
  );
}

/// The Monday 00:00, local time, of the week that holds [at].
///
/// Built from year, month and day, so a week with a clock change in it is
/// still seven calendar days and the result is always midnight.
DateTime proofWeekStart(DateTime at) {
  final local = at.toLocal();
  return DateTime(local.year, local.month, local.day - (local.weekday - 1));
}

/// `YYYY-MM-DD` for a local date.
String proofWeekKey(DateTime day) {
  String pad(int n, int width) => n.toString().padLeft(width, '0');
  return '${pad(day.year, 4)}-${pad(day.month, 2)}-${pad(day.day, 2)}';
}

/// The date `YYYY-MM-DD` names, or null when [key] is not a real date.
DateTime? proofWeekFromKey(Object? key) {
  if (key is! String) return null;
  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(key);
  if (match == null) return null;
  final year = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  final day = int.parse(match.group(3)!);
  final date = DateTime(year, month, day);
  if (date.year != year || date.month != month || date.day != day) return null;
  return date;
}
