import 'dart:async';

import 'package:critalarm/core/access/app_feature.dart';
import 'package:critalarm/core/sound/alarm_sound.dart';
import 'package:critalarm/core/sound/bundled_sounds.dart';
import 'package:critalarm/core/sound/sound_host.dart';
import 'package:critalarm/core/sound/sound_pack_repository.dart';
import 'package:critalarm/features/settings/domain/personalize/personalize_rules.dart';
import 'package:critalarm/features/settings/domain/repositories/alarm_sound_repository.dart';
import 'package:critalarm/features/settings/presentation/cubits/personalize_state.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Drives the Personalize page.
///
/// It saves the default sound through the same repository the sound picker
/// uses, so a choice made on either shows on the other. It plays through
/// the picker's preview player and nothing else: one loop, at the preview
/// volume, with no vibration and no torch. It never touches an incident.
///
/// A locked option is tried, not picked: [tryOption] and [trySound] change
/// what the page shows and plays, and save nothing.
class PersonalizeCubit extends Cubit<PersonalizeState> {
  PersonalizeCubit(
    this._repository,
    this._host, {
    TargetPlatform? platform,
    this.nameOf,
    this._packs,
  }) : _platform = platform ?? defaultTargetPlatform,
       super(const PersonalizeState()) {
    _previewEnded = _host.previewEnded.listen((path) {
      if (isClosed) return;
      // A late event for a preview that was replaced says nothing about
      // the one playing now.
      final playing = state.soundById(state.playingSoundId);
      if (playing != null && playing.path == path) {
        emit(state.copyWith(clearPlaying: true));
      }
    });
  }

  final AlarmSoundRepository _repository;
  final SoundHost _host;
  final TargetPlatform _platform;
  final SoundPackRepository? _packs;
  late final StreamSubscription<String> _previewEnded;

  /// Turns a bundled or pack sound id into a name in the user's language.
  final String Function(String id)? nameOf;

  /// Reads the saved default and the sounds. Called when the page opens
  /// and again when a picker it opened closes.
  Future<void> load() async {
    final assignments = (await _repository.getAssignments()).getOrNull();
    final userSounds = (await _repository.getUserSounds()).getOrDefault(
      const [],
    );
    if (isClosed) return;
    emit(
      state.copyWith(
        isLoading: false,
        builtIn: BundledSounds.catalogue(platform: _platform, nameOf: nameOf),
        userSounds: userSounds,
        defaultSoundId: assignments?.defaultSoundId ?? BundledSounds.fallbackId,
      ),
    );
    final packs = _packs;
    if (packs == null) return;
    final installed = await packs.installedSounds(nameOf: nameOf);
    if (!isClosed) emit(state.copyWith(otherSounds: installed));
  }

  /// A sound the user may use: saved as the default and played once. Ends
  /// any try.
  Future<void> pickSound(AlarmSound sound) async {
    await _repository.setDefaultSoundId(sound.id);
    await _host.publishSoundAssignments();
    if (isClosed) return;
    emit(state.copyWith(defaultSoundId: sound.id, clearTried: true));
    await _play(sound);
  }

  /// A locked own sound: played once and shown as tried. Nothing is saved.
  Future<void> trySound(AlarmSound sound) async {
    emit(
      state.copyWith(
        tried: PersonalizeTry(AppFeature.ownSounds, optionId: sound.id),
      ),
    );
    await _play(sound);
  }

  /// A locked option of any section, tried in the preview. Nothing is
  /// saved.
  void tryOption(PersonalizeTry tried) => emit(state.copyWith(tried: tried));

  /// A free option was picked, or the tried option stopped being locked.
  void clearTry() {
    if (state.tried != null) emit(state.copyWith(clearTried: true));
  }

  /// The play button on the preview: plays the chosen sound once, or stops
  /// it. [ownSoundsLocked] is the access layer's answer, handed in by the
  /// page, so the button plays what really rings.
  Future<void> togglePlay({required bool ownSoundsLocked}) async {
    if (state.isPlaying) return stopPlaying();
    final sound = state.chosenSound(ownSoundsLocked: ownSoundsLocked);
    if (sound != null) await _play(sound);
  }

  Future<void> stopPlaying() async {
    if (!state.isPlaying) return;
    await _host.stopPreview();
    if (!isClosed) emit(state.copyWith(clearPlaying: true));
  }

  Future<void> _play(AlarmSound sound) async {
    await _host.stopPreview();
    final started = await _host.startPreview(sound);
    if (isClosed) return;
    emit(
      started
          ? state.copyWith(playingSoundId: sound.id)
          : state.copyWith(clearPlaying: true),
    );
  }

  @override
  Future<void> close() async {
    await _previewEnded.cancel();
    await _host.stopPreview();
    return super.close();
  }
}
