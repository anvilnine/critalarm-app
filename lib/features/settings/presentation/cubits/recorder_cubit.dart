import 'dart:async';

import 'package:critalarm/core/sound/sound_import.dart';
import 'package:critalarm/core/sound/sound_recorder.dart';
import 'package:critalarm/features/settings/presentation/cubits/recorder_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Records one clip from the microphone and hands it to the cropper.
///
/// Time comes from the clock it is given and moves on each loudness reading,
/// which arrives about every 70 ms, so tests can drive it without waiting.
class RecorderCubit extends Cubit<RecorderState> {
  RecorderCubit(
    this._recorder, {
    required Duration maxDuration,
    required this._isRinging,
    required this._stopPreview,
    DateTime Function()? now,
    Timer Function(Duration after, void Function() run)? startTimer,
  }) : _now = now ?? DateTime.now,
       _startTimer = startTimer ?? Timer.new,
       super(RecorderState(maxDuration: maxDuration)) {
    _interruptions = _recorder.interrupted.listen(
      (_) => unawaited(interrupt()),
    );
  }

  /// Louder than this counts as a spike. dBFS, so 0 is the loudest.
  static const loudLevel = -6.0;

  /// A spike has to last this long to surprise the face.
  static const loudHold = Duration(milliseconds: 300);

  /// And the face stays surprised this long after it ends, so it does not
  /// flicker.
  static const loudLinger = Duration(milliseconds: 500);

  /// The shortest clip the cropper accepts.
  static const minUsable = Duration(seconds: 1);

  /// Readings at or below this draw as a flat bar.
  static const _quietLevel = -50.0;

  final SoundRecorder _recorder;
  final Future<bool> Function() _isRinging;
  final Future<void> Function() _stopPreview;
  final DateTime Function() _now;
  final Timer Function(Duration after, void Function() run) _startTimer;
  late final StreamSubscription<void> _interruptions;
  StreamSubscription<double>? _levels;

  String? _path;
  DateTime? _startedAt;
  DateTime? _loudSince;
  DateTime? _lastLoud;

  /// Stops the recording at the max even if the loudness readings stall.
  Timer? _maxTimer;

  /// True once the cropper owns the recorded file.
  bool _handedOff = false;

  /// Starts on the first tap and stops on the next one.
  Future<void> toggle() async {
    switch (state.status) {
      case RecorderStatus.recording:
        await _stop();
      case RecorderStatus.ready ||
          RecorderStatus.denied ||
          RecorderStatus.interrupted:
        await _start();
      case RecorderStatus.starting ||
          RecorderStatus.stopping ||
          RecorderStatus.stopped:
        break;
    }
  }

  Future<void> _start() async {
    // A ringing alarm comes first. On Android the alarm does not take the
    // audio, so nothing else would stop the two from overlapping.
    final ringing = await _isRinging();
    if (isClosed) return;
    if (ringing != state.alarmRinging) {
      emit(state.copyWith(alarmRinging: ringing));
    }
    if (ringing) return;
    final back = state.status;
    emit(state.copyWith(status: RecorderStatus.starting));
    final allowed = await _recorder.requestPermission();
    if (isClosed) return;
    if (!allowed) {
      emit(state.copyWith(status: RecorderStatus.denied));
      return;
    }
    // On iOS stopping a preview turns the audio session off, which would cut
    // a recording that had already started.
    await _stopPreview();
    final path = await _recorder.start();
    if (isClosed) {
      if (path != null) await _recorder.cancel();
      return;
    }
    if (path == null) {
      emit(
        state.copyWith(
          status: back == RecorderStatus.denied ? RecorderStatus.ready : back,
        ),
      );
      return;
    }
    _path = path;
    _startedAt = _now();
    _loudSince = null;
    _lastLoud = null;
    emit(
      state.copyWith(
        status: RecorderStatus.recording,
        elapsed: Duration.zero,
        levels: const [],
        isLoud: false,
        clearRecorded: true,
      ),
    );
    _maxTimer?.cancel();
    _maxTimer = _startTimer(state.maxDuration, () => unawaited(_stop()));
    await _levels?.cancel();
    _levels = _recorder.levels.listen(_onLevel);
  }

