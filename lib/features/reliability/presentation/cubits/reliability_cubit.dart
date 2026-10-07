import 'dart:async';

import 'package:critalarm/features/reliability/domain/entities/reliability_check.dart';
import 'package:critalarm/features/reliability/domain/entities/reliability_state.dart';
import 'package:critalarm/features/reliability/domain/overall_state.dart';
import 'package:critalarm/features/reliability/domain/reliability_check_source.dart';
import 'package:critalarm/features/reliability/presentation/cubits/reliability_snapshot.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Gathers the checks from every source and works out the overall state.
///
/// It has no list of checks of its own. Each source brings its own, and
/// `lib/app/di.dart` is where the sources are listed. [refresh] reads them
/// all at once. A screen calls it when it opens and when the app comes back.
/// A source that throws leaves the list incomplete and the overall state at
/// needs a look at least.
class ReliabilityCubit extends Cubit<ReliabilitySnapshot> {
  ReliabilityCubit(this._sources) : super(const ReliabilitySnapshot());

  final List<ReliabilityCheckSource> _sources;
  int _generation = 0;

  Future<void> refresh() async {
    final generation = ++_generation;
    final reads = await Future.wait(_sources.map(_readOne));
    // A newer refresh has started, or the cubit is gone. Its answer is the
    // one to keep.
    if (isClosed || generation != _generation) return;
    final checks = [
      for (final read in reads)
        for (final check in read ?? const <ReliabilityCheck>[])
          if (check.state != ReliabilityState.notOnThisPhone) check,
    ];
    final incomplete = reads.any((read) => read == null);
    var overall = overallReliabilityState(checks);
    // A source that could not answer might have been the broken one.
    if (incomplete && overall == ReliabilityState.fine) {
      overall = ReliabilityState.needsLook;
    }
    emit(
      ReliabilitySnapshot(
        checks: List.unmodifiable(checks),
        overall: overall,
        loaded: true,
        incomplete: incomplete,
      ),
    );
  }

  /// A source that throws loses its checks for this read, and the answer is
  /// marked incomplete. It does not turn the others into an error.
  Future<List<ReliabilityCheck>?> _readOne(
    ReliabilityCheckSource source,
  ) async {
    try {
      return await source.read();
    } on Object catch (error) {
      debugPrint('ReliabilityCubit: ${source.runtimeType} failed: $error');
      return null;
    }
  }
}
