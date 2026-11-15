import 'package:flutter/foundation.dart';
import 'package:foldable_ext/foldable_ext.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The developer switches that make an Android foldable render the app as
/// an iPhone Duo does, so iPhone Duo layouts can be built and checked on it.
///
/// With the first one on, the app under `AppFoldScope` gets the window of an
/// iPhone Duo: its size, its safe area and its fold, scaled to fit the real
/// screen. The other three tune that.
///
/// Kept in preferences, so each is still set after a restart. Rendering as
/// an iPhone Duo, the flat division and the overlay are off until a
/// developer turns them on. Matching the screen size is on until a developer
/// turns it off.
///
/// Only registered in a build that has Developer options, on a platform
/// where a hinge can exist. Store builds never see it.
class DevFoldDivisionSwitches extends ChangeNotifier {
  DevFoldDivisionSwitches(this._prefs)
    : _isOn = _prefs.getBool(divisionKey) ?? false,
      _staysOnFlat = _prefs.getBool(flatKey) ?? false,
      _showsOverlay = _prefs.getBool(overlayKey) ?? false,
      _matchesWindowSize = _prefs.getBool(sizeKey) ?? true;

  static const divisionKey = 'dev.fold_division.on';
  static const flatKey = 'dev.fold_division.flat';
  static const overlayKey = 'dev.fold_division.overlay';

  /// Holds false while the switch is off. On is the absence of the key.
  static const sizeKey = 'dev.fold_division.match_size';

  final SharedPreferences _prefs;
  bool _isOn;
  bool _staysOnFlat;
  bool _showsOverlay;
  bool _matchesWindowSize;

  /// Whether the app is rendered as an iPhone Duo: its window, its safe
  /// area, and the hinge as its division.
  bool get isOn => _isOn;

  /// Whether the division stays in force with the device lying flat.
  bool get staysOnFlat => _staysOnFlat;

  /// Whether the division and its margins are drawn over the app.
  bool get showsOverlay => _showsOverlay;

  /// Whether the app is laid out at the window size of an iPhone Duo and
  /// scaled to fit the screen. Off, the window keeps its real size and takes
  /// the iPhone Duo safe area only.
  bool get matchesWindowSize => _matchesWindowSize;

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

  Future<void> setMatchesWindowSize({required bool matchesWindowSize}) async {
    if (matchesWindowSize == _matchesWindowSize) return;
    _matchesWindowSize = matchesWindowSize;
    notifyListeners();
    // On is the default, so on is the absence of the key.
    if (matchesWindowSize) {
      await _prefs.remove(sizeKey);
    } else {
      await _prefs.setBool(sizeKey, false);
    }
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

/// The division settings a run starts with and keeps: [base] with iPhone Duo
/// rendering on or off, and tuned, as [switches] say.
///
/// With no switches (a store build, or a platform with no hinge) it is off.
/// The package's own default is on in a debug build, so this is applied at
/// startup in every build.
///
/// The device in [base] is kept. The package starts with the iPhone Duo.
FoldDivisionConfig foldDivisionConfigFor(
  FoldDivisionConfig base,
  DevFoldDivisionSwitches? switches,
) => base.copyWith(
  enabled: switches?.isOn ?? false,
  activation: (switches?.staysOnFlat ?? false)
      ? DivisionActivation.always
      : DivisionActivation.followPosture,
  matchWindowSize: switches?.matchesWindowSize ?? true,
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
