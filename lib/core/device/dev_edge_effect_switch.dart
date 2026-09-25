import 'package:critalarm/design_system/edge_effect.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The developer picker that pins the list edges to one [EdgeEffect].
///
/// Only a `--dart-define=SKIP_PAYWALL=true` build registers this. Null means
/// the device decides through [autoEdgeEffect], which is what a store build
/// always does.
class DevEdgeEffectSwitch extends ValueNotifier<EdgeEffect?> {
  DevEdgeEffectSwitch(this._prefs, {required this.auto})
    : super(EdgeEffect.fromKey(_prefs.getString(_key)));

  static const _key = 'dev.edge_effect';

  /// What this device picks on its own, shown next to the choices.
  final EdgeEffect auto;

  /// The effect the screens should draw right now.
  EdgeEffect get effective => value ?? auto;

  final SharedPreferences _prefs;

  /// Pins the edges to [effect], or hands them back to the device when
  /// [effect] is null. Remembered across launches.
  Future<void> setEffect(EdgeEffect? effect) async {
    value = effect;
    if (effect == null) {
      await _prefs.remove(_key);
      return;
    }
    await _prefs.setString(_key, effect.key);
  }
}
