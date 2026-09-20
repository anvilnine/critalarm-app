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

  /// Nodded off, and staying that way until it is tapped.
  dozing,
}

/// One thing the face can do while nothing is happening.
class IdleBeat {
  /// A beat that puts on [face], takes [enter] to get there, holds it for
  /// [hold], and takes [leave] to come back.
  const IdleBeat(
    this.face, {
    required this.weight,
    this.enter = const Duration(milliseconds: 380),
    this.hold = const Duration(milliseconds: 800),
    this.leave = const Duration(milliseconds: 460),
    this.thenPlay,
  });

  /// The face this beat wears.
  final FaceState face;

  /// How often this beat comes up against the others. Bigger is more often.
  final int weight;

  /// How long calm takes to turn into [face].
  final Duration enter;

  /// How long [face] stays on.
  final Duration hold;

  /// How long [face] takes to turn back.
  final Duration leave;

  /// A beat that follows straight on with no wait, which is what makes two
  /// small movements read as one thing somebody did.
  final IdleBeat? thenPlay;
}

/// Runs the small things the face does while nothing is wrong: wait, do
/// something, go back to calm, wait again. Every so often it nods off, and
/// then it stays asleep until somebody taps it.
///
/// Holds no widgets, so it tests without a screen.
class IdleFaceController extends ChangeNotifier {
  /// [random], [delay] and [now] are only swapped out by tests.
  IdleFaceController({
    math.Random? random,
    Future<void> Function(Duration)? delay,
    DateTime Function()? now,
  }) : _random = random ?? math.Random(),
       _injectedDelay = delay,
       _now = now ?? DateTime.now;

  /// A blink, which is most of what a resting face does.
  static const IdleBeat blink = IdleBeat(
    FaceState.blink,
    weight: 30,
    enter: Duration(milliseconds: 90),
    hold: Duration(milliseconds: 70),
    leave: Duration(milliseconds: 120),
  );

  /// Two blinks close together.
  static const IdleBeat doubleBlink = IdleBeat(
    FaceState.blink,
    weight: 10,
    enter: Duration(milliseconds: 90),
    hold: Duration(milliseconds: 60),
    leave: Duration(milliseconds: 110),
    thenPlay: IdleBeat(
      FaceState.blink,
      weight: 0,
      enter: Duration(milliseconds: 90),
      hold: Duration(milliseconds: 60),
      leave: Duration(milliseconds: 130),
    ),
  );

