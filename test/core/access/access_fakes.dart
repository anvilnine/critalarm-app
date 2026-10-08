import 'package:critalarm/core/access/holding.dart';
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
