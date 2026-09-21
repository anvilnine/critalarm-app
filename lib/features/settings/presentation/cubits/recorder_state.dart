import 'package:critalarm/core/sound/sound_import.dart';
import 'package:critalarm/design/faces/face_state.dart';

enum RecorderStatus {
  /// Waiting for the first tap.
  ready,

  /// Asking for the microphone and starting up.
  starting,

  /// The microphone is on.
  recording,

  /// Finishing the file after a stop.
  stopping,

  /// The file is done. [RecorderState.recorded] goes to the cropper.
  stopped,

  /// The user said no to the microphone.
  denied,

  /// A call or another app cut the recording short before anything usable
  /// was recorded.
  interrupted,
}

/// What the recorder is showing.
class RecorderState {
  const RecorderState({
    required this.maxDuration,
    this.status = RecorderStatus.ready,
    this.elapsed = Duration.zero,
    this.levels = const [],
    this.isLoud = false,
    this.recorded,
    this.alarmRinging = false,
  });

  /// How many bars the live panel holds. Older ones scroll off the left.
  static const barCount = 60;

  /// The warning starts this long before the max.
  static const lastSeconds = Duration(seconds: 5);

  final RecorderStatus status;
  final Duration elapsed;
  final Duration maxDuration;

  /// The most recent loudness readings, 0 to 1, oldest first.
  final List<double> levels;

  /// True while a loud spike keeps going.
  final bool isLoud;

  /// The finished file, set once [status] is stopped.
  final PickedSoundFile? recorded;

  /// An alarm was ringing at the last check. The record button looks
  /// disabled, and a tap checks again.
  final bool alarmRinging;

  double get progress => maxDuration <= Duration.zero
      ? 0
      : (elapsed.inMicroseconds / maxDuration.inMicroseconds).clamp(0.0, 1.0);

  bool get isRecording => status == RecorderStatus.recording;

  bool get isLastSeconds => isRecording && elapsed >= maxDuration - lastSeconds;

  /// Whether the timer is drawn right now. In the last 5 seconds it blinks,
  /// half a second on and half a second off, unless the user asked for less
  /// motion.
  bool showsTimer({required bool reduceMotion}) {
    if (!isLastSeconds || reduceMotion) return true;
    final intoWarning = elapsed - (maxDuration - lastSeconds);
    return intoWarning.inMilliseconds % 1000 < 500;
  }

  FaceState get face => switch (status) {
    RecorderStatus.denied => FaceState.sad,
    RecorderStatus.interrupted => FaceState.confused,
    RecorderStatus.stopped => FaceState.success,
    RecorderStatus.recording || RecorderStatus.stopping =>
      isLastSeconds
          ? FaceState.worried
          : isLoud
          ? FaceState.surprised
          : FaceState.interested,
    RecorderStatus.ready || RecorderStatus.starting => FaceState.calm,
  };

  RecorderState copyWith({
    RecorderStatus? status,
    Duration? elapsed,
    List<double>? levels,
    bool? isLoud,
    PickedSoundFile? recorded,
    bool clearRecorded = false,
    bool? alarmRinging,
  }) => RecorderState(
    maxDuration: maxDuration,
    status: status ?? this.status,
    elapsed: elapsed ?? this.elapsed,
    levels: levels ?? this.levels,
    isLoud: isLoud ?? this.isLoud,
    recorded: clearRecorded ? null : recorded ?? this.recorded,
    alarmRinging: alarmRinging ?? this.alarmRinging,
  );
}
