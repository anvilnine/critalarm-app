import 'dart:async';

import 'package:critalarm/core/access/app_feature.dart';
import 'package:critalarm/core/access/feature_decision.dart';
import 'package:critalarm/core/access/holding.dart';
import 'package:critalarm/core/access/holdings.dart';
import 'package:critalarm/core/api/api_session.dart';

/// The one place that turns holdings into a yes or no for a feature.
///
/// It reads three things and nothing else: the feature table, [Holdings]
/// and the server mode. It keeps the last server mode it was told, so
/// [can] and [decide] are synchronous.
final class FeatureAccess {
  FeatureAccess({
    required this._holdings,
    this._table = featureTable,
    this._serverMode,
    this._serverModeRead,
  }) {
    _last = _decideAll();
    _subscription = _holdings.stream.listen((_) => _announce());
  }

  final Holdings _holdings;
  final Map<AppFeature, FeatureRule> _table;
  final _changes = StreamController<AppFeature>.broadcast();
  late final StreamSubscription<Set<Holding>> _subscription;
  late Map<AppFeature, FeatureDecision> _last;
  ServerMode? _serverMode;
  final Future<void>? _serverModeRead;

  /// Done once the holdings are current and the saved server mode has been
  /// read. Never fails.
  ///
  /// Before that an answer can say "locked" for something that is open:
  /// a tier not read yet counts as not held, and a mode not read yet
  /// counts as Crit Alarm Cloud. A screen that only draws a lock can skip
  /// the wait and listen to [changes]. Code that takes something away, or
  /// that decides once and does not look again, waits for this first.
  Future<void> get ready async {
    await _holdings.ready;
    try {
      await _serverModeRead;
    } on Object catch (_) {
      // A mode that could not be read stays unknown.
    }
  }

  /// [decide], asked once [ready] is done. For a caller that decides once
  /// and does not listen to [changes], and for one that takes something
  /// away.
  Future<FeatureDecision> decideOnceReady(AppFeature feature) async {
    await ready;
    return decide(feature);
  }

  /// [can], asked once [ready] is done. See [decideOnceReady].
  Future<bool> canOnceReady(AppFeature feature) async =>
      (await decideOnceReady(feature)).isUsable;

  /// The mode last handed to [setServerMode]. Null while it is not known.
  ServerMode? get serverMode => _serverMode;

  /// Whether [feature] may be used now. True while a purchase that unlocks
  /// it is waiting to be confirmed.
  bool can(AppFeature feature) => decide(feature).isUsable;

  FeatureDecision decide(AppFeature feature) {
    final rule = _table[feature];
    // A feature with no row is open to everyone.
    if (rule == null || rule.unlockedBy.isEmpty) {
      return const FeatureDecision.open();
    }
    if (isOwnServer && rule.onOwnServer == OwnServerRule.open) {
      return const FeatureDecision.open();
    }
    Holding? waiting;
    for (final holding in rule.unlockedBy) {
      switch (_holdings.stateOf(holding)) {
        case HoldingState.held:
          return const FeatureDecision.open();
        case HoldingState.pending:
          waiting ??= holding;
        case HoldingState.notHeld:
          break;
      }
    }
    return waiting == null
        ? FeatureDecision.locked(rule.unlockedBy.first)
        : FeatureDecision.confirming(waiting);
  }

  /// What [decide] answers for [feature] here when nothing is held: the
  /// lock, with the holding to sell.
  ///
  /// For a place that is locked by something other than the holdings and
  /// still has to open the right paywall: a row the relay refused, a row
  /// drawn locked while a purchase is being confirmed.
  FeatureDecision decideHoldingNothing(AppFeature feature) {
    final rule = _table[feature];
    if (rule == null || rule.unlockedBy.isEmpty) {
      return const FeatureDecision.open();
    }
    if (isOwnServer && rule.onOwnServer == OwnServerRule.open) {
      return const FeatureDecision.open();
    }
    return FeatureDecision.locked(rule.unlockedBy.first);
  }

  /// Each feature whose [decide] answer changed, once per change. Read
  /// [decide] for the value to start from.
  Stream<AppFeature> get changes => _changes.stream;

  /// Takes the mode of the server this phone is connected to. Null means it
  /// is not known, and that answers as Crit Alarm Cloud.
  void setServerMode(ServerMode? mode) {
    if (mode == _serverMode) return;
    _serverMode = mode;
    _announce();
  }

  /// Whether this phone is on a server of the user's own. Only Crit Alarm
  /// Cloud has plans, and every other known mode is such a server.
  ///
  /// For wording only ("no plans on your own server"). Whether a feature
  /// is open there is [decide]'s answer, from the table.
  bool get isOwnServer =>
      _serverMode != null && _serverMode != ServerMode.hosted;

  Map<AppFeature, FeatureDecision> _decideAll() => {
    for (final feature in AppFeature.values) feature: decide(feature),
  };

  void _announce() {
    final now = _decideAll();
    final before = _last;
    _last = now;
    if (_changes.isClosed) return;
    for (final feature in AppFeature.values) {
      if (now[feature] != before[feature]) _changes.add(feature);
    }
  }

  Future<void> dispose() async {
    await _subscription.cancel();
    await _changes.close();
  }
}
