import 'dart:async';

import 'package:critalarm/core/sound/alarm_sound.dart';
import 'package:critalarm/core/sound/bundled_sounds.dart';
import 'package:critalarm/core/sound/sound_host.dart';
import 'package:critalarm/core/sound/sound_import.dart';
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
  }) : _platform = platform ?? defaultTargetPlatform,
       super(const SoundPickerState()) {
    _previewEnded = _host.previewEnded.listen((path) {
      if (isClosed) return;
      final playing = state.previewingSoundId;
      // A late event for a preview that has since been replaced says nothing
      // about the one playing now.
      final match = [...state.bundled, ...state.userSounds].where(
        (s) => s.id == playing && s.path == path,
      );
      if (match.isNotEmpty) emit(state.copyWith(clearPreviewing: true));
    });
  }

  /// Turns a bundled sound id into a name in the user's language. Left null
  /// in tests, which fall back to the English names in the catalogue.
  final String Function(String id)? nameOf;

  final AlarmSoundRepository _repository;
  final SoundHost _host;
  final DeleteUserSoundUsecase _delete;
  final SoundFilePicker _picker;
  final SoundPeaksCache _peaksCache;
  final TargetPlatform _platform;
  late final StreamSubscription<String> _previewEnded;

  /// [topicName] null means this screen is choosing the global default.
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
        bundled: BundledSounds.catalogue(
          platform: _platform,
          nameOf: nameOf,
        ),
        userSounds: userSounds,
        selectedSoundId: selected,
        defaultSoundId: defaultId,
        topicName: topicName,
        capabilities: await _host.capabilities(),
        platform: _platform,
      ),
    );
    await Future.wait([_fillBundledPeaks(), _backfillUserPeaks()]);
  }

  Future<void> _fillBundledPeaks() async {
    await Future.wait([
      for (final sound in state.bundled)
        if (sound.peaks == null)
          _peaksCache.load(sound).then((peaks) {
            if (isClosed || peaks.isEmpty) return;
            emit(
              state.copyWith(
                bundled: [
                  for (final s in state.bundled)
                    s.id == sound.id ? s.copyWith(peaks: peaks) : s,
                ],
              ),
            );
          }),
    ]);
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

  Future<void> select(String soundId) async {
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
  Future<PickedSoundFile?> pickFile() async {
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
    await _host.stopPreview();
    return super.close();
  }
}
