import 'dart:async';

import 'package:critalarm/core/access/app_feature.dart';
import 'package:critalarm/core/access/feature_decision.dart';
import 'package:critalarm/core/access/holding.dart';
import 'package:critalarm/core/access/holdings.dart';
import 'package:critalarm/core/access/own_server.dart';
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
  /// counts as Crit Alarm Cloud. For the same reason "not offered" is never
  /// said early. A screen that only draws a lock can skip the wait and
  /// listen to [changes]. Code that takes something away, or that decides
  /// once and does not look again, waits for this first.
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
  ///
  /// Throws [HoldingUnreadable] where [decide] would answer
  /// [FeatureUnread]: nobody knows, and a caller that would lock, trim or
  /// remove something on "no" catches it and does none of those.
  Future<FeatureDecision> decideOnceReady(AppFeature feature) async {
    await ready;
    final decision = decide(feature);
    if (decision is FeatureUnread) throw HoldingUnreadable(decision.holding);
    return decision;
  }

  /// [isOwnServer], asked once the saved server mode has been read.
  Future<bool> isOwnServerOnceReady() async {
    try {
      await _serverModeRead;
    } on Object catch (_) {
      // A mode that could not be read stays unknown.
    }
    return isOwnServer;
  }

  /// Whether [feature] may be drawn as usable, asked once [ready] is done.
  /// Never throws: when nobody knows, the answer is yes.
  ///
  /// For a screen that draws from the answer and would otherwise trim a
  /// list, hide a section or show a count card with an offer on it. Code
  /// that writes a lock somewhere, or takes something away, asks
  /// [canOnceReady] and handles [HoldingUnreadable] itself.
  Future<bool> usableOnceReady(AppFeature feature) async {
    await ready;
    return decide(feature).isUsable;
  }

  /// [can], asked once [ready] is done. Throws [HoldingUnreadable] when
  /// nobody knows. See [decideOnceReady].
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
    final here = _onThisServer(rule);
    if (here != null) return here;
    Holding? waiting;
    Holding? unread;
    for (final holding in rule.unlockedBy) {
      switch (_holdings.stateOf(holding)) {
        case HoldingState.held:
          return const FeatureDecision.open();
        case HoldingState.pending:
          waiting ??= holding;
        case HoldingState.unknown:
          unread ??= holding;
        case HoldingState.notHeld:
          break;
      }
    }
    if (waiting != null) return FeatureDecision.confirming(waiting);
    // One of the holdings that would unlock it could not be read. That is
    // never a lock.
    if (unread != null) return FeatureDecision.unread(unread);
    return FeatureDecision.locked(rule.offered);
  }

  /// What the server this phone is on settles by itself, before anything
  /// held is looked at. Null where the holdings decide.
  FeatureDecision? _onThisServer(FeatureRule rule) {
    if (!isOwnServer) return null;
    return switch (rule.onOwnServer) {
      OwnServerRule.open => const FeatureDecision.open(),
      OwnServerRule.notOffered => const FeatureDecision.notOffered(),
      OwnServerRule.sameAsCloud => null,
    };
  }

  /// What [decide] answers for [feature] here when nothing is held: the
  /// lock, with the holding to sell. Where the server settles it, that
  /// answer: open, or not offered.
  ///
  /// For a place that is locked by something other than the holdings and
  /// still has to open the right paywall: a row the relay refused, a row
  /// drawn locked while a purchase is being confirmed.
  FeatureDecision decideHoldingNothing(AppFeature feature) {
    final rule = _table[feature];
    if (rule == null || rule.unlockedBy.isEmpty) {
      return const FeatureDecision.open();
    }
    return _onThisServer(rule) ?? FeatureDecision.locked(rule.offered);
  }

  /// Each feature whose [decide] answer changed, once per change. Read
  /// [decide] for the value to start from.
  Stream<AppFeature> get changes => _changes.stream;

  /// Takes the mode of the server this phone is connected to. Null means it
  /// is not known, and that answers as Crit Alarm Cloud. See [isOwnServer].
  void setServerMode(ServerMode? mode) {
    if (mode == _serverMode) return;
    _serverMode = mode;
    _announce();
  }

  /// Whether this phone is on a server of the user's own: the mode is
  /// `selfhosted` and nothing else.
  ///
  /// Crit Alarm Cloud (`hosted`) has plans. So does a server that reports
  /// `relay`: it is the relay itself, with accounts, tiers and caps. A mode
  /// that is not known yet is treated the same. All three follow what is
  /// held.
  ///
  /// The one definition of "own server" for anything about plans: whether
  /// a feature is open there is [decide]'s answer, and wording such as "no
  /// plans on your own server" reads this.
  bool get isOwnServer => isOwnServerMode(_serverMode);

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
