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

  Future<AppResult<Unit>> setDefaultSoundId(String soundId);

  /// Passing null for [soundId] puts the topic back on the default.
  Future<AppResult<Unit>> setTopicSoundId(String topicName, String? soundId);

  /// Sounds the user imported, oldest first.
  Future<AppResult<List<AlarmSound>>> getUserSounds();

  Future<AppResult<Unit>> addUserSound(AlarmSound sound);

  /// Removes the sound and re-points anything still using it. A topic falls
  /// back to the default; the default falls back to the first bundled sound.
  Future<AppResult<Unit>> deleteUserSound(String soundId);
}
