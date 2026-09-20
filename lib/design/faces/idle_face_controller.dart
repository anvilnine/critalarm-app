import 'dart:async';
import 'dart:math' as math;

import 'package:critalarm/design/faces/face_state.dart';
import 'package:flutter/foundation.dart';

/// Where the idle face is inside one beat.
enum IdleFacePhase {
  /// Calm, waiting for the next beat.
  resting,

  /// Turning from calm into the beat.
  entering,

  /// Holding the beat.
  holding,

  /// Turning from the beat back into calm.
  leaving,
}

/// Runs the small idle beats the face plays while nothing is wrong: wait, put
/// on a face, hold it, go back to calm, wait again.
///
/// Holds no widgets, so it tests without a screen.
class IdleFaceController extends ChangeNotifier {
  /// [random] and [delay] are only swapped out by tests.
  IdleFaceController({
    math.Random? random,
    Future<void> Function(Duration)? delay,
  }) : _random = random ?? math.Random(),
       _injectedDelay = delay;

  /// The only faces a beat may show. Every other face means something real,
  /// and some of them change the colour of the head.
  static const List<FaceState> beats = [
    FaceState.watching,
    FaceState.skeptical,
  ];

  /// Shortest wait between two beats.
  static const Duration minGap = Duration(milliseconds: 2400);

  /// Longest wait between two beats.
  static const Duration maxGap = Duration(milliseconds: 4800);

  /// How long calm takes to turn into the beat.
  static const Duration enterBlend = Duration(milliseconds: 420);

  /// How long the beat stays on.
  static const Duration hold = Duration(milliseconds: 1100);

  /// How long the beat takes to turn back into calm.
  static const Duration leaveBlend = Duration(milliseconds: 520);

  final math.Random _random;
  final Future<void> Function(Duration)? _injectedDelay;

  Timer? _timer;
  Completer<void>? _waiting;
  bool _disposed = false;
  int _run = 0;

  /// Where the beat is.
  IdleFacePhase get phase => _phase;
  IdleFacePhase _phase = IdleFacePhase.resting;

  /// The face this beat shows. Calm between beats.
  FaceState get beat => _beat;
  FaceState _beat = FaceState.calm;

  /// True while the loop is running.
  bool get isRunning => _running;
  bool _running = false;

  /// Starts the loop. Does nothing when it is already running.
  Future<void> start() async {
    if (_running || _disposed) return;
    _running = true;
    final run = ++_run;

    while (_keepGoing(run)) {
      await _wait(_gap());
      if (!_keepGoing(run)) return;

      _beat = beats[_random.nextInt(beats.length)];
      _set(IdleFacePhase.entering, run);
      await _wait(enterBlend);
      if (!_keepGoing(run)) return;

      _set(IdleFacePhase.holding, run);
      await _wait(hold);
      if (!_keepGoing(run)) return;

      _set(IdleFacePhase.leaving, run);
      await _wait(leaveBlend);
      if (!_keepGoing(run)) return;

      _beat = FaceState.calm;
      _set(IdleFacePhase.resting, run);
    }
  }

  /// Stops the loop and settles back on calm. Nothing is left waiting.
  void stop() {
    if (!_running && _phase == IdleFacePhase.resting) return;
    _running = false;
    _run++;
    _stopWaiting();
    _beat = FaceState.calm;
    if (_phase != IdleFacePhase.resting) {
      _phase = IdleFacePhase.resting;
      if (!_disposed) notifyListeners();
    }
  }

  bool _keepGoing(int run) => _running && !_disposed && run == _run;

  void _set(IdleFacePhase phase, int run) {
    if (!_keepGoing(run)) return;
    _phase = phase;
    notifyListeners();
  }

  Duration _gap() {
    final span = maxGap.inMilliseconds - minGap.inMilliseconds;
    return Duration(
      milliseconds: minGap.inMilliseconds + _random.nextInt(span + 1),
    );
  }

  /// Waits [d]. Without an injected delay this runs a timer the controller can
  /// cancel, so no wait is still ticking once the loop is stopped.
  Future<void> _wait(Duration d) {
    final delay = _injectedDelay;
    if (delay != null) return delay(d);

    final waiting = _waiting = Completer<void>();
    _timer = Timer(d, () {
      _timer = null;
      _waiting = null;
      if (!waiting.isCompleted) waiting.complete();
    });
    return waiting.future;
  }

  void _stopWaiting() {
    _timer?.cancel();
    _timer = null;
    final waiting = _waiting;
    _waiting = null;
    if (waiting != null && !waiting.isCompleted) waiting.complete();
  }

  @override
  void dispose() {
    _running = false;
    _disposed = true;
    _run++;
    _stopWaiting();
    super.dispose();
  }
}
