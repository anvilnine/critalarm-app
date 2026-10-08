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
