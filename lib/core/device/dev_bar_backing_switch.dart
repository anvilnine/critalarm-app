import 'package:critalarm/design_system/bar_backing.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The developer override for how the bars are backed.
///
/// Only a build with Developer options registers this, so a store build
/// never reads the preference and always draws
/// [BarBackingConfig.defaults].
class DevBarBackingSwitch extends ValueNotifier<BarBackingConfig> {
  DevBarBackingSwitch(this._prefs)
    : super(BarBackingConfig.decode(_prefs.getString(prefsKey)));

  static const prefsKey = 'dev.bar_backing';

  final SharedPreferences _prefs;

  /// Whether anything differs from what ships.
  bool get isOverridden => value != BarBackingConfig.defaults;

  /// Draws every bar with [config] from now on. Remembered across launches.
  Future<void> setConfig(BarBackingConfig config) async {
    value = config;
    if (config == BarBackingConfig.defaults) {
      await _prefs.remove(prefsKey);
      return;
    }
    await _prefs.setString(prefsKey, config.encode());
  }

  /// Back to what ships.
  Future<void> reset() => setConfig(BarBackingConfig.defaults);
}
