import 'dart:async';

import 'package:critalarm/core/access/feature_decision.dart';
import 'package:critalarm/core/sound/alarm_sound.dart';
import 'package:critalarm/core/sound/bundled_sounds.dart';
import 'package:critalarm/core/sound/own_sound_rule.dart';
import 'package:critalarm/core/sound/sound_host.dart';
import 'package:critalarm/core/sound/sound_import.dart';
import 'package:critalarm/core/sound/sound_pack.dart';
import 'package:critalarm/core/sound/sound_pack_host.dart';
import 'package:critalarm/core/sound/sound_pack_repository.dart';
import 'package:critalarm/core/sound/sound_peaks_cache.dart';
import 'package:critalarm/features/settings/domain/repositories/alarm_sound_repository.dart';
import 'package:critalarm/features/settings/domain/repositories/sound_file_picker.dart';
import 'package:critalarm/features/settings/domain/usecases/delete_user_sound_usecase.dart';
import 'package:critalarm/features/settings/presentation/cubits/sound_picker_state.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Drives the sound picker. One instance per open, for one topic or for the
/// global default.
class SoundPickerCubit extends Cubit<SoundPickerState> {
  SoundPickerCubit(
    this._repository,
    this._host,
    this._delete,
    this._picker,
    this._peaksCache, {
    TargetPlatform? platform,
    this.nameOf,
    SoundPackRepository? packs,
    this._readOwnSounds,
    Stream<Object?>? ownSoundsChanges,
  }) : _platform = platform ?? defaultTargetPlatform,
       _packs = packs,
       super(const SoundPickerState()) {
    _ownSoundsChanges = ownSoundsChanges?.listen((_) {
      if (isClosed) return;
      emit(state.copyWith(ownSounds: _ownSounds()));
    });
    _previewEnded = _host.previewEnded.listen((path) {
      if (isClosed) return;
      final playing = state.previewingSoundId;
      // A late event for a preview that has since been replaced says nothing
      // about the one playing now.
      final match = state.allSounds.where(
        (s) => s.id == playing && s.path == path,
      );
      if (match.isNotEmpty) emit(state.copyWith(clearPreviewing: true));
    });
    _packChanges = packs?.changes.listen(_onPackChange);
  }

  /// Turns a bundled or pack sound id into a name in the user's language.
  /// Left null in tests, which fall back to the English names in the
  /// catalogue.
  final String Function(String id)? nameOf;

  /// The access layer's decision for own sounds. Left out, they are open.
  final FeatureDecision Function()? _readOwnSounds;
  StreamSubscription<Object?>? _ownSoundsChanges;

  FeatureDecision _ownSounds() =>
      _readOwnSounds?.call() ?? const FeatureDecision.open();

  /// Null where the app offers no packs.
  final SoundPackRepository? _packs;
  StreamSubscription<SoundPackChange>? _packChanges;

  final AlarmSoundRepository _repository;
  final SoundHost _host;
  final DeleteUserSoundUsecase _delete;
  final SoundFilePicker _picker;
  final SoundPeaksCache _peaksCache;
  final TargetPlatform _platform;
  late final StreamSubscription<String> _previewEnded;

  /// [topicName] null means this screen is choosing the global default.
  ///
  /// The built-in and user sounds show first. The packs ask the store, which
  /// can be slow or offline, so their rows fill in after and never hold the
  /// screen on loading.
  Future<void> load({String? topicName}) async {
    final assignments = (await _repository.getAssignments()).getOrNull();
    final userSounds = (await _repository.getUserSounds()).getOrDefault(
      const [],
    );
    final defaultId = assignments?.defaultSoundId ?? BundledSounds.fallbackId;
    final selected = topicName == null
        ? defaultId
        : assignments?.soundIdFor(topicName) ?? defaultId;
    emit(
      state.copyWith(
        isLoading: false,
        // Peaks read on an earlier open show on the first frame.
        bundled: [
          for (final sound in BundledSounds.catalogue(
            platform: _platform,
            nameOf: nameOf,
          ))
            sound.copyWith(peaks: sound.peaks ?? _peaksCache.cached(sound.id)),
        ],
        isLoadingPeaks: true,
        ownSounds: _ownSounds(),
        userSounds: userSounds,
        selectedSoundId: selected,
        defaultSoundId: defaultId,
        topicName: topicName,
        capabilities: await _host.capabilities(),
        platform: _platform,
      ),
    );
    await Future.wait([
      _fillBundledPeaks(),
      _backfillUserPeaks(),
      _loadPacks(),
    ]);
    if (!isClosed) emit(state.copyWith(isLoadingPeaks: false));
  }

