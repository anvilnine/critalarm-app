import 'package:critalarm/features/reliability/domain/entities/reliability_check.dart';
import 'package:critalarm/features/reliability/domain/entities/reliability_state.dart';
import 'package:flutter/foundation.dart';

/// Everything the Reliability screen, and anything else that wants one answer,
/// reads: the checks on this phone and the state that sums them up.
@immutable
final class ReliabilitySnapshot {
  const ReliabilitySnapshot({
    this.checks = const [],
    this.overall = ReliabilityState.fine,
    this.loaded = false,
  });

  /// The checks that exist on this phone, in source order. Checks that are
  /// not on this phone are not here.
  final List<ReliabilityCheck> checks;

  /// Never [ReliabilityState.notOnThisPhone].
  final ReliabilityState overall;

  /// False until the first read ends. Until then [overall] says nothing, so
  /// a screen waits instead of drawing "fine".
  final bool loaded;

  @override
  bool operator ==(Object other) =>
      other is ReliabilitySnapshot &&
      other.overall == overall &&
      other.loaded == loaded &&
      listEquals(other.checks, checks);

  @override
  int get hashCode => Object.hash(overall, loaded, Object.hashAll(checks));
}
