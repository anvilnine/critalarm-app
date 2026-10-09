import 'dart:async';

import 'package:critalarm/features/reliability/domain/proof/proof_entry.dart';
import 'package:critalarm/features/reliability/domain/proof/proof_log_store.dart';
import 'package:critalarm/features/reliability/domain/proof/proof_weeks.dart';

/// The phone's own record of the weeks an alarm or a check got through.
///
/// Nothing here goes to the server. Callers that only observe an alarm or a
/// check wrap a call in a `try` of their own: a log that cannot be written
/// must not stop either.
final class ProofLog {
  ProofLog(this._store, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final ProofLogStore _store;
  final DateTime Function() _now;
  final _changes = StreamController<void>.broadcast();

  // Writes run one after the other, so two marks that arrive together both
  // land.
  Future<void> _tail = Future<void>.value();

  /// Fires after the log changed.
  Stream<void> get changes => _changes.stream;

  /// Something rang at [at].
  Future<void> markRang(DateTime at) => add(ProofEntry.rang(at));

  /// A test failed at [at].
  Future<void> markFailed(DateTime at) => add(ProofEntry.failed(at));

  /// Merges [event] into the log. Writes nothing when it adds nothing new.
  Future<void> add(ProofEntry event) {
    final run = _tail.then((_) async {
      final before = _store.read();
      final after = proofMerge(before, event);
      if (_sameEntries(before, after)) return;
      await _store.write(after);
      if (!_changes.isClosed) _changes.add(null);
    });
    // A failed write reaches the caller through [run], and the queue goes on.
    _tail = run.then((_) {}, onError: (Object _) {});
    return run;
  }

  /// Eight weeks ending with the week of [now], oldest first.
  List<ProofWeek> weeks(DateTime now) => proofWeeksFor(_store.read(), now);

  /// The newest time something rang, or null.
  DateTime? newestRangAt() => proofNewestRangAt(_store.read(), now: _now());

  /// Drops the log. For the account's other local data going too.
  Future<void> clear() async {
    await _store.clear();
    if (!_changes.isClosed) _changes.add(null);
  }

  Future<void> dispose() => _changes.close();

  static bool _sameEntries(List<ProofEntry> a, List<ProofEntry> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
