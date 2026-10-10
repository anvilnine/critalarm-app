import 'package:critalarm/core/result/result.dart';
import 'package:critalarm/core/sound/alarm_sound.dart';
import 'package:critalarm/core/sound/sound_assignments.dart';

/// Stores which sound rings, and the sounds the user brought in.
///
/// All of it stays on the device. `docs/api.md` has no field for a sound, and
/// nothing here is ever sent to the server.
abstract interface class AlarmSoundRepository {
  /// The default sound plus every per-topic override.
  Future<AppResult<SoundAssignments>> getAssignments();

  /// [getAssignments] without waiting, for a screen that draws the sound on
  /// its first frame. The choices are already in memory on the device.
  SoundAssignments assignmentsNow();

  /// [getUserSounds] without waiting, for the same reason.
  List<AlarmSound> userSoundsNow();

  Future<AppResult<Unit>> setDefaultSoundId(String soundId);

  /// Passing null for [soundId] puts the topic back on the default.
  Future<AppResult<Unit>> setTopicSoundId(String topicName, String? soundId);

  /// Sounds the user imported, oldest first.
  Future<AppResult<List<AlarmSound>>> getUserSounds();

  Future<AppResult<Unit>> addUserSound(AlarmSound sound);

  /// Saves waveform [peaks] onto the user sound [soundId], in place. Does
  /// nothing when the sound is gone, so a slow read can never bring back a
  /// sound the user deleted in the meantime.
  Future<AppResult<Unit>> updateUserSoundPeaks(
    String soundId,
    List<double> peaks,
  );

  /// Removes the sound and re-points anything still using it. A topic falls
  /// back to the default; the default falls back to the first bundled sound.
  Future<AppResult<Unit>> deleteUserSound(String soundId);

  /// Re-points anything using [soundId] the way [deleteUserSound] does,
  /// without touching the user sound list. For a pack sound whose file is
  /// no longer on the device.
  Future<AppResult<Unit>> fallBackFrom(String soundId);
}
