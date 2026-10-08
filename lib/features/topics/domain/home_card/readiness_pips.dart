import 'package:critalarm/features/reliability/domain/entities/reliability_check.dart';
import 'package:critalarm/features/reliability/domain/entities/reliability_state.dart';
import 'package:critalarm/features/reliability/domain/overall_state.dart';
import 'package:flutter/foundation.dart';

/// How one pip on the card looks.
enum PipTone {
  /// A check that passes, or a setup row that is done.
  fine,

  /// A check that needs a look.
  look,

  /// A check that is broken.
  broken,

  /// A setup row not done yet.
  open,
}

/// The checks that exist on this phone. A check with no meaning here is not
/// counted and gets no pip.
Iterable<ReliabilityCheck> _onThisPhone(Iterable<ReliabilityCheck> checks) =>
    checks.where((check) => check.state.isOnThisPhone);

/// One pip per check, in the order the checks were given.
List<PipTone> pipsFor(Iterable<ReliabilityCheck> checks) => [
  for (final check in _onThisPhone(checks))
    switch (check.state) {
      ReliabilityState.fine || ReliabilityState.notOnThisPhone => PipTone.fine,
      ReliabilityState.needsLook => PipTone.look,
      ReliabilityState.broken => PipTone.broken,
    },
];

/// How many checks pass out of how many exist on this phone.
///
/// The total is the number of checks given. It is 6 to 9 on a real phone and
/// is never a fixed number.
@immutable
class ReadinessCount {
  const ReadinessCount({
    required this.fine,
    required this.total,
    required this.worst,
  });

  final int fine;
  final int total;

  /// The state of the worst check, never [ReliabilityState.notOnThisPhone].
  /// [ReliabilityState.fine] for an empty list.
  final ReliabilityState worst;

  @override
  bool operator ==(Object other) =>
      other is ReadinessCount &&
      other.fine == fine &&
      other.total == total &&
      other.worst == worst;

  @override
  int get hashCode => Object.hash(fine, total, worst);

  @override
  String toString() => 'ReadinessCount($fine/$total, $worst)';
}

ReadinessCount readinessCount(Iterable<ReliabilityCheck> checks) {
  final shown = _onThisPhone(checks).toList();
  return ReadinessCount(
    fine: shown.where((c) => c.state == ReliabilityState.fine).length,
    total: shown.length,
    worst: overallReliabilityState(shown),
  );
}

/// The check the card names: the first broken one, else the first that needs
/// a look, in the order the checks were given. Null when none does.
ReliabilityCheck? worstCheck(Iterable<ReliabilityCheck> checks) {
  final shown = _onThisPhone(checks).toList();
  for (final state in const [
    ReliabilityState.broken,
    ReliabilityState.needsLook,
  ]) {
    for (final check in shown) {
      if (check.state == state) return check;
    }
  }
  return null;
}

/// The check whose fix the card offers: the first one that is not fine and
/// has a fix, broken ones before ones that need a look. This is the rule the
/// reliability screen uses for its one primary button. Null when no check
/// that needs attention has a fix.
ReliabilityCheck? checkToFix(Iterable<ReliabilityCheck> checks) {
  final shown = _onThisPhone(checks).toList();
  for (final state in const [
    ReliabilityState.broken,
    ReliabilityState.needsLook,
  ]) {
    for (final check in shown) {
      if (check.state == state && check.fix != null) return check;
    }
  }
  return null;
}
