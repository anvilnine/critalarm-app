import 'package:critalarm/core/result/result.dart';
import 'package:critalarm/core/sound/alarm_sound.dart';
import 'package:critalarm/core/sound/bundled_sounds.dart';
import 'package:critalarm/core/sound/sound_assignments.dart';
import 'package:critalarm/features/settings/domain/repositories/alarm_sound_repository.dart';

/// Keeps everything in memory, the same fallback rules as the real one.
class MemoryAlarmSoundRepository implements AlarmSoundRepository {
  SoundAssignments assignments = const SoundAssignments(
    defaultSoundId: BundledSounds.fallbackId,
  );
  final List<AlarmSound> sounds = [];

  @override
  Future<AppResult<SoundAssignments>> getAssignments() async =>
      assignments.toSuccess();

  @override
  Future<AppResult<Unit>> setDefaultSoundId(String soundId) async {
    assignments = assignments.withDefault(soundId);
    return unit.toSuccess();
  }

  @override
  Future<AppResult<Unit>> setTopicSoundId(
    String topicName,
    String? soundId,
  ) async {
    assignments = assignments.withTopicSound(topicName, soundId);
    return unit.toSuccess();
  }

  @override
  Future<AppResult<List<AlarmSound>>> getUserSounds() async =>
      List<AlarmSound>.of(sounds).toSuccess();

  @override
  Future<AppResult<Unit>> addUserSound(AlarmSound sound) async {
    sounds.add(sound);
    return unit.toSuccess();
  }

  @override
  Future<AppResult<Unit>> updateUserSoundPeaks(
    String soundId,
    List<double> peaks,
  ) async {
    final index = sounds.indexWhere((s) => s.id == soundId);
    if (index >= 0) sounds[index] = sounds[index].copyWith(peaks: peaks);
    return unit.toSuccess();
  }

  @override
  Future<AppResult<Unit>> deleteUserSound(String soundId) async {
    sounds.removeWhere((s) => s.id == soundId);
    assignments = assignments.withSoundDeleted(
      soundId,
      fallbackSoundId: BundledSounds.fallbackId,
    );
    return unit.toSuccess();
  }
}
