import 'dart:io';

import 'package:critalarm/core/sound/sound_import.dart';
import 'package:critalarm/features/settings/domain/repositories/sound_file_picker.dart';
import 'package:critalarm/features/settings/domain/usecases/import_sound_usecase.dart';
import 'package:file_picker/file_picker.dart';

/// [SoundFilePicker] backed by the `file_picker` plugin.
class PlatformSoundFilePicker implements SoundFilePicker {
  const PlatformSoundFilePicker();

  @override
  Future<PickedSoundFile?> pickOne() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: SoundImportLimits.readableExtensions.toList(),
    );
    final file = result?.files.singleOrNull;
    final path = file?.path;
    if (file == null || path == null) return null;
    final size = file.size > 0 ? file.size : await File(path).length();
    return PickedSoundFile(path: path, name: file.name, sizeBytes: size);
  }
}