  /// Fills in the "Sound packs" rows and the downloaded pack sounds, after
  /// moving any choice whose pack sound is gone.
  Future<void> _loadPacks() async {
    if (_packs == null) return;
    if (await _fallBackFromMissingPackSounds()) {
      final assignments = (await _repository.getAssignments()).getOrNull();
      if (isClosed) return;
      final defaultId = assignments?.defaultSoundId ?? BundledSounds.fallbackId;
      emit(
        state.copyWith(
          defaultSoundId: defaultId,
          selectedSoundId: state.isPerTopic
              ? assignments?.soundIdFor(state.topicName!) ?? defaultId
              : defaultId,
        ),
      );
    }
    final packs = await _packEntries();
    final packSounds = await _installedPackSounds();
    if (isClosed) return;
    emit(state.copyWith(packs: packs, packSounds: packSounds));
    await _fillPackPeaks();
  }

  /// A pack sound picked earlier whose file is gone (a restore onto a new
  /// phone, say) moves to the bundled default, the way a deleted user sound
  /// does. The alarm itself already rings the default for it.
  /// True when something moved.
  Future<bool> _fallBackFromMissingPackSounds() async {
    final packs = _packs;
    if (packs == null) return false;
    final assignments = (await _repository.getAssignments()).getOrNull();
    if (assignments == null) return false;
    final missing = await packs.missingAssigned(assignments);
    if (missing.isEmpty) return false;
    for (final id in missing) {
      await _repository.fallBackFrom(id);
    }
    await _host.publishSoundAssignments();
    return true;
  }

  Future<List<SoundPackEntry>> _packEntries() async {
    final packs = _packs;
    if (packs == null) return const [];
    final entries = [
      for (final pack in packs.packs)
        SoundPackEntry(pack, await packs.status(pack)),
    ];
    // No native side (the web): nothing to offer.
    return entries
        .where((e) => e.status.state != SoundPackState.unsupported)
        .toList();
  }

  Future<List<AlarmSound>> _installedPackSounds() async {
    final packs = _packs;
    if (packs == null) return const [];
    return [
      for (final sound in await packs.installedSounds(nameOf: nameOf))
        sound.copyWith(peaks: _peaksCache.cached(sound.id)),
    ];
  }

  /// "Download" on a pack row. The row shows progress from the store's
  /// updates and lists the sounds once they are installed.
  Future<void> downloadPack(String packId) async {
    final packs = _packs;
    final pack = packs?.packById(packId);
    if (packs == null || pack == null) return;
    _setPackStatus(
      packId,
      const SoundPackStatus(SoundPackState.downloading),
    );
    final status = await packs.download(pack);
    if (isClosed) return;
    await _applyPackStatus(packId, status);
  }

  Future<void> _onPackChange(SoundPackChange change) async {
    if (isClosed) return;
    await _applyPackStatus(change.packId, change.status);
  }

  Future<void> _applyPackStatus(String packId, SoundPackStatus status) async {
    _setPackStatus(packId, status);
    if (status.state != SoundPackState.downloaded) return;
    final packSounds = await _installedPackSounds();
    if (isClosed) return;
    emit(state.copyWith(packSounds: packSounds));
    await _fillPackPeaks();
  }

  void _setPackStatus(String packId, SoundPackStatus status) {
    if (isClosed) return;
    // A late progress update must not take a finished pack back to
    // downloading.
    final current = state.packs.where((e) => e.pack.id == packId);
    if (current.isNotEmpty &&
        current.first.status.state == SoundPackState.downloaded &&
        status.state.isBusy) {
      return;
    }
    emit(
      state.copyWith(
        packs: [
          for (final entry in state.packs)
            entry.pack.id == packId ? entry.withStatus(status) : entry,
        ],
      ),
    );
  }

  /// Pack sounds read their waveform once per launch, like bundled ones.
  Future<void> _fillPackPeaks() async {
    final missing = state.packSounds.where((s) => s.peaks == null).toList();
    if (missing.isEmpty) return;
    final read = await Future.wait([
      for (final sound in missing) _peaksCache.load(sound),
    ]);
    final found = <String, List<double>>{
      for (var i = 0; i < missing.length; i++)
        if (read[i].isNotEmpty) missing[i].id: read[i],
    };
    if (isClosed || found.isEmpty) return;
    emit(
      state.copyWith(
        packSounds: [
          for (final s in state.packSounds)
            found.containsKey(s.id) ? s.copyWith(peaks: found[s.id]) : s,
        ],
      ),
    );
  }

  /// Reads every missing bundled waveform at once and shows them together,
  /// so the rows do not fill in one at a time.
  Future<void> _fillBundledPeaks() async {
    final missing = state.bundled.where((s) => s.peaks == null).toList();
    if (missing.isEmpty) return;
    final read = await Future.wait([
      for (final sound in missing) _peaksCache.load(sound),
    ]);
    final found = <String, List<double>>{
      for (var i = 0; i < missing.length; i++)
        if (read[i].isNotEmpty) missing[i].id: read[i],
    };
    if (isClosed || found.isEmpty) return;
    emit(
      state.copyWith(
        bundled: [
          for (final s in state.bundled)
            found.containsKey(s.id) ? s.copyWith(peaks: found[s.id]) : s,
        ],
      ),
    );
  }

