import 'dart:async';

import 'package:critalarm/core/access/holding.dart';
import 'package:flutter/foundation.dart';

/// What this install holds: Hosted, Pro, both or neither.
///
/// Read only. Buying and restoring stay where they are. After a purchase the
/// source changes and [stream] announces it.
///
/// Every read asks the sources at that moment, so an answer is never older
/// than the source's own.
final class Holdings {
  Holdings(List<HoldingSource> sources)
    : _sources = List.unmodifiable(sources) {
    _last = _read();
    for (final source in _sources) {
      source.changes.addListener(_sourceChanged);
    }
  }

  final List<HoldingSource> _sources;
  final _changes = StreamController<Set<Holding>>.broadcast();
  late Map<Holding, HoldingState> _last;

  /// Every holding that is [HoldingState.held] or [HoldingState.pending].
  /// A holding that could not be read is left out. Ask [isUnknown] before
  /// treating "not in the set" as "not held".
  ///
  /// A pending purchase counts, the same way the app already shows a plan
  /// the store confirmed before the server did. Ask [stateOf] to tell the
  /// two apart.
  Set<Holding> get held => _heldIn(_read());

  HoldingState stateOf(Holding holding) =>
      _read()[holding] ?? HoldingState.notHeld;

  /// Whether [holding] is held or pending. See [held]. False while it
  /// could not be read, which is not the same as not held: see [isUnknown].
  bool holds(Holding holding) => _counts(stateOf(holding));

  /// Whether [holding] could not be read, so nobody knows if it is held.
  bool isUnknown(Holding holding) => stateOf(holding) == HoldingState.unknown;

  static bool _counts(HoldingState state) =>
      state == HoldingState.held || state == HoldingState.pending;

  /// Done once every source is current. See [HoldingSource.ready].
  Future<void> get ready async {
    for (final source in _sources) {
      await source.ready;
    }
  }

  /// Whether [holding] is held and confirmed: never true for a purchase
  /// that is still pending.
  bool holdsConfirmed(Holding holding) => stateOf(holding) == HoldingState.held;

  /// [holds], asked once every source is current. For a caller that asks
  /// once and does not listen for changes.
  ///
  /// Throws [HoldingUnreadable] when [holding] could not be read. A caller
  /// that would lock, trim or offer something on "false" catches it and
  /// does none of those.
  Future<bool> holdsOnceReady(Holding holding) async {
    await ready;
    if (isUnknown(holding)) throw HoldingUnreadable(holding);
    return holds(holding);
  }

  /// [held], sent each time the set or the state of a holding changes, and
  /// only then. Read [held] for the value to start from.
  Stream<Set<Holding>> get stream => _changes.stream;

  /// The one place that turns what the sources say into what is held.
  ///
  /// It changes nothing today. A rule such as "Hosted includes Pro" would
  /// be one line here.
  static Map<Holding, HoldingState> _resolve(
    Map<Holding, HoldingState> said,
  ) => said;

  Map<Holding, HoldingState> _read() {
    final said = <Holding, HoldingState>{};
    for (final source in _sources) {
      final state = source.state;
      final before = said[source.holding];
      // Two sources for one holding: the stronger answer stands.
      if (before == null || _rank(state) > _rank(before)) {
        said[source.holding] = state;
      }
    }
    return _resolve(said);
  }

  static Set<Holding> _heldIn(Map<Holding, HoldingState> states) => {
    for (final holding in Holding.values)
      if (_counts(states[holding] ?? HoldingState.notHeld)) holding,
  };

  /// A source that knows beats one that does not, and among those that
  /// know the stronger answer stands.
  static int _rank(HoldingState state) => switch (state) {
    HoldingState.notHeld => 1,
    HoldingState.unknown => 0,
    HoldingState.pending => 2,
    HoldingState.held => 3,
  };

  void _sourceChanged() {
    final now = _read();
    if (mapEquals(now, _last) || _changes.isClosed) return;
    _last = now;
    _changes.add(_heldIn(now));
  }

  Future<void> dispose() async {
    for (final source in _sources) {
      source.changes.removeListener(_sourceChanged);
    }
    await _changes.close();
  }
}
