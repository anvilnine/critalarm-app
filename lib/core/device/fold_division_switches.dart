import 'package:flutter/foundation.dart';
import 'package:foldable_ext/foldable_ext.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The developer switches that make an Android foldable report its hinge as
/// the reserved middle region an iPhone Duo reports, so iPhone Duo layouts
/// can be built and checked on it.
///
/// Kept in preferences, so each is still set after a restart. All three are
/// off until a developer turns them on.
///
/// Only registered in a build that has Developer options, on a platform
/// where a hinge can exist. Store builds never see it.
class DevFoldDivisionSwitches extends ChangeNotifier {
  DevFoldDivisionSwitches(this._prefs)
    : _isOn = _prefs.getBool(divisionKey) ?? false,
      _staysOnFlat = _prefs.getBool(flatKey) ?? false,
      _showsOverlay = _prefs.getBool(overlayKey) ?? false;

  static const divisionKey = 'dev.fold_division.on';
  static const flatKey = 'dev.fold_division.flat';
  static const overlayKey = 'dev.fold_division.overlay';

  final SharedPreferences _prefs;
  bool _isOn;
  bool _staysOnFlat;
  bool _showsOverlay;

  /// Whether the hinge is reported as an iPhone Duo division.
  bool get isOn => _isOn;

  /// Whether the division stays in force with the device lying flat.
  bool get staysOnFlat => _staysOnFlat;

  /// Whether the division and its margins are drawn over the app.
  bool get showsOverlay => _showsOverlay;

  Future<void> setOn({required bool isOn}) async {
    if (isOn == _isOn) return;
    _isOn = isOn;
    notifyListeners();
    await _save(divisionKey, value: isOn);
  }

  Future<void> setStaysOnFlat({required bool staysOnFlat}) async {
    if (staysOnFlat == _staysOnFlat) return;
    _staysOnFlat = staysOnFlat;
    notifyListeners();
    await _save(flatKey, value: staysOnFlat);
  }

  Future<void> setShowsOverlay({required bool showsOverlay}) async {
    if (showsOverlay == _showsOverlay) return;
    _showsOverlay = showsOverlay;
    notifyListeners();
    await _save(overlayKey, value: showsOverlay);
  }

  /// Off is the absence of the key, like the other developer switches.
  Future<void> _save(String key, {required bool value}) async {
    if (value) {
      await _prefs.setBool(key, true);
    } else {
      await _prefs.remove(key);
    }
  }
}

/// The division settings a run starts with and keeps: [base] with the
/// division on or off as [switches] say.
///
/// With no switches (a store build, or a platform with no hinge) the
/// division is off. The package's own default is on in a debug build, so
/// this is applied at startup in every build.
FoldDivisionConfig foldDivisionConfigFor(
  FoldDivisionConfig base,
  DevFoldDivisionSwitches? switches,
) => base.copyWith(
  enabled: switches?.isOn ?? false,
  activation: (switches?.staysOnFlat ?? false)
      ? DivisionActivation.always
      : DivisionActivation.followPosture,
);

/// Applies [switches] to the package's division settings now and on every
/// later change of a switch.
void bindFoldDivisionConfig(DevFoldDivisionSwitches? switches) {
  void apply() {
    FoldDivision.config.value = foldDivisionConfigFor(
      FoldDivision.config.value,
      switches,
    );
  }

  apply();
  switches?.addListener(apply);
}
