import 'package:critalarm/features/reliability/domain/attention_order.dart';
import 'package:critalarm/features/reliability/domain/entities/reliability_check.dart';
import 'package:critalarm/features/reliability/domain/entities/reliability_fix.dart';
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

/// Where the phone's checks stand, as the one word every screen agrees on.
enum ReadinessKind {
  /// The first read has not ended. Nothing is known yet.
  loading,

  /// Every check that exists on this phone passes.
  fine,

  /// A check needs a look, or a source did not answer.
  look,

  /// A check is broken.
  broken,
}

/// The kind for a read of the checks.
///
/// This is the one rule behind the Topics card and the Settings card. Nothing
/// counts until [loaded]. A broken check beats everything. A read with a hole
/// in it ([incomplete]) is at least a look, never fine.
ReadinessKind readinessKindOf({
  required bool loaded,
  required bool incomplete,
  required Iterable<ReliabilityCheck> checks,
}) {
  if (!loaded) return ReadinessKind.loading;
  if (checks.any((c) => c.state == ReliabilityState.broken)) {
    return ReadinessKind.broken;
  }
  if (incomplete || checks.any((c) => c.state == ReliabilityState.needsLook)) {
    return ReadinessKind.look;
  }
  return ReadinessKind.fine;
}

/// Everything a card needs to say about the checks: the kind, the count, one
/// pip per check, the check to name and the fix to offer.
@immutable
class ReadinessSummary {
  const ReadinessSummary({
    required this.kind,
    required this.count,
    required this.pips,
    required this.isIncomplete,
    this.worst,
    this.fix,
  });

  factory ReadinessSummary.of({
    required bool loaded,
    required bool incomplete,
    required Iterable<ReliabilityCheck> checks,
  }) {
    final kind = readinessKindOf(
      loaded: loaded,
      incomplete: incomplete,
      checks: checks,
    );
    return ReadinessSummary(
      kind: kind,
      count: readinessCount(checks),
      pips: kind == ReadinessKind.loading ? const [] : pipsFor(checks),
      isIncomplete: incomplete,
      worst: worstCheck(checks),
      fix: checkToFix(checks)?.fix,
    );
  }

  final ReadinessKind kind;
  final ReadinessCount count;

  /// Empty until the first read ends.
  final List<PipTone> pips;

  /// A source did not answer, so [count] is missing some checks.
  final bool isIncomplete;

  /// The check to name first, or null when none needs attention.
  final ReliabilityCheck? worst;

  /// The fix of the first check that needs attention and has one.
  final ReliabilityFix? fix;

  /// True when a card names "a check could not run" instead of [worst]: the
  /// read has a hole in it and no check is known to be broken.
  bool get namesMissingCheck => kind == ReadinessKind.look && isIncomplete;

  /// The big figure: `fine/total`, `···` until the first read ends, and `?`
  /// when no check exists on this phone.
  String get numeralText => switch (kind) {
    ReadinessKind.loading => '···',
    _ when count.total == 0 => '?',
    _ => '${count.fine}/${count.total}',
  };
}
