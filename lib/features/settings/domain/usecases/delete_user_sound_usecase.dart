import 'package:critalarm/core/result/result.dart';
import 'package:critalarm/core/sound/sound_host.dart';
import 'package:critalarm/features/settings/domain/repositories/alarm_sound_repository.dart';

/// Removes one imported sound: the file, then the record, then anything that
/// was still pointing at it.
class DeleteUserSoundUsecase {
  const DeleteUserSoundUsecase(this._repository, this._host);

  final AlarmSoundRepository _repository;
  final SoundHost _host;

  Future<AppResult<Unit>> call(String soundId) async {
    final sounds = await _repository.getUserSounds();
    final match = sounds
        .getOrDefault(const [])
        .where((s) => s.id == soundId)
        .firstOrNull;
    if (match != null) {
      // A file that is already gone is not a reason to keep a dead row.
      await _host.deleteSound(match.path);
    }
    return _repository.deleteUserSound(soundId);
  }
}
