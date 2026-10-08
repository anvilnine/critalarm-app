import 'package:critalarm/features/incidents/domain/alarm_style/own_photo_import.dart';
import 'package:file_selector/file_selector.dart';

/// [OwnPhotoPicker] backed by the `file_selector` plugin, the same one
/// the sound import uses. It opens the system's file picker, so the app
/// asks for no photo library permission and sees only the one file the
/// person picks.
class PlatformOwnPhotoPicker implements OwnPhotoPicker {
  const PlatformOwnPhotoPicker();

  static XTypeGroup get _images => XTypeGroup(
    label: 'images',
    extensions: OwnPhotoLimits.extensions.toList(),
    mimeTypes: const <String>['image/*'],
    // iOS filters by type ID only and throws without one.
    uniformTypeIdentifiers: const <String>['public.image'],
  );

  @override
  Future<PickedOwnPhoto?> pickOne() async {
    final file = await openFile(acceptedTypeGroups: [_images]);
    if (file == null) return null;
    return PickedOwnPhoto(
      path: file.path,
      name: file.name,
      sizeBytes: await file.length(),
    );
  }
}
