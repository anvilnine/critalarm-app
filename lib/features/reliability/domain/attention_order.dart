import 'package:critalarm/features/reliability/domain/entities/reliability_check.dart';
import 'package:critalarm/features/reliability/domain/entities/reliability_state.dart';

// The one rule for which check comes first. The Reliability screen orders its
// rows with it and the Home card names the same check, so the two cannot
// disagree about what to look at first.

int _rank(ReliabilityState state) => switch (state) {
  ReliabilityState.broken => 0,
  ReliabilityState.needsLook => 1,
  ReliabilityState.fine => 2,
  ReliabilityState.notOnThisPhone => 3,
};

/// The checks that exist on this phone, the ones that need attention first:
/// broken, then needs a look, then fine.
///
/// A check that is not on this phone is dropped. Inside one state the order
/// the sources gave is kept.
List<ReliabilityCheck> orderByAttention(Iterable<ReliabilityCheck> checks) {
  final shown = [
    for (final check in checks)
      if (check.state.isOnThisPhone) check,
  ];
  // List.sort is not stable, so the position breaks ties.
  final indexed = shown.asMap().entries.toList()
    ..sort((a, b) {
      final byState = _rank(a.value.state).compareTo(_rank(b.value.state));
      return byState != 0 ? byState : a.key.compareTo(b.key);
    });
  return [for (final entry in indexed) entry.value];
}

/// Whether [state] asks the user to do something.
bool needsAttention(ReliabilityState state) =>
    state == ReliabilityState.needsLook || state == ReliabilityState.broken;

/// The index in [ordered] of the check whose fix is offered first: the first
/// one that needs attention and has a fix. Null when none does.
///
/// [ordered] comes from [orderByAttention]. It reads the state and the fix
/// only, so a check from any source counts.
int? indexOfFirstFixable(List<ReliabilityCheck> ordered) {
  for (var i = 0; i < ordered.length; i++) {
    final check = ordered[i];
    if (needsAttention(check.state) && check.fix != null) return i;
  }
  return null;
}

/// The check to name first: the first broken one, else the first that needs a
/// look, in the order the checks were given. Null when none does.
ReliabilityCheck? worstCheck(Iterable<ReliabilityCheck> checks) {
  final ordered = orderByAttention(checks);
  if (ordered.isEmpty || !needsAttention(ordered.first.state)) return null;
  return ordered.first;
}

/// The check whose fix is offered: the first one that needs attention and has
/// a fix, broken ones before ones that need a look. Null when no such check
/// has a fix.
ReliabilityCheck? checkToFix(Iterable<ReliabilityCheck> checks) {
  final ordered = orderByAttention(checks);
  final index = indexOfFirstFixable(ordered);
  return index == null ? null : ordered[index];
}