  /// Everything the face might do, and how often. A beat that ends in a
  /// blink reads as somebody finishing a thought.
  static const List<IdleBeat> beats = [
    blink,
    doubleBlink,
    IdleBeat(
      FaceState.lookLeft,
      weight: 9,
      enter: Duration(milliseconds: 520),
      hold: Duration(milliseconds: 1900),
      leave: Duration(milliseconds: 780),
      thenPlay: blink,
    ),
    IdleBeat(
      FaceState.lookRight,
      weight: 9,
      enter: Duration(milliseconds: 520),
      hold: Duration(milliseconds: 1900),
      leave: Duration(milliseconds: 780),
      thenPlay: blink,
    ),
    IdleBeat(
      FaceState.content,
      weight: 9,
      enter: Duration(milliseconds: 720),
      hold: Duration(milliseconds: 1800),
      leave: Duration(milliseconds: 860),
    ),
    IdleBeat(
      FaceState.curious,
      weight: 7,
      enter: Duration(milliseconds: 580),
      hold: Duration(milliseconds: 1600),
      leave: Duration(milliseconds: 760),
      thenPlay: blink,
    ),
    IdleBeat(
      FaceState.breatheIn,
      weight: 6,
      enter: Duration(milliseconds: 1300),
      hold: Duration(milliseconds: 700),
      leave: Duration(milliseconds: 160),
      thenPlay: IdleBeat(
        FaceState.breatheOut,
        weight: 0,
        enter: Duration(milliseconds: 420),
        hold: Duration(milliseconds: 1000),
        leave: Duration(milliseconds: 1200),
      ),
    ),
    IdleBeat(
      FaceState.thinking,
      weight: 5,
      enter: Duration(milliseconds: 640),
      hold: Duration(milliseconds: 2100),
      leave: Duration(milliseconds: 800),
      thenPlay: blink,
    ),
    IdleBeat(
      FaceState.happy,
      weight: 4,
      enter: Duration(milliseconds: 500),
      hold: Duration(milliseconds: 1500),
      leave: Duration(milliseconds: 700),
    ),
    IdleBeat(
      FaceState.interested,
      weight: 4,
      enter: Duration(milliseconds: 420),
      hold: Duration(milliseconds: 1300),
      leave: Duration(milliseconds: 640),
    ),
    IdleBeat(
      FaceState.proud,
      weight: 3,
      enter: Duration(milliseconds: 580),
      hold: Duration(milliseconds: 1600),
      leave: Duration(milliseconds: 760),
    ),
    IdleBeat(
      FaceState.cheeky,
      weight: 3,
      enter: Duration(milliseconds: 340),
      hold: Duration(milliseconds: 1100),
      leave: Duration(milliseconds: 560),
    ),
    IdleBeat(
      FaceState.shakeHead,
      weight: 2,
      enter: Duration(milliseconds: 320),
      hold: Duration(milliseconds: 1000),
      leave: Duration(milliseconds: 520),
      thenPlay: blink,
    ),
    IdleBeat(
      FaceState.skeptical,
      weight: 2,
      enter: Duration(milliseconds: 580),
      hold: Duration(milliseconds: 1600),
      leave: Duration(milliseconds: 780),
    ),
    IdleBeat(
      FaceState.yawn,
      weight: 3,
      enter: Duration(milliseconds: 760),
      hold: Duration(milliseconds: 1600),
      leave: Duration(milliseconds: 900),
      thenPlay: IdleBeat(
        FaceState.sleepy,
        weight: 0,
        enter: Duration(milliseconds: 440),
        hold: Duration(milliseconds: 1300),
        leave: Duration(milliseconds: 780),
      ),
    ),
  ];

  /// Waking up after a doze.
  static const IdleBeat waking = IdleBeat(
    FaceState.wakesUp,
    weight: 0,
    enter: Duration(milliseconds: 220),
    hold: Duration(milliseconds: 900),
    leave: Duration(milliseconds: 620),
  );

  /// The two beats a tired face does more of late at night.
  static const Set<FaceState> tiredFaces = {FaceState.yawn, FaceState.sleepy};

  /// How much more often a tired beat comes up outside [dayStarts] to
  /// [dayEnds].
  static const int nightLift = 9;

  /// The first hour of the day, for deciding how tired the face acts.
  static const int dayStarts = 7;

  /// The hour the evening starts.
  static const int dayEnds = 21;

  /// Shortest wait between two beats. A face that does something every
  /// couple of seconds reads as twitchy, so the waits are long.
  static const Duration minGap = Duration(milliseconds: 3000);

  /// Longest wait between two beats.
  static const Duration maxGap = Duration(milliseconds: 7000);

  /// How long the face idles, untouched, before it nods off.
  static const Duration dozeAfter = Duration(seconds: 100);

  /// And at night, when it gives up sooner.
  static const Duration dozeAfterAtNight = Duration(seconds: 45);

  final math.Random _random;
  final Future<void> Function(Duration)? _injectedDelay;
  final DateTime Function() _now;

  Timer? _timer;
  Completer<void>? _waiting;
  bool _disposed = false;
  int _run = 0;
  Duration _awake = Duration.zero;

  /// Where the beat is.
  IdleFacePhase get phase => _phase;
  IdleFacePhase _phase = IdleFacePhase.resting;

  /// The face this beat shows. Calm between beats.
  FaceState get beat => _beat;
  FaceState _beat = FaceState.calm;

  /// How long the current beat's blend runs for.
  Duration get blend => _blend;
  Duration _blend = Duration.zero;

