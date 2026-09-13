import 'package:critalarm/features/settings/domain/usecases/import_sound_usecase.dart';

/// Opens the platform's own file browser and hands back one audio file.
///
/// Behind an interface so the picker cubit has one thing to stub and no plugin
/// of its own.
// ignore: one_member_abstracts
abstract interface class SoundFilePicker {
  /// Null when the user backed out, or when the platform gave no real path.
  Future<PickedSoundFile?> pickOne();
}
