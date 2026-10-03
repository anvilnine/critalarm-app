import 'package:critalarm/core/sound/alarm_sound.dart';
import 'package:flutter/foundation.dart';

/// The 27 sounds that ship inside the app: the first eight, then 14
/// emergency sounds, then five seamless loops.
///
/// `assets/sounds/LICENSES.md` says where each came from.
/// `tools/sounds/generate.py` rebuilds the first eight,
/// `tools/sounds/emergency.mjs` rebuilds the `emergency_` ones and
/// `tools/sounds/loops.mjs` rebuilds the `loop_` ones. The ids here
/// are the file names with no extension, and they are stored against topics,
/// so they can never change.
abstract final class BundledSounds {
  /// The one every install starts on, and the one anything falls back to
  /// when a sound is deleted. It cannot itself be deleted.
  static const fallbackId = 'classic_siren';

  /// Android plays the ogg for every sound. iOS plays the first eight as
  /// mp3 and the emergency sounds and loops as m4a: AVFoundation turns an
  /// m4a into a caf at its exact length, an mp3 with encoder padding added.
  static const _androidExtension = 'ogg';

  /// id to the extension of the file iOS plays.
  static const iosExtensions = <String, String>{
    'classic_siren': 'mp3',
    'pulsing_klaxon': 'mp3',
    'marimba_escalator': 'mp3',
    'soft_to_loud_ramp': 'mp3',
    'pager_beep': 'mp3',
    'submarine_dive_horn': 'mp3',
    'rising_synth_sweep': 'mp3',
    'plain_loud_beep': 'mp3',
    'emergency_hilo_siren': 'm4a',
    'emergency_wail_siren': 'm4a',
    'emergency_yelp_siren': 'm4a',
    'emergency_windup_siren': 'm4a',
    'emergency_klaxon': 'm4a',
    'emergency_sos_beeper': 'm4a',
    'emergency_sos_horn': 'm4a',
    'emergency_rapid_beeper': 'm4a',
    'emergency_red_alert': 'm4a',
    'emergency_endless_siren': 'm4a',
    'emergency_speeding_beeper': 'm4a',
    'emergency_proximity': 'm4a',
    'emergency_alarm_bell': 'm4a',
    'emergency_tone_ladder': 'm4a',
    'loop_ascend': 'm4a',
    'loop_dread': 'm4a',
    'loop_chiprun': 'm4a',
    'loop_glockslide': 'm4a',
    'loop_royalroad': 'm4a',
  };

  /// The sounds made to loop with no gap. Each is exactly 1,382,400 samples
  /// at 48 kHz on both platforms, with no silence at either end.
  static const seamlessLoops = <String>{
    'loop_ascend',
    'loop_dread',
    'loop_chiprun',
    'loop_glockslide',
    'loop_royalroad',
  };

  /// The file extension [id] ships with on [platform].
  /// `docs/specs/remote-alarm.md`, Part A. Throws for an id that is not
  /// bundled.
  static String extensionFor(String id, TargetPlatform platform) {
    final ios = iosExtensions[id];
    if (ios == null) throw ArgumentError.value(id, 'id', 'not a bundled sound');
    return platform == TargetPlatform.iOS ? ios : _androidExtension;
  }

  static String assetPath(String id, TargetPlatform platform) =>
      'assets/sounds/$id.${extensionFor(id, platform)}';

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
    'emergency_hilo_siren': Duration(milliseconds: 16200),
    'emergency_wail_siren': Duration(seconds: 16),
    'emergency_yelp_siren': Duration(milliseconds: 15840),
    'emergency_windup_siren': Duration(milliseconds: 16500),
    'emergency_klaxon': Duration(seconds: 16),
    'emergency_sos_beeper': Duration(seconds: 17),
    'emergency_sos_horn': Duration(milliseconds: 17340),
    'emergency_rapid_beeper': Duration(seconds: 16),
    'emergency_red_alert': Duration(milliseconds: 16250),
    'emergency_endless_siren': Duration(seconds: 16),
    'emergency_speeding_beeper': Duration(seconds: 16),
    'emergency_proximity': Duration(seconds: 16),
    'emergency_alarm_bell': Duration(seconds: 16),
    'emergency_tone_ladder': Duration(seconds: 16),
    'loop_ascend': Duration(milliseconds: 28800),
    'loop_dread': Duration(milliseconds: 28800),
    'loop_chiprun': Duration(milliseconds: 28800),
    'loop_glockslide': Duration(milliseconds: 28800),
    'loop_royalroad': Duration(milliseconds: 28800),
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
    'emergency_hilo_siren': 'Hi-lo siren',
    'emergency_wail_siren': 'Wail siren',
    'emergency_yelp_siren': 'Yelp siren',
    'emergency_windup_siren': 'Wind-up siren',
    'emergency_klaxon': 'Klaxon',
    'emergency_sos_beeper': 'SOS beeper',
    'emergency_sos_horn': 'SOS ship horn',
    'emergency_rapid_beeper': 'Rapid beeper',
    'emergency_red_alert': 'Red alert',
    'emergency_endless_siren': 'Endless siren',
    'emergency_speeding_beeper': 'Speeding beeper',
    'emergency_proximity': 'Proximity warning',
    'emergency_alarm_bell': 'Alarm bell',
    'emergency_tone_ladder': 'Tone ladder',
    'loop_ascend': 'Endless climb',
    'loop_dread': 'Falling dread',
    'loop_chiprun': 'Chip run',
    'loop_glockslide': 'Glock slide',
    'loop_royalroad': 'Royal road',
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

/// Whether a sound loops with no gap. It lives here, next to the list it
/// reads, so `AlarmSound` does not import the catalogue.
extension SeamlessLoop on AlarmSound {
  /// True for a bundled sound made to loop with no gap: no silence at
  /// either end, and the same exact length on every platform, so the last
  /// sample leads straight into the first. A gapless player loops these
  /// sample to sample.
  ///
  /// Worked out from the id and source, never stored, so neither a saved
  /// JSON nor a user's own file can claim it.
  bool get seamlessLoop =>
      source == AlarmSoundSource.bundled &&
      BundledSounds.seamlessLoops.contains(id);
}
