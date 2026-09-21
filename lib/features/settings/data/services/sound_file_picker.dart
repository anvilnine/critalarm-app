import 'package:critalarm/core/sound/sound_import.dart';
import 'package:critalarm/features/settings/domain/repositories/sound_file_picker.dart';
import 'package:critalarm/features/settings/domain/usecases/import_sound_usecase.dart';
import 'package:file_selector/file_selector.dart';

/// [SoundFilePicker] backed by the `file_selector` plugin.
///
/// `file_selector` only opens the Files picker. `file_picker` also shipped
/// camera and photo library code, which made App Store Connect ask for
/// camera and photo purpose strings the app has no use for.
class PlatformSoundFilePicker implements SoundFilePicker {
  const PlatformSoundFilePicker();

  static const _audio = XTypeGroup(
    label: 'audio',
    extensions: <String>[...SoundImportLimits.readableExtensions],
    mimeTypes: <String>['audio/*'],
    // iOS filters by type ID only and throws without one.
    uniformTypeIdentifiers: <String>['public.audio'],
  );

  @override
  Future<PickedSoundFile?> pickOne() async {
    final file = await openFile(acceptedTypeGroups: const [_audio]);
    if (file == null) return null;
    return PickedSoundFile(
      path: file.path,
      name: file.name,
      sizeBytes: await file.length(),
    );
  }
}
