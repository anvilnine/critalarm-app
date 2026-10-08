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
    if (_isOwnServer && rule.onOwnServer == OwnServerRule.open) {
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

  /// Only Crit Alarm Cloud has plans. Every other known mode is a server of
  /// the user's own.
  bool get _isOwnServer =>
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