  /// Sounds imported before waveforms existed have no peaks. Read them once,
  /// save them, and merge them into whatever the screen shows by then, so a
  /// sound deleted during the read is not brought back.
  Future<void> _backfillUserPeaks() async {
    for (final sound in state.userSounds) {
      if (sound.peaks != null) continue;
      final peaks = await _host.readPeaks(
        path: sound.path,
        isAsset: false,
        count: SoundPeaksCache.barCount,
      );
      if (peaks.isEmpty) continue;
      await _repository.updateUserSoundPeaks(sound.id, peaks);
      if (isClosed) return;
      emit(
        state.copyWith(
          userSounds: [
            for (final s in state.userSounds)
              s.id == sound.id ? s.copyWith(peaks: peaks) : s,
          ],
        ),
      );
    }
  }

  /// Saves the choice. A locked own sound cannot be picked: the screen
  /// opens the paywall for it, and this saves nothing.
  Future<void> select(String soundId) async {
    final ownSounds = _ownSounds();
    if (ownSoundsLockedBy(ownSounds) && isOwnSoundId(soundId)) {
      if (ownSounds != state.ownSounds) {
        emit(state.copyWith(ownSounds: ownSounds));
      }
      return;
    }
    if (state.isPerTopic) {
      await _repository.setTopicSoundId(state.topicName!, soundId);
    } else {
      await _repository.setDefaultSoundId(soundId);
    }
    await _host.publishSoundAssignments();
    emit(
      state.copyWith(
        selectedSoundId: soundId,
        defaultSoundId: state.isPerTopic ? state.defaultSoundId : soundId,
      ),
    );
  }

  /// Tapping play on the row already playing stops it.
  Future<void> togglePreview(AlarmSound sound) async {
    if (state.previewingSoundId == sound.id) {
      await _host.stopPreview();
      emit(state.copyWith(clearPreviewing: true));
      return;
    }
    await _host.stopPreview();
    final started = await _host.startPreview(sound);
    emit(
      started
          ? state.copyWith(previewingSoundId: sound.id)
          : state.copyWith(clearPreviewing: true),
    );
  }

  Future<void> stopPreview() async {
    if (state.previewingSoundId == null) return;
    await _host.stopPreview();
    if (!isClosed) emit(state.copyWith(clearPreviewing: true));
  }

  /// "Pick a file". Opens the platform picker and runs the cheap checks
  /// (size and type) before anything decodes the file. Hands back a file the
  /// cropper can open, or null. A file that fails is deleted from the cache
  /// and the screen shows why.
  ///
  /// With own sounds locked the platform picker never opens, and the
  /// screen opens the paywall instead.
  Future<PickedSoundFile?> pickFile() async {
    final ownSounds = _ownSounds();
    if (ownSoundsLockedBy(ownSounds)) {
      if (!isClosed && ownSounds != state.ownSounds) {
        emit(state.copyWith(ownSounds: ownSounds));
      }
      return null;
    }
    final picked = await _picker.pickOne();
    if (picked == null) return null;
    final rejection = checkPickedSound(
      fileName: picked.name,
      sizeBytes: picked.sizeBytes,
      platform: _platform,
    );
    if (rejection == null) return picked;
    await _picker.discard(picked.path);
    if (!isClosed) emit(state.copyWith(errorCode: rejection.name));
    return null;
  }

  /// Reads the user's sounds again once the cropper has closed, whatever it
  /// returned. [pendingSave] is a save still running when the user left; the
  /// list is read after it lands, so the new sound still shows.
  Future<void> reloadAfterCrop([Future<void>? pendingSave]) async {
    await pendingSave;
    if (isClosed) return;
    final userSounds = (await _repository.getUserSounds()).getOrDefault(
      const [],
    );
    await _host.publishSoundAssignments();
    if (!isClosed) emit(state.copyWith(userSounds: userSounds));
  }

  /// Deleting the sound in use drops the screen back onto whatever the
  /// repository fell back to, so the checkmark never points at nothing.
  Future<void> deleteUserSound(String soundId) async {
    if (state.previewingSoundId == soundId) await stopPreview();
    await _delete(soundId);
    await _host.publishSoundAssignments();
    final assignments = (await _repository.getAssignments()).getOrNull();
    final userSounds = (await _repository.getUserSounds()).getOrDefault(
      const [],
    );
    final defaultId = assignments?.defaultSoundId ?? BundledSounds.fallbackId;
    emit(
      state.copyWith(
        userSounds: userSounds,
        defaultSoundId: defaultId,
        selectedSoundId: state.isPerTopic
            ? assignments?.soundIdFor(state.topicName!) ?? defaultId
            : defaultId,
      ),
    );
  }

  void clearError() => emit(state.copyWith(clearError: true));

  @override
  Future<void> close() async {
    await _previewEnded.cancel();
    await _packChanges?.cancel();
    await _ownSoundsChanges?.cancel();
    await _host.stopPreview();
    return super.close();
  }
}
