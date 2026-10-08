import 'package:critalarm/core/access/feature_access.dart';
import 'package:critalarm/core/access/holding.dart';
import 'package:critalarm/core/access/holdings.dart';
import 'package:critalarm/core/api/api_session.dart';
import 'package:flutter/foundation.dart';

/// A source the test sets by hand.
class FakeHoldingSource extends ChangeNotifier implements HoldingSource {
  FakeHoldingSource(this.holding, [this._state = HoldingState.notHeld]);

  @override
  final Holding holding;

  HoldingState _state;

  @override
  HoldingState get state => _state;

  @override
  Listenable get changes => this;

  /// Completed unless a test swaps it for one it finishes by hand.
  @override
  Future<void> ready = Future<void>.value();

  /// Changes the state and tells the listeners.
  void set(HoldingState state) {
    _state = state;
    notifyListeners();
  }

  /// Tells the listeners with nothing changed.
  void ringOnly() => notifyListeners();
}

/// Lets everything that is ready to run, run.
Future<void> settle() async {
  for (var i = 0; i < 20; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

/// Holdings and feature access a test sets by hand.
///
/// Starts on Crit Alarm Cloud with the given holdings. Move a holding with
/// `hosted.set` or `pro.set`, and the server with `features.setServerMode`.
class TestAccess {
  TestAccess({
    Set<Holding> held = const {},
    ServerMode? serverMode = ServerMode.hosted,
  }) : hosted = FakeHoldingSource(
         Holding.hosted,
         held.contains(Holding.hosted)
             ? HoldingState.held
             : HoldingState.notHeld,
       ),
       pro = FakeHoldingSource(
         Holding.pro,
         held.contains(Holding.pro) ? HoldingState.held : HoldingState.notHeld,
       ) {
    holdings = Holdings([hosted, pro]);
    features = FeatureAccess(holdings: holdings, serverMode: serverMode);
  }

  final FakeHoldingSource hosted;
  final FakeHoldingSource pro;
  late final Holdings holdings;
  late final FeatureAccess features;

  Future<void> dispose() async {
    await features.dispose();
    await holdings.dispose();
  }
}
