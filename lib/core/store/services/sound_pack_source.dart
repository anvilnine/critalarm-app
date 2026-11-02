import 'package:critalarm/core/sound/sound_pack.dart';

/// A pack state the source sent without being asked: download progress, a
/// finished download, a failure.
class SoundPackChange {
  const SoundPackChange(this.packId, this.status);

  final String packId;
  final SoundPackStatus status;
}

/// Where the sound packs come from for this store's build: Play Asset
/// Delivery on Google Play, Apple-hosted Background Assets on the App Store.
///
/// Every call answers and none throws. A source that cannot be asked
/// answers [SoundPackState.unsupported], an empty list or null.
abstract interface class SoundPackSource {
  Stream<SoundPackChange> get changes;

  /// Where [packId] is right now. Asks, never downloads.
  Future<SoundPackStatus> packState(String packId);

  /// Starts the download of [packId]. The end may come on [changes].
  Future<SoundPackStatus> download(String packId);

  /// The folder [packId] was unpacked into, or null when it is not on the
  /// device.
  Future<String?> packPath(String packId, {List<String> soundIds = const []});

  /// Copies [soundIds] out of the downloaded pack into the app's sound
  /// folder. Hands back id to path for the ones that made it.
  Future<Map<String, String>> installPack(
    String packId,
    List<String> soundIds,
  );

  /// Which of [soundIds] have a copy in the app's sound folder now, id to
  /// path. Null when the source could not be asked.
  Future<Map<String, String>?> installedPackSounds(
    String packId,
    List<String> soundIds,
  );
}
