import 'package:critalarm/core/sound/alarm_sound.dart';
import 'package:critalarm/core/sound/bundled_sounds.dart';
import 'package:critalarm/core/sound/sound_host.dart';
import 'package:critalarm/features/settings/domain/repositories/alarm_sound_repository.dart';
import 'package:critalarm/features/settings/domain/repositories/sound_file_picker.dart';
import 'package:critalarm/features/settings/domain/usecases/delete_user_sound_usecase.dart';
import 'package:critalarm/features/settings/domain/usecases/import_sound_usecase.dart';
import 'package:critalarm/features/settings/presentation/cubits/sound_picker_state.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Drives the sound picker. One instance per open, for one topic or for the
/// global default.
class SoundPickerCubit extends Cubit<SoundPickerState> {
  SoundPickerCubit(
    this._repository,
    this._host,
    this._import,
    this._delete,
    this._picker, {
    TargetPlatform? platform,
    this.nameOf,
  }) : _platform = platform ?? defaultTargetPlatform,
       super(const SoundPickerState());

  /// Turns a bundled sound id into a name in the user's language. Left null
  /// in tests, which fall back to the English names in the catalogue.
  final String Function(String id)? nameOf;

  final AlarmSoundRepository _repository;
  final SoundHost _host;
  final ImportSoundUsecase _import;
  final DeleteUserSoundUsecase _delete;
  final SoundFilePicker _picker;
  final TargetPlatform _platform;

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

  /// "Add your own". Opens the platform picker, checks the caps, copies the
  /// file in.
  Future<void> importSound() async {
    final picked = await _picker.pickOne();
    if (picked == null) return;
    emit(state.copyWith(isImporting: true, clearError: true));
    final result = await _import(picked);
    final sound = result.getOrNull();
    if (sound == null) {
      emit(
        state.copyWith(
          isImporting: false,
          errorCode: result.exceptionOrNull()?.message ?? 'copyFailed',
        ),
      );
      return;
    }
    await _host.publishSoundAssignments();
    emit(
      state.copyWith(
        isImporting: false,
        userSounds: [...state.userSounds, sound],
      ),
    );
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
    await _host.stopPreview();
    return super.close();
  }
}
