import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The user's Interface sounds switch in Settings. On until they turn it off.
///
/// It covers the short sounds the app plays for its own screens, and the
/// light tap that goes with each. It has nothing to do with an alarm: the
/// alarm sound, its volume and its vibration are not read or changed here.
final class InterfaceSoundsSetting {
  InterfaceSoundsSetting(this._prefs)
    : _isOn = ValueNotifier(_prefs.getBool(prefsKey) ?? true);

  static const String prefsKey = 'interface_sounds_enabled';

  final SharedPreferences _prefs;
  final ValueNotifier<bool> _isOn;

  bool get isOn => _isOn.value;

  /// For a row that redraws when the choice changes.
  ValueListenable<bool> get listenable => _isOn;

  /// Applies the choice at once and then saves it.
  Future<void> set({required bool isOn}) async {
    _isOn.value = isOn;
    await _prefs.setBool(prefsKey, isOn);
  }
}
