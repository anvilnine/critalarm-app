import 'package:critalarm/core/sound/alarm_sound.dart';
import 'package:flutter/foundation.dart';

/// The eight sounds that ship inside the app.
///
/// `assets/sounds/LICENSES.md` says where each came from and
/// `tools/sounds/generate.py` rebuilds them. The ids here are the file names
/// with no extension, and they are stored against topics, so they can never
/// change.
abstract final class BundledSounds {
  /// The one every install starts on, and the one anything falls back to
  /// when a sound is deleted. It cannot itself be deleted.
  static const fallbackId = 'classic_siren';

  /// iOS plays the mp3, Android the ogg. `docs/specs/remote-alarm.md`, Part A.
  static String extensionFor(TargetPlatform platform) =>
      platform == TargetPlatform.iOS ? 'mp3' : 'ogg';

  static String assetPath(String id, TargetPlatform platform) =>
      'assets/sounds/$id.${extensionFor(platform)}';

  /// id to length, measured from what the generator wrote.
  static const durations = <String, Duration>{
    'classic_siren': Duration(seconds: 16),
    'pulsing_klaxon': Duration(seconds: 12),
    'marimba_escalator': Duration(milliseconds: 15600),
    'soft_to_loud_ramp': Duration(seconds: 15),
    'pager_beep': Duration(seconds: 14),
    'submarine_dive_horn': Duration(seconds: 15),
    'rising_synth_sweep': Duration(seconds: 15),
    'plain_loud_beep': Duration(seconds: 12),
  };

  /// Shown when nothing has translated the name yet, and used by tests.
  static const englishNames = <String, String>{
    'classic_siren': 'Classic siren',
    'pulsing_klaxon': 'Pulsing klaxon',
    'marimba_escalator': 'Marimba escalator',
    'soft_to_loud_ramp': 'Soft to loud ramp',
    'pager_beep': 'Pager beep',
    'submarine_dive_horn': 'Submarine dive horn',
    'rising_synth_sweep': 'Rising synth sweep',
    'plain_loud_beep': 'Plain loud beep',
  };

  static List<String> get ids => durations.keys.toList(growable: false);

  /// The catalogue in the order it is shown.
  ///
  /// [nameOf] lets the screen hand in translated names without core knowing
  /// anything about easy_localization.
  static List<AlarmSound> catalogue({
    TargetPlatform platform = TargetPlatform.android,
    String Function(String id)? nameOf,
  }) => [
    for (final id in ids)
      AlarmSound(
        id: id,
        name: nameOf?.call(id) ?? englishNames[id]!,
        source: AlarmSoundSource.bundled,
        path: assetPath(id, platform),
        duration: durations[id]!,
      ),
  ];

  static bool isBundled(String id) => durations.containsKey(id);
}
