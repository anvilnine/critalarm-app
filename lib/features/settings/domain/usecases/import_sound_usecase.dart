import 'package:critalarm/core/failures/failure.dart';
import 'package:critalarm/core/result/result.dart';
import 'package:critalarm/core/sound/alarm_sound.dart';
import 'package:critalarm/core/sound/sound_host.dart';
import 'package:critalarm/core/sound/sound_import.dart';
import 'package:critalarm/features/settings/domain/repositories/alarm_sound_repository.dart';
import 'package:flutter/foundation.dart';

/// A file the user picked, before anything has been checked.
class PickedSoundFile {
  const PickedSoundFile({
    required this.path,
    required this.name,
    required this.sizeBytes,
  });

  final String path;

  /// The file name as the picker reported it, extension included.
  final String name;
  final int sizeBytes;
}

/// Brings a user's own audio file into the sound library.
///
/// Order matters: check the size and the format before asking the platform to
/// decode anything, so a 400 MB video never gets opened.
class ImportSoundUsecase {
  ImportSoundUsecase(this._repository, this._host, {TargetPlatform? platform})
    : _platform = platform ?? defaultTargetPlatform;

  final AlarmSoundRepository _repository;
  final SoundHost _host;

  /// Decides the length cap. Tests pass one in.
  final TargetPlatform _platform;

  Future<AppResult<AlarmSound>> call(PickedSoundFile file) async {
    if (file.sizeBytes > SoundImportLimits.maxBytes) {
      return const BadRequestFailure(
        message: 'tooLarge',
      ).toFailure<AlarmSound>();
    }
    final duration = await _host.probeDuration(file.path);
    final rejection = checkSoundImport(
      fileName: file.name,
      sizeBytes: file.sizeBytes,
      duration: duration,
      platform: _platform,
    );
    if (rejection != null) {
      return BadRequestFailure(
        message: rejection.name,
      ).toFailure<AlarmSound>();
    }

    final id = 'user_${DateTime.now().microsecondsSinceEpoch}';
    final imported = await _host.importSound(
      sourcePath: file.path,
      id: id,
    );
    if (imported == null) {
      return const UnexpectedFailure(
        message: 'copyFailed',
      ).toFailure<AlarmSound>();
    }

    final sound = AlarmSound(
      id: id,
      name: displayNameFor(file.name),
      source: AlarmSoundSource.user,
      path: imported.path,
      duration: imported.duration,
    );
    final saved = await _repository.addUserSound(sound);
    if (saved.isError()) {
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
