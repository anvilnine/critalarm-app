import 'package:critalarm/core/access/dev_access_switches.dart';
import 'package:critalarm/core/access/holding.dart';
import 'package:flutter/foundation.dart';

/// The Hosted toggle in the developer section of Settings.
///
/// It keeps nothing of its own. On is "force Hosted to held" and off is
/// "release Hosted" on [DevAccessSwitches], the one store behind every
/// developer plan switch, so the toggle and the Plans and features lab can
/// never disagree.
///
/// Only registered when the app was built with
/// --dart-define=SKIP_PAYWALL=true. Store builds never see it.
class DevProSwitch implements ValueListenable<bool> {
  DevProSwitch(this._switches);

  final DevAccessSwitches _switches;

  ValueListenable<bool> get _held => _switches.forcedHeld(Holding.hosted);

  @override
  bool get value => _held.value;

  @override
  void addListener(VoidCallback listener) => _held.addListener(listener);

  @override
  void removeListener(VoidCallback listener) => _held.removeListener(listener);

  /// Forces Hosted to held, or hands it back to its source. Remembered
  /// across launches.
  Future<void> setPro({required bool isPro}) =>
      _switches.force(Holding.hosted, isPro ? HoldingState.held : null);
}
