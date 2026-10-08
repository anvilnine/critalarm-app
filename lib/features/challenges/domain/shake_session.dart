import 'dart:async';

import 'package:critalarm/core/motion/motion_sensor.dart';
import 'package:critalarm/features/challenges/domain/shake_count.dart';

/// How the count is made: by shaking, or by tapping a button.
enum ShakeInput { shake, taps }

/// Whether the challenge opens on taps. Shaking a phone is not possible for
/// everyone, so a screen reader or switch control ([hasAssistiveNavigation])
/// and the system reduce motion setting ([reducesMotion]) both get taps
/// from the first frame, and the sensor never starts.
bool shakeOpensOnTaps({
  required bool hasAssistiveNavigation,
  required bool reducesMotion,
}) => hasAssistiveNavigation || reducesMotion;

/// Starts a timer. A test hands in its own so no test waits five seconds.
typedef ShakeTimerStarter =
    Timer Function(Duration after, void Function() then);

/// One run of the shake challenge: the count, where it comes from, and the
/// sensor's whole life.
///
/// The sensor is on only between [open] and the first of: the count
/// reaching [target], [close], the app leaving the front, the challenge
/// being covered by a sheet or another page, or the switch to taps. It
/// comes back on only when the app is in front and the challenge is on top
/// again, with the run still open, unpassed and still on shaking.
/// [isSensorOn] is the one place that says whether a subscription is open.
///
/// Nothing counts while the challenge is covered: no shake, because the
/// sensor is off, and no tap. So the count cannot reach [target] under a
/// sheet the person is looking at instead.
///
/// Taps take over, for good, when the sensor cannot start, its stream
/// fails or ends, or it gives nothing for [ShakeRule.silentAfter] after it
/// said it was running. A start the phone refused because the app was not
/// in front is none of these: the run waits and asks again. The
/// count so far is kept.
final class ShakeSession {
  ShakeSession({
    required this._sensor,
    required this._onChanged,
    required this._onPassed,
    this.target = ShakeRule.target,
    ShakeTimerStarter? startTimer,
  }) : _startTimer = startTimer ?? Timer.new;

  final MotionSensor _sensor;
  final void Function() _onChanged;
  final void Function() _onPassed;
  final ShakeTimerStarter _startTimer;

  /// How many shakes or taps pass.
  final int target;

  final ShakeCounter _counter = ShakeCounter();
  // Cancelled in [_stopSensor], the one way the sensor goes off.
  // ignore: cancel_subscriptions
  StreamSubscription<MotionReading>? _readings;
  Timer? _silence;
  int _heard = 0;
  int _listens = 0;
  bool _didStart = false;
  int _count = 0;
  ShakeInput _input = ShakeInput.shake;
  bool _isOpen = false;
  bool _isClosed = false;
  bool _isPassed = false;
  bool _isInFront = true;
  bool _isOnTop = true;

  /// Shakes and taps so far, never above [target].
  int get count => _count;

  ShakeInput get input => _input;

  bool get isPassed => _isPassed;

  /// Whether the accelerometer is being listened to right now.
  bool get isSensorOn => _readings != null;

  /// Starts the run. With [onTaps] the sensor is never asked for.
  /// [isInFront] is false when the app is not the one on screen, and the
  /// sensor then waits for [appMoved]. [isOnTop] is false when something
  /// already covers the challenge, and it then waits for [routeMoved].
  void open({
    required bool onTaps,
    bool isInFront = true,
    bool isOnTop = true,
  }) {
    if (_isOpen || _isClosed) return;
    _isOpen = true;
    _isInFront = isInFront;
    _isOnTop = isOnTop;
    if (onTaps) {
      _input = ShakeInput.taps;
      return;
    }
    _listen();
  }

  /// Moves the run to taps and turns the sensor off. Called when a screen
  /// reader or reduce motion comes on mid-run, and by the run itself when
  /// the sensor lets it down.
  void useTaps() {
    if (_isClosed || _isPassed || _input == ShakeInput.taps) return;
    _input = ShakeInput.taps;
    _stopSensor();
    _onChanged();
  }

