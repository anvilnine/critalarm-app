import 'dart:async';

import 'package:critalarm/core/sound/alarm_sound.dart';
import 'package:critalarm/core/sound/sound_assignments.dart';
import 'package:critalarm/core/sound/sound_pack.dart';
import 'package:critalarm/core/sound/sound_pack_host.dart';

/// Downloads sound packs from the store and turns their files into sounds the
/// picker lists and the alarm rings.
///
/// A pack counts as downloaded only once every one of its sounds has a copy
/// in the app's sound folder. The store having the pack is not enough: the
/// copy is what the alarm and the notifications play, so the pack itself is
/// never read at ring time.
class SoundPackRepository {
  SoundPackRepository(
    this._host, {
    this.packs = SoundPacks.all,
    this.storeTimeout = const Duration(seconds: 3),
  }) {
    _hostChanges = _host.changes.listen(_onHostChange);
  }

  final SoundPackHost _host;
  final List<SoundPack> packs;

  /// How long a question to the store or the sound folder may take. Offline,
  /// or on an iOS that never answers, the pack shows as failed instead of
  /// holding the screen.
  final Duration storeTimeout;
  final _changes = StreamController<SoundPackChange>.broadcast();
  late final StreamSubscription<SoundPackChange> _hostChanges;

  /// Every state change, with a finished download already installed: a
  /// [SoundPackState.downloaded] here means the sounds ring.
  Stream<SoundPackChange> get changes => _changes.stream;

  SoundPack? packById(String packId) {
    for (final pack in packs) {
      if (pack.id == packId) return pack;
    }
    return null;
  }

  /// Where [pack] is. Installs it on the way when the store already has it
  /// on the device but the copies are missing, as after a restore.
  Future<SoundPackStatus> status(SoundPack pack) async {
    final installed = await _installed(pack.id, pack.soundIds);
    if (installed != null && installed.length == pack.sounds.length) {
      return const SoundPackStatus(SoundPackState.downloaded, progress: 1);
    }
    final native = await _host
        .packState(pack.id)
        .timeout(
          storeTimeout,
          onTimeout: () => const SoundPackStatus(SoundPackState.failed),
        );
    if (native.state != SoundPackState.downloaded) return native;
    return _install(pack);
  }

  /// Asks the store for [pack]. When the store answers that it is already
  /// here, it is installed before this returns. Otherwise the end arrives on
  /// [changes].
  Future<SoundPackStatus> download(SoundPack pack) async {
    final started = await _host.download(pack.id);
    if (started.state != SoundPackState.downloaded) return started;
    return _install(pack);
  }

  /// The downloaded sounds of every pack, in pack order, ready for the
  /// picker. [nameOf] turns an id into a name in the user's language.
  Future<List<AlarmSound>> installedSounds({
    String Function(String id)? nameOf,
  }) async {
    final sounds = <AlarmSound>[];
    for (final pack in packs) {
      final paths = await _installed(pack.id, pack.soundIds) ?? const {};
      for (final info in pack.sounds) {
        final path = paths[info.id];
        if (path == null) continue;
        sounds.add(
          AlarmSound(
            id: info.id,
            name: nameOf?.call(info.id) ?? info.englishName,
            source: AlarmSoundSource.pack,
            path: path,
            duration: info.duration,
          ),
        );
      }
    }
    return sounds;
  }

  /// Pack sounds [assignments] point at that are not on the device. Each
  /// one has to fall back to the bundled default, as a deleted user sound
  /// does. Ids that belong to no known pack count as missing too.
  ///
  /// When the platform cannot be asked, nothing counts as missing: a failed
  /// question must not move anyone's sound. The alarm itself still falls
  /// back at ring time.
  Future<Set<String>> missingAssigned(SoundAssignments assignments) async {
    final wanted = {
      assignments.defaultSoundId,
      ...assignments.perTopic.values,
    }.where(SoundPacks.isPackSound).toSet();
    if (wanted.isEmpty) return const {};
    final present = <String>{};
    for (final pack in packs) {
      final ids = pack.soundIds.where(wanted.contains).toList();
      if (ids.isEmpty) continue;
      final found = await _installed(pack.id, ids);
      if (found == null) return const {};
      present.addAll(found.keys);
    }
    // An id no pack knows still needs a working answer from the platform
    // before it is called missing.
    if (present.isEmpty && await _installed(packs.first.id, const []) == null) {
      return const {};
    }
    return wanted.difference(present);
  }

  /// [SoundPackHost.installedPackSounds] with [storeTimeout]. A late answer
  /// counts as no answer.
  Future<Map<String, String>?> _installed(String packId, List<String> ids) =>
      _host
          .installedPackSounds(packId, ids)
          .timeout(storeTimeout, onTimeout: () => null);

  Future<SoundPackStatus> _install(SoundPack pack) async {
    final copied = await _host.installPack(pack.id, pack.soundIds);
    return copied.length == pack.sounds.length
        ? const SoundPackStatus(SoundPackState.downloaded, progress: 1)
        : const SoundPackStatus(SoundPackState.failed);
  }

  Future<void> _onHostChange(SoundPackChange change) async {
    final pack = packById(change.packId);
    if (pack == null) return;
    if (change.status.state != SoundPackState.downloaded) {
      _changes.add(change);
      return;
    }
    _changes.add(SoundPackChange(pack.id, await _install(pack)));
  }

  Future<void> dispose() async {
    await _hostChanges.cancel();
    await _changes.close();
  }
}