  void _onLevel(double db) {
    final startedAt = _startedAt;
    if (isClosed || !state.isRecording || startedAt == null) return;
    final now = _now();
    // Readings only move the timer and the bars. The max timer stops it.
    var elapsed = now.difference(startedAt);
    if (elapsed > state.maxDuration) elapsed = state.maxDuration;

    if (db > loudLevel) {
      _loudSince ??= now;
      _lastLoud = now;
    } else {
      _loudSince = null;
    }
    final loudSince = _loudSince;
    final lastLoud = _lastLoud;
    final isLoud =
        (loudSince != null && now.difference(loudSince) >= loudHold) ||
        (state.isLoud &&
            lastLoud != null &&
            now.difference(lastLoud) < loudLinger);

    final levels = [...state.levels, _barHeight(db)];
    if (levels.length > RecorderState.barCount) {
      levels.removeRange(0, levels.length - RecorderState.barCount);
    }
    emit(state.copyWith(elapsed: elapsed, levels: levels, isLoud: isLoud));
  }

  static double _barHeight(double db) {
    if (db.isNaN || db <= _quietLevel) return 0.04;
    return ((db - _quietLevel) / -_quietLevel).clamp(0.04, 1.0);
  }

  /// A call, an alarm or the app going to the background. Keeps what was
  /// recorded if there is enough of it to crop.
  Future<void> interrupt() async {
    if (!state.isRecording) return;
    await _stop(interrupted: true);
  }

  Future<void> _stop({bool interrupted = false}) async {
    if (!state.isRecording) return;
    final atMax = _maxTimer != null && !_maxTimer!.isActive;
    _maxTimer?.cancel();
    _maxTimer = null;
    emit(
      state.copyWith(
        status: RecorderStatus.stopping,
        isLoud: false,
        elapsed: atMax ? state.maxDuration : null,
      ),
    );
    await _levels?.cancel();
    _levels = null;
    final startedAt = _startedAt;
    final written = await _recorder.stop() ?? _path;
    _path = null;
    if (written == null) {
      if (!isClosed) emit(state.copyWith(status: RecorderStatus.ready));
      return;
    }
    if (state.elapsed < minUsable) {
      await _recorder.delete(written);
      if (isClosed) return;
      emit(
        state.copyWith(
          status: interrupted
              ? RecorderStatus.interrupted
              : RecorderStatus.ready,
          elapsed: Duration.zero,
          levels: const [],
        ),
      );
      return;
    }
    final size = await _recorder.sizeOf(written);
    final file = PickedSoundFile(
      path: written,
      name: '${_fileStem(startedAt ?? _now())}.m4a',
      sizeBytes: size,
    );
    if (isClosed) {
      // Nobody is left to hand it to.
      await _recorder.delete(written);
      return;
    }
    emit(state.copyWith(status: RecorderStatus.stopped, recorded: file));
  }

  /// `2026-09-22 14.32`. The cropper shows it as the name, and the user can
  /// change it there.
  static String _fileStem(DateTime t) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${t.year}-${two(t.month)}-${two(t.day)} '
        '${two(t.hour)}.${two(t.minute)}';
  }

  /// Asks again whether an alarm rings, for the record button's look.
  Future<void> checkRinging() async {
    final ringing = await _isRinging();
    if (!isClosed && ringing != state.alarmRinging) {
      emit(state.copyWith(alarmRinging: ringing));
    }
  }

  Future<void> openSettings() => _recorder.openSettings();

  /// Gives the recorded file to the cropper, which deletes it when it
  /// closes. Until then this cubit deletes it on close.
  PickedSoundFile? handOff() {
    final file = state.recorded;
    if (file != null) _handedOff = true;
    return file;
  }

  @override
  Future<void> close() async {
    await _interruptions.cancel();
    _maxTimer?.cancel();
    await _levels?.cancel();
    final recorded = state.recorded;
    if (recorded != null && !_handedOff) {
      // Closed before the cropper took it.
      await _recorder.delete(recorded.path);
    }
    if (_path != null) {
      // Closed mid-recording: nobody asked for this clip.
      _path = null;
      await _recorder.cancel();
    }
    await _recorder.dispose();
    return super.close();
  }
}