  /// One tap of the button. Counts only while the run is on taps.
  void tap() {
    if (!_isOpen || _isClosed || _isPassed) return;
    if (_input != ShakeInput.taps) return;
    // A tap that reaches a covered challenge was not meant for it.
    if (!_isOnTop) return;
    _add();
  }

  /// The app came to the front or left it. Anything but the front turns
  /// the sensor off, and coming back turns it on again if the run still
  /// wants it.
  void appMoved({required bool isInFront}) {
    if (_isClosed) return;
    _isInFront = isInFront;
    if (isInFront) {
      _listen();
    } else {
      _stopSensor();
    }
  }

  /// A sheet or another page came over the challenge, or went away again.
  /// Covered is the same as the app leaving the front: the sensor goes off
  /// and nothing counts. Uncovered, it comes back on if the run still
  /// wants it.
  void routeMoved({required bool isOnTop}) {
    if (_isClosed) return;
    _isOnTop = isOnTop;
    if (isOnTop) {
      _listen();
    } else {
      _stopSensor();
    }
  }

  /// The end of the run: the challenge was left, skipped, or its widget
  /// went away. The sensor is off after this and nothing turns it back on.
  void close() {
    if (_isClosed) return;
    _isClosed = true;
    _stopSensor();
  }

  void _listen() {
    if (_readings != null) return;
    if (!_isOpen || _isClosed || _isPassed) return;
    if (!_isInFront || !_isOnTop) return;
    if (_input != ShakeInput.shake) return;
    _heard = 0;
    _didStart = false;
    final listen = ++_listens;
    try {
      _readings = _sensor
          .readings(onStarted: () => _started(listen))
          .listen(_onReading, onError: _onError, onDone: useTaps);
      // Anything can come out of a sensor that will not start. Whatever it
      // is, the person gets taps.
      // ignore: avoid_catches_without_on_clauses
    } catch (_) {
      useTaps();
      return;
    }
    // A stream that failed inside the listen call moved the run to taps
    // before there was a subscription to cancel. Cancel it now.
    if (_input != ShakeInput.shake) {
      _stopSensor();
      return;
    }
    _watch();
  }

  /// The sensor said it is running. The five seconds it has to say
  /// something are counted from here, not from when it was asked.
  void _started(int listen) {
    if (listen != _listens) return;
    _didStart = true;
    _watch();
  }

  /// Starts the watch for a silent sensor, once there is a subscription
  /// and the sensor has said it is running, whichever comes second.
  void _watch() {
    if (_readings == null || !_didStart || _silence != null) return;
    _silence = _startTimer(ShakeRule.silentAfter, _checkSilence);
  }

  void _onError(Object error) {
    if (error is MotionSensorNotInFront) {
      // The phone says the app is not in front, so it started nothing.
      // That is no fault of the sensor: let go, and ask again the next
      // time the app or the challenge comes back.
      _stopSensor();
      return;
    }
    useTaps();
  }

  /// Runs every [ShakeRule.silentAfter] while the sensor is on. A sensor
  /// that never says anything is caught at the first check, five seconds
  /// in. One that goes quiet later is caught at the first check that saw
  /// nothing since the one before, so within ten seconds.
  void _checkSilence() {
    _silence = null;
    if (_readings == null) return;
    if (_heard == 0) {
      useTaps();
      return;
    }
    _heard = 0;
    _silence = _startTimer(ShakeRule.silentAfter, _checkSilence);
  }

  void _onReading(MotionReading reading) {
    if (_readings == null || !_isOnTop) return;
    _heard++;
    if (_counter.add(reading)) _add();
  }

  void _add() {
    _count++;
    if (_count < target) {
      _onChanged();
      return;
    }
    _count = target;
    _isPassed = true;
    _stopSensor();
    _onChanged();
    _onPassed();
  }

  void _stopSensor() {
    _didStart = false;
    _silence?.cancel();
    _silence = null;
    final readings = _readings;
    _readings = null;
    if (readings != null) unawaited(readings.cancel());
  }
}
