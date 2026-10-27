import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The instrument family a paywall intro's score is played in. Each score
/// has one file for each flavour, with the same timing.
enum IntroSoundFlavour {
  /// A brooding piano that resolves bright. What a store build plays.
  piano,

  /// Kalimba pairs and soft bells, landing on a music box.
  kalimba;

  /// The flavour saved as [key], or null for nothing saved and for a word
  /// this build does not know.
  static IntroSoundFlavour? fromKey(String? key) {
    for (final flavour in values) {
      if (flavour.name == key) return flavour;
    }
    return null;
  }
}

/// The developer control for the flavour of the intro scores, so the two
/// can be compared by ear. Saved in prefs. There is no remote value: a
/// build with no Developer options plays [IntroSoundFlavour.piano].
class DevIntroSoundSwitch extends ValueNotifier<IntroSoundFlavour> {
  DevIntroSoundSwitch(this._prefs)
    : super(
        IntroSoundFlavour.fromKey(_prefs.getString(prefsKey)) ??
            IntroSoundFlavour.piano,
      );

  static const prefsKey = 'dev.paywall_intro_sound';

  final SharedPreferences _prefs;

  /// Sets the flavour every intro plays from now on. Remembered across
  /// launches.
  Future<void> setFlavour(IntroSoundFlavour flavour) async {
    value = flavour;
    await _prefs.setString(prefsKey, flavour.name);
  }
}
