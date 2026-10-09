import 'package:critalarm/core/access/dev_access_switches.dart';
import 'package:critalarm/core/access/holding.dart';
import 'package:critalarm/features/pro_pack/domain/pro_pack_override.dart';
import 'package:flutter/foundation.dart';

/// The Developer options toggle for the Pro pack.
///
/// It keeps nothing of its own. On is "force Pro to held" and off is
/// "release Pro" on [DevAccessSwitches], the one store behind every
/// developer plan switch, which is what keeps the choice in preferences.
///
/// Only registered when the app was built with
/// --dart-define=SKIP_PAYWALL=true. Store builds never see it.
class PrefsProPackDevSwitch implements ProPackDevSwitch {
  PrefsProPackDevSwitch(this._switches);

  final DevAccessSwitches _switches;

  ValueListenable<bool> get _held => _switches.forcedHeld(Holding.pro);

  @override
  bool get value => _held.value;

  @override
  void addListener(VoidCallback listener) => _held.addListener(listener);

  @override
  void removeListener(VoidCallback listener) => _held.removeListener(listener);

  @override
  Future<void> setHeld({required bool isHeld}) =>
      _switches.force(Holding.pro, isHeld ? HoldingState.held : null);
}
