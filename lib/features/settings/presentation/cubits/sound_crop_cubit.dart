import 'dart:async';

import 'package:critalarm/core/sound/sound_host.dart';
import 'package:critalarm/core/sound/sound_import.dart';
import 'package:critalarm/features/settings/domain/crop_window.dart';
import 'package:critalarm/features/settings/domain/repositories/sound_file_picker.dart';
import 'package:critalarm/features/settings/domain/usecases/import_sound_usecase.dart';
import 'package:critalarm/features/settings/presentation/cubits/sound_crop_state.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Drives the cropper for one picked file.
///
/// The file is a copy in the app's cache. It is deleted when the cropper
/// closes, but only after a save that is still running has finished with it.
class SoundCropCubit extends Cubit<SoundCropState> {
  SoundCropCubit(
    this._host,
    this._import,
    this._picker, {
    TargetPlatform? platform,
  }) : _platform = platform ?? defaultTargetPlatform,
       super(const SoundCropState()) {
    _previewEnded = _host.previewEnded.listen((path) {
      final file = _file;
      if (isClosed || file == null || path != file.path) return;
      if (state.isPlaying) emit(state.copyWith(isPlaying: false));
    });
  }

  /// How finely the whole file's loudness is read. Enough for the zoomed
  /// editor to stay sharp at its tightest, and cheap enough to hold 20
  /// minutes of it.
  static const peaksPerSecond = 100;

  /// One step of a handle or the window for a screen reader.
  static const nudge = Duration(milliseconds: 500);

  final SoundHost _host;
  final ImportSoundUsecase _import;
  final SoundFilePicker _picker;
  final TargetPlatform _platform;
  late final StreamSubscription<String> _previewEnded;

  PickedSoundFile? _file;
  Future<void>? _pendingSave;
  final String _peaksToken = 'crop_${DateTime.now().microsecondsSinceEpoch}';

  /// Done when no save is running. A save the user left behind keeps going,
  /// so whoever opened the cropper waits on this before reading the list.
  Future<void> get pendingSave => _pendingSave ?? Future<void>.value();

  Future<void> load(PickedSoundFile file) async {
    _file = file;
    final capabilities = await _host.capabilities();
    if (isClosed) return;
    if (!capabilities.canImportSounds) {
      emit(state.copyWith(status: SoundCropStatus.unavailable));
      return;
    }
    emit(state.copyWith(name: ImportSoundUsecase.displayNameFor(file.name)));

    final length = await _host.probeDuration(file.path);
    if (isClosed) return;
    final rejection = checkSourceDuration(length);
    if (rejection != null) {
      emit(
        state.copyWith(
          status: SoundCropStatus.failed,
          errorCode: rejection.name,
        ),
      );
      return;
    }

    final peaks = await _host.readPeaks(
      path: file.path,
      isAsset: false,
      count: (length.inMilliseconds * peaksPerSecond / 1000).ceil(),
      cancelToken: _peaksToken,
    );
    if (isClosed) return;
    emit(
      state.copyWith(
        status: SoundCropStatus.ready,
        peaks: peaks,
        window: CropWindow.initial(
          fileLength: length,
          maxLength: SoundImportLimits.maxClipDuration(_platform),
          peaks: peaks,
        ),
      ),
    );
  }

  /// An empty name goes back to the file name.
  void rename(String name) {
    final trimmed = name.trim();
    final file = _file;
    emit(
      state.copyWith(
        name: trimmed.isEmpty && file != null
            ? ImportSoundUsecase.displayNameFor(file.name)
            : trimmed,
      ),
    );
  }

  void moveBy(Duration delta) => _change((w) => w.move(delta));

  void centerOn(Duration at) => _change((w) => w.centerOn(at));

  void dragStart(Duration to) => _change((w) => w.dragStart(to));

  void dragEnd(Duration to) => _change((w) => w.dragEnd(to));

  /// Every change to the window stops playback, so what plays next is what
  /// is selected.
  void _change(CropWindow Function(CropWindow window) change) {
    final window = state.window;
    if (window == null || state.status != SoundCropStatus.ready) return;
    if (state.isPlaying) unawaited(_host.stopPreview());
    emit(state.copyWith(window: change(window), isPlaying: false));
  }

  Future<void> togglePlay() async {
    final file = _file;
    final window = state.window;
    if (file == null || window == null) return;
    if (state.isPlaying) {
      await _host.stopPreview();
      if (!isClosed) emit(state.copyWith(isPlaying: false));
      return;
    }
    final started = await _host.startClipPreview(
      path: file.path,
      start: window.start,
      end: window.end,
    );
    if (!isClosed) emit(state.copyWith(isPlaying: started));
  }

  /// Cuts and saves the window. Keeps running if the user leaves.
  Future<void> save() {
    final file = _file;
    final window = state.window;
    if (file == null ||
        window == null ||
        state.status != SoundCropStatus.ready) {
      return pendingSave;
    }
    if (state.isPlaying) unawaited(_host.stopPreview());
    emit(
      state.copyWith(
        status: SoundCropStatus.saving,
        isPlaying: false,
        clearError: true,
      ),
    );
    final save =
        _import(
          file: file,
          name: state.name,
          start: window.start,
          end: window.end,
        ).then((result) {
          if (isClosed) return;
          final sound = result.getOrNull();
          emit(
            sound == null
                ? state.copyWith(
                    status: SoundCropStatus.ready,
                    errorCode:
                        result.exceptionOrNull()?.message ?? 'copyFailed',
                  )
                : state.copyWith(status: SoundCropStatus.saved, saved: sound),
          );
        });
    _pendingSave = save;
    return save;
  }

  void clearError() => emit(state.copyWith(clearError: true));

  @override
  Future<void> close() async {
    await _previewEnded.cancel();
    await _host.cancelPeaks(_peaksToken);
    if (state.isPlaying) await _host.stopPreview();
    final file = _file;
    if (file != null) {
      unawaited(pendingSave.whenComplete(() => _picker.discard(file.path)));
    }
    return super.close();
  }
}
