import 'package:critalarm/features/reliability/domain/proof/proof_entry.dart';

/// How many weeks the log keeps.
const proofKeepWeeks = 12;

/// How many weeks the card draws.
const proofShownWeeks = 8;

/// Eight weeks ending with the week of [now], oldest first.
///
/// A week with a `rangAt` is [ProofMark.rang], else one with a `failedAt` is
/// [ProofMark.failed], else [ProofMark.none]. A time after [now] (a clock
/// that was set back) counts for nothing, and a week after the week of
/// [now] is never drawn.
List<ProofWeek> proofWeeksFor(
  List<ProofEntry> entries,
  DateTime now, {
  int count = proofShownWeeks,
}) {
  final current = proofWeekStart(now);
  final byWeek = {for (final entry in entries) entry.key: entry};
  bool counts(DateTime? at) => at != null && !at.isAfter(now);
  return [
    for (var back = count - 1; back >= 0; back--)
      () {
        final monday = DateTime(
          current.year,
          current.month,
          current.day - 7 * back,
        );
        final entry = byWeek[proofWeekKey(monday)];
        final mark = entry == null
            ? ProofMark.none
            : counts(entry.rangAt)
            ? ProofMark.rang
            : counts(entry.failedAt)
            ? ProofMark.failed
            : ProofMark.none;
        return ProofWeek(monday: monday, mark: mark);
      }(),
  ];
}

/// Adds [event] to [entries]: one entry per week, oldest first, cut to the
/// newest [proofKeepWeeks].
///
/// Inside a week a later time of the same kind replaces an earlier one. The
/// two kinds are kept side by side and [proofWeeksFor] lets `rang` win, so a
/// failed test never takes a rang week back.
List<ProofEntry> proofMerge(List<ProofEntry> entries, ProofEntry event) {
  final merged = <String, ProofEntry>{
    for (final entry in entries) entry.key: entry,
  };
  final held = merged[event.key];
  merged[event.key] = held == null
      ? event
      : ProofEntry(
          weekStart: held.weekStart,
          rangAt: _later(held.rangAt, event.rangAt),
          failedAt: _later(held.failedAt, event.failedAt),
        );
  return proofPrune(merged.values.toList());
}

/// [entries] sorted oldest first and cut to the newest [proofKeepWeeks].
List<ProofEntry> proofPrune(List<ProofEntry> entries) {
  final sorted = [...entries]
    ..sort((a, b) => a.weekStart.compareTo(b.weekStart));
  if (sorted.length <= proofKeepWeeks) return sorted;
  return sorted.sublist(sorted.length - proofKeepWeeks);
}

DateTime? _later(DateTime? a, DateTime? b) {
  if (a == null) return b;
  if (b == null) return a;
  return b.isAfter(a) ? b : a;
}

/// How many of [weeks] rang.
int proofRangCount(List<ProofWeek> weeks) =>
    weeks.where((week) => week.mark == ProofMark.rang).length;

/// The newest time something rang, or null when nothing did. With [now], a
/// time after it is left out.
DateTime? proofNewestRangAt(List<ProofEntry> entries, {DateTime? now}) {
  DateTime? newest;
  for (final entry in entries) {
    final at = entry.rangAt;
    if (at == null || (now != null && at.isAfter(now))) continue;
    if (newest == null || at.isAfter(newest)) newest = at;
  }
  return newest;
}
