import 'package:critalarm/core/sound/alarm_sound.dart';
import 'package:critalarm/features/settings/domain/crop_window.dart';

enum SoundCropStatus {
  /// Measuring the file and reading its waveform.
  loading,

  /// Waiting for the user to pick a range.
  ready,

  /// The file could not be opened. [SoundCropState.errorCode] says why.
  failed,

  /// This platform cannot import sounds. The screen leaves.
  unavailable,

  /// The cut is running.
  saving,

  /// The clip is saved. The screen leaves.
  saved,
}

/// What the cropper is showing.
class SoundCropState {
  const SoundCropState({
    this.status = SoundCropStatus.loading,
    this.name = '',
    this.window,
    this.peaks = const [],
    this.isPlaying = false,
    this.errorCode,
    this.saved,
  });

  final SoundCropStatus status;

  /// The name the sound is saved under. Starts as the file name.
  final String name;

  /// Null until the file has been measured.
  final CropWindow? window;

  /// Loudness across the whole file, about 100 values a second. The overview
  /// and the zoomed editor are both cut from this.
  final List<double> peaks;

  final bool isPlaying;

  /// `unreadable` or `sourceTooLong` when [status] is failed, `copyFailed`
  /// after a save that did not work.
  final String? errorCode;

  final AlarmSound? saved;

  SoundCropState copyWith({
    SoundCropStatus? status,
    String? name,
    CropWindow? window,
    List<double>? peaks,
    bool? isPlaying,
    String? errorCode,
    bool clearError = false,
    AlarmSound? saved,
  }) => SoundCropState(
    status: status ?? this.status,
    name: name ?? this.name,
    window: window ?? this.window,
    peaks: peaks ?? this.peaks,
    isPlaying: isPlaying ?? this.isPlaying,
    errorCode: clearError ? null : errorCode ?? this.errorCode,
    saved: saved ?? this.saved,
  );
}
