import 'package:critalarm/core/failures/failure.dart';
import 'package:critalarm/core/result/result.dart';
import 'package:critalarm/core/sound/alarm_sound.dart';
import 'package:critalarm/core/sound/sound_host.dart';
import 'package:critalarm/core/sound/sound_import.dart';
import 'package:critalarm/core/sound/sound_peaks_cache.dart';
import 'package:critalarm/features/settings/domain/repositories/alarm_sound_repository.dart';

// Lives in core now, so a file shared in from another app can become one.
export 'package:critalarm/core/sound/sound_import.dart' show PickedSoundFile;

/// Saves one range of a picked file as a user sound.
///
/// The checks on the picked file itself happen before the cropper opens
/// (`checkPickedSound`, `checkSourceDuration`). By the time this runs the user
/// has chosen the range, so all that is left is the cut, the waveform and the
/// save.
class ImportSoundUsecase {
  ImportSoundUsecase(this._repository, this._host);

  final AlarmSoundRepository _repository;
  final SoundHost _host;

  Future<AppResult<AlarmSound>> call({
    required PickedSoundFile file,
    required String name,
    required Duration start,
    required Duration end,
  }) async {
    final id = 'user_${DateTime.now().microsecondsSinceEpoch}';
    final imported = await _host.importSound(
      sourcePath: file.path,
      id: id,
      start: start,
      end: end,
    );
    if (imported == null) {
      return const UnexpectedFailure(
        message: 'copyFailed',
      ).toFailure<AlarmSound>();
    }
    if ((imported.sizeBytes ?? 0) > SoundImportLimits.maxBytes) {
      await _host.deleteSound(imported.path);
      return const UnexpectedFailure(
        message: 'copyFailed',
      ).toFailure<AlarmSound>();
    }

    final peaks = await _host.readPeaks(
      path: imported.path,
      isAsset: false,
      count: SoundPeaksCache.barCount,
    );
    final trimmed = name.trim();
    final sound = AlarmSound(
      id: id,
      name: trimmed.isEmpty ? displayNameFor(file.name) : trimmed,
      source: AlarmSoundSource.user,
      path: imported.path,
      duration: imported.duration,
      // Empty means the read failed. Null lets the picker try again later.
      peaks: peaks.isEmpty ? null : peaks,
    );
    final saved = await _repository.addUserSound(sound);
    if (saved.isError()) {
      await _host.deleteSound(imported.path);
      return saved.exceptionOrNull()!.toFailure<AlarmSound>();
    }
    return sound.toSuccess();
  }

  /// The file name with the extension taken off, trimmed to something that
  /// fits one row.
  static String displayNameFor(String fileName) {
    final dot = fileName.lastIndexOf('.');
    final stem = dot > 0 ? fileName.substring(0, dot) : fileName;
    final cleaned = stem.trim().isEmpty ? fileName : stem.trim();
    return cleaned.length <= 40 ? cleaned : '${cleaned.substring(0, 39)}…';
  }
}