  /// True while the loop is running.
  bool get isRunning => _running;
  bool _running = false;

  /// True when tapping the face would wake it.
  bool get isDozing => _phase == IdleFacePhase.dozing;

  /// True when the clock says it is late enough to act tired.
  bool get isNight {
    final hour = _now().hour;
    return hour < dayStarts || hour >= dayEnds;
  }

  /// Starts the loop. Does nothing when it is already running.
  Future<void> start() async {
    if (_running || _disposed) return;
    _running = true;
    _awake = Duration.zero;
    await _loop(++_run);
  }

  /// Taps the face awake, and picks the loop back up. Does nothing unless it
  /// is asleep.
  Future<void> wake() async {
    if (_phase != IdleFacePhase.dozing) return;
    final run = _run;
    _awake = Duration.zero;
    _stopWaiting();
    await _play(waking, run);
    if (!_keepGoing(run)) return;
    await _loop(run);
  }

  /// Waits, does something, waits again, until it runs out of steam and nods
  /// off. Nodding off ends the loop: only a tap starts it again.
  Future<void> _loop(int run) async {
    while (_keepGoing(run)) {
      final gap = _gap();
      await _wait(gap);
      if (!_keepGoing(run)) return;
      _awake += gap;

      if (_awake >= (isNight ? dozeAfterAtNight : dozeAfter)) {
        await _nodOff(run);
        return;
      }

      await _play(_pick(), run);
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

  /// Runs one beat all the way through, and whatever follows it.
  Future<void> _play(IdleBeat move, int run) async {
    _beat = move.face;
    _blend = move.enter;
    _set(IdleFacePhase.entering, run);
    await _wait(move.enter);
    if (!_keepGoing(run)) return;

    _set(IdleFacePhase.holding, run);
    await _wait(move.hold);
    if (!_keepGoing(run)) return;

    final next = move.thenPlay;
    if (next != null) {
      // Straight into the next one, so the two read as one movement.
      _beat = next.face;
      _blend = next.enter;
      _set(IdleFacePhase.entering, run);
      await _wait(next.enter);
      if (!_keepGoing(run)) return;

      _set(IdleFacePhase.holding, run);
      await _wait(next.hold);
      if (!_keepGoing(run)) return;

      _blend = next.leave;
      _set(IdleFacePhase.leaving, run);
      await _wait(next.leave);
    } else {
      _blend = move.leave;
      _set(IdleFacePhase.leaving, run);
      await _wait(move.leave);
    }
    if (!_keepGoing(run)) return;

    _beat = FaceState.calm;
    _set(IdleFacePhase.resting, run);
  }

  /// Gets sleepy, then drops off and stays there.
  Future<void> _nodOff(int run) async {
    _beat = FaceState.sleepy;
    _blend = const Duration(milliseconds: 700);
    _set(IdleFacePhase.entering, run);
    await _wait(_blend);
    if (!_keepGoing(run)) return;

    _set(IdleFacePhase.holding, run);
    await _wait(const Duration(milliseconds: 900));
    if (!_keepGoing(run)) return;

    _beat = FaceState.dozing;
    _blend = const Duration(milliseconds: 800);
    _set(IdleFacePhase.entering, run);
    await _wait(_blend);
    if (!_keepGoing(run)) return;

    // Nothing but a tap moves it from here, so the loop ends and `wake`
    // picks it back up. Parking on a long timer instead would leave one
    // ticking for no reason.
    _set(IdleFacePhase.dozing, run);
  }

  /// Picks a beat, leaning on the tired ones late at night.
  IdleBeat _pick() {
    final night = isNight;
    var total = 0;
    for (final beat in beats) {
      total += _weightOf(beat, night);
    }
    var roll = _random.nextInt(total);
    for (final beat in beats) {
      roll -= _weightOf(beat, night);
      if (roll < 0) return beat;
    }
    return blink;
  }

  int _weightOf(IdleBeat beat, bool night) =>
      beat.weight + (night && tiredFaces.contains(beat.face) ? nightLift : 0);

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
