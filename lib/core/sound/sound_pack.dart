import 'package:critalarm/core/sound/library_pack_sounds.dart';
import 'package:flutter/foundation.dart';

/// One sound in a store-hosted pack, known before the pack is downloaded.
///
/// The credits travel with the sound so the Acknowledgements screen and the
/// pack's `LICENSES.md` say the same thing.
@immutable
class PackSoundInfo {
  const PackSoundInfo({
    required this.id,
    required this.englishName,
    required this.duration,
    required this.title,
    required this.author,
    required this.sourceUrl,
    required this.licence,
  });

  /// Stored against topics, so it never changes. Always starts with
  /// [SoundPacks.soundIdPrefix].
  final String id;

  /// Shown when nothing has translated the name, and used by tests.
  final String englishName;
  final Duration duration;

  /// The title on the page the recording came from.
  final String title;
  final String author;
  final String sourceUrl;
  final String licence;
}

/// A pack of extra alarm sounds that the App Store or Google Play hosts and
/// the app downloads when the user asks. Nothing here comes from our own
/// server.
@immutable
class SoundPack {
  const SoundPack({
    required this.id,
    required this.englishName,
    required this.sounds,
  });

  /// The pack's name in both stores: the Play asset pack name and the Apple
  /// asset pack id. Permanent.
  final String id;
  final String englishName;
  final List<PackSoundInfo> sounds;

  List<String> get soundIds => [for (final s in sounds) s.id];

  bool contains(String soundId) => sounds.any((s) => s.id == soundId);

  /// One paragraph per sound: name, title, author, source and licence. The
  /// Acknowledgements screen shows it. None of these sounds needs credit;
  /// every one gets it anyway.
  String get creditsText => [
    _creditsIntro,
    for (final s in sounds) _credit(s),
  ].join('\n\n');

  static String _credit(PackSoundInfo s) =>
      '${s.englishName}: "${s.title}" by ${s.author}. '
      '${s.licence}. ${s.sourceUrl}';

  static const _creditsIntro =
      'Recordings by other people, released as CC0 or public domain. '
      'Trimmed, levelled and re-encoded for Crit Alarm.';
}

/// Every pack the app knows about.
abstract final class SoundPacks {
  /// Every pack sound id starts with this, and no other sound's does. The
  /// Android alarm and the iOS notification extension read it to decide a
  /// sound came from a pack.
  static const soundIdPrefix = 'pack_';

  /// The CC0 and public domain recordings. `tools/sounds/library_pack.mjs`
  /// prepares them.
  static const library = SoundPack(
    id: 'sound_pack_library',
    englishName: 'Library sounds',
    sounds: libraryPackSounds,
  );

  static const all = <SoundPack>[library];

  static bool isPackSound(String soundId) => soundId.startsWith(soundIdPrefix);

  /// The pack sound with [soundId], or null when no pack has it.
  static PackSoundInfo? info(String soundId) {
    for (final pack in all) {
      for (final sound in pack.sounds) {
        if (sound.id == soundId) return sound;
      }
    }
    return null;
  }
}

/// Where a pack is, from the user's side.
enum SoundPackState {
  /// The store has it and it is not on this device yet.
  notDownloaded,
  downloading,

  /// Android only: Play holds a large download until Wi-Fi.
  waitingForWifi,

  /// Android only: Play wants the user to approve the download.
  needsConfirmation,

  /// Its sounds are copied into the app's sound folder and ring.
  downloaded,

  /// The last download failed. Asking again may work.
  failed,

  /// This install cannot get packs: a build not installed from the store, or
  /// a store that does not know the pack.
  unavailable,

  /// iOS before 26, where Apple-hosted packs do not exist.
  needsNewerOs,

  /// No native side at all, as on the web and in tests. The picker hides
  /// the packs.
  unsupported;

  static SoundPackState fromWire(Object? raw) => switch (raw) {
    'not_downloaded' => notDownloaded,
    'downloading' => downloading,
    'waiting_for_wifi' => waitingForWifi,
    'needs_confirmation' => needsConfirmation,
    'downloaded' => downloaded,
    'failed' => failed,
    'needs_newer_os' => needsNewerOs,
    'unsupported' => unsupported,
    _ => unavailable,
  };

  /// True while the store is still working on it.
  bool get isBusy => this == downloading;

  /// True when tapping download makes sense. On Android, tapping it while
  /// Play waits for Wi-Fi or a confirmation shows Play's own dialog.
  bool get canDownload =>
      this == notDownloaded ||
      this == failed ||
      this == needsConfirmation ||
      this == waitingForWifi;
}

/// One pack's state, plus how far a download has got.
@immutable
class SoundPackStatus {
  const SoundPackStatus(this.state, {this.progress});

  factory SoundPackStatus.fromMap(Object? raw) {
    if (raw is! Map) return const SoundPackStatus(SoundPackState.unavailable);
    final progress = raw['progress'];
    return SoundPackStatus(
      SoundPackState.fromWire(raw['state']),
      progress: progress is num ? progress.toDouble().clamp(0.0, 1.0) : null,
    );
  }

  final SoundPackState state;

  /// 0 to 1 while downloading, when the store says how big the pack is.
  final double? progress;

  @override
  bool operator ==(Object other) =>
      other is SoundPackStatus &&
      other.state == state &&
      other.progress == progress;

  @override
  int get hashCode => Object.hash(state, progress);

  @override
  String toString() => 'SoundPackStatus($state, progress: $progress)';
}
