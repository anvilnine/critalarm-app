import 'dart:async';
import 'dart:math';

import 'package:critalarm/core/motion/motion_sensor.dart';
import 'package:critalarm/features/challenges/domain/shake_count.dart';
import 'package:critalarm/features/challenges/domain/shake_session.dart';
import 'package:flutter_test/flutter_test.dart';

/// A sensor a test drives by hand. It counts every listen and every
/// cancel, so a test can say whether it is on.
final class _FakeSensor implements MotionSensor {
  _FakeSensor({this.throwsOnAsk = false});

  final bool throwsOnAsk;
  int listens = 0;
  int cancels = 0;
  StreamController<MotionReading>? _open;

  /// How many subscriptions are open right now. On is 1, off is 0, and
  /// anything else is a leak.
  int get listening => listens - cancels;

  @override
  Stream<MotionReading> readings() {
    if (throwsOnAsk) throw StateError('no sensor');
    late final StreamController<MotionReading> controller;
    controller = StreamController<MotionReading>(
      sync: true,
      onListen: () {
        listens++;
        _open = controller;
      },
      onCancel: () {
        cancels++;
        if (identical(_open, controller)) _open = null;
      },
    );
    return controller.stream;
  }

  int _tick = 0;

  /// One reading of a phone at rest.
  void still() => _add(0);

  /// Hard shaking: [count] swings out and back, 300 ms each.
  void shake(int count) {
    for (var i = 0; i < count; i++) {
      for (var step = 0; step < 15; step++) {
        _add(3 * sin(2 * pi * step / 15));
      }
    }
  }

  void _add(double x) {
    _tick++;
    _open?.add(
      MotionReading(
        x: x,
        y: 0,
        z: -1,
        at: Duration(milliseconds: 20 * _tick),
      ),
    );
  }

  void fail() => _open?.addError(const MotionSensorUnavailable('gone'));

  Future<void> end() async => _open?.close();
}

/// A sensor whose stream fails the moment it is listened to, the way the
/// real one does on a phone with no accelerometer.
final class _NoSensor implements MotionSensor {
  int listens = 0;
  int cancels = 0;

  @override
  Stream<MotionReading> readings() {
    late final StreamController<MotionReading> controller;
    controller = StreamController<MotionReading>(
      onListen: () {
        listens++;
        controller.addError(const MotionSensorUnavailable('no_accelerometer'));
      },
      onCancel: () => cancels++,
    );
    return controller.stream;
  }
}

/// A timer that fires only when the test says so.
final class _FakeTimer implements Timer {
  _FakeTimer(this.after, this._then);

  final Duration after;
  final void Function() _then;
  bool _isActive = true;

  void fire() {
    if (!_isActive) return;
    _isActive = false;
    _then();
  }

  @override
  void cancel() => _isActive = false;

  @override
  bool get isActive => _isActive;

  @override
  int get tick => 0;
}

/// A run with its sensor, its timers and what it reported.
final class _Run {
  _Run({MotionSensor? sensor, int target = ShakeRule.target})
    : sensor = sensor ?? _FakeSensor() {
    session = ShakeSession(
      sensor: this.sensor,
      onChanged: () => changes++,
      onPassed: () => passes++,
      target: target,
      startTimer: (after, then) {
        final timer = _FakeTimer(after, then);
        timers.add(timer);
        return timer;
      },
    );
  }

  final MotionSensor sensor;
  late final ShakeSession session;
  final timers = <_FakeTimer>[];
  int changes = 0;
  int passes = 0;

  _FakeSensor get fake => sensor as _FakeSensor;

  /// The watch for a silent sensor, when one is running.
  _FakeTimer? get watch => timers.where((timer) => timer.isActive).firstOrNull;

  int get activeTimers => timers.where((timer) => timer.isActive).length;
}

void main() {
  group('opening', () {
    test('turns the sensor on and counts shakes', () {
      final run = _Run()..session.open(onTaps: false);
      expect(run.session.isSensorOn, isTrue);
      expect(run.fake.listening, 1);
      expect(run.session.input, ShakeInput.shake);
      run.fake.shake(5);
      expect(run.session.count, 5);
      expect(run.changes, 5);
      expect(run.passes, 0);
    });

    test('before it is opened nothing is on and nothing counts', () {
      final run = _Run();
      expect(run.session.isSensorOn, isFalse);
      expect(run.fake.listens, 0);
      run.session.tap();
      expect(run.session.count, 0);
    });

    test('opening twice listens once', () {
      final run = _Run()
        ..session.open(onTaps: false)
        ..session.open(onTaps: false);
      expect(run.fake.listens, 1);
      expect(run.activeTimers, 1);
    });

    test('a tap does nothing while the run is on shaking', () {
      final run = _Run()
        ..session.open(onTaps: false)
        ..session.tap()
        ..session.tap();
      expect(run.session.count, 0);
    });

    test('opened with the app not in front, the sensor waits', () {
      final run = _Run()..session.open(onTaps: false, isInFront: false);
      expect(run.fake.listens, 0);
      expect(run.activeTimers, 0);
      run.session.appMoved(isInFront: true);
      expect(run.fake.listening, 1);
    });
  });

  group('the sensor is off', () {
    test('once the count reaches the target', () {
      final run = _Run()..session.open(onTaps: false);
      run.fake.shake(29);
      expect(run.session.isSensorOn, isTrue);
      expect(run.passes, 0);
      run.fake.shake(1);
      expect(run.session.count, 30);
      expect(run.session.isPassed, isTrue);
      expect(run.passes, 1);
      expect(run.session.isSensorOn, isFalse);
      expect(run.fake.listening, 0);
      expect(run.activeTimers, 0);
    });

    test('and stays off after a pass, whatever happens next', () {
      final run = _Run()..session.open(onTaps: false);
      run.fake.shake(30);
      run.session
        ..appMoved(isInFront: false)
        ..appMoved(isInFront: true)
        ..useTaps()
        ..tap();
      run.fake.shake(10);
      expect(run.fake.listens, 1);
      expect(run.fake.listening, 0);
      expect(run.session.count, 30);
      expect(run.passes, 1);
    });

    test('when the challenge is left or skipped', () {
      // The cross, the system back and the way out all take the step off
      // the screen, which closes the run.
      final run = _Run()..session.open(onTaps: false);
      run.fake.shake(7);
      run.session.close();
      expect(run.session.isSensorOn, isFalse);
      expect(run.fake.listening, 0);
      expect(run.activeTimers, 0);
      expect(run.passes, 0);
    });

    test('when its widget goes away, more than once', () {
      final run = _Run()
        ..session.open(onTaps: false)
        ..session.close()
        ..session.close();
      expect(run.fake.listens, 1);
      expect(run.fake.cancels, 1);
    });

    test('and nothing turns it back on after a close', () {
      final run = _Run()
        ..session.open(onTaps: false)
        ..session.close()
        ..session.appMoved(isInFront: false)
        ..session.appMoved(isInFront: true)
        ..session.open(onTaps: false);
      expect(run.fake.listens, 1);
      expect(run.fake.listening, 0);
      final changes = run.changes;
      run.session
        ..useTaps()
        ..tap();
      expect(run.session.count, 0);
      expect(run.changes, changes);
    });

    test('when the app leaves the front', () {
      final run = _Run()..session.open(onTaps: false);
      run.fake.shake(4);
      run.session.appMoved(isInFront: false);
      expect(run.session.isSensorOn, isFalse);
      expect(run.fake.listening, 0);
      expect(run.activeTimers, 0);
      // Shaking a phone that shows another app counts nothing.
      run.fake.shake(4);
      expect(run.session.count, 4);
    });

    test('and comes back on, once, when the app returns', () {
      final run = _Run()..session.open(onTaps: false);
      run.fake.shake(4);
      run.session
        ..appMoved(isInFront: false)
        ..appMoved(isInFront: false)
        ..appMoved(isInFront: true)
        ..appMoved(isInFront: true);
      expect(run.fake.listens, 2);
      expect(run.fake.listening, 1);
      expect(run.activeTimers, 1);
      run.fake.shake(3);
      // The count was kept.
      expect(run.session.count, greaterThanOrEqualTo(6));
      expect(run.session.count, lessThanOrEqualTo(7));
    });

    test('through any number of trips to the back and the front', () {
      final run = _Run()..session.open(onTaps: false);
      for (var i = 0; i < 20; i++) {
        run.session.appMoved(isInFront: false);
        expect(run.fake.listening, 0);
        run.session.appMoved(isInFront: true);
        expect(run.fake.listening, 1);
      }
      run.session.close();
      expect(run.fake.listening, 0);
      expect(run.activeTimers, 0);
    });

    test('from the start on a run that opens on taps', () {
      final run = _Run()..session.open(onTaps: true);
      expect(run.fake.listens, 0);
      expect(run.timers, isEmpty);
      run.session
        ..appMoved(isInFront: false)
        ..appMoved(isInFront: true);
      expect(run.fake.listens, 0);
    });

    test('once the run moves to taps', () {
      final run = _Run()
        ..session.open(onTaps: false)
        ..session.useTaps();
      expect(run.fake.listening, 0);
      expect(run.activeTimers, 0);
      run.session
        ..appMoved(isInFront: false)
        ..appMoved(isInFront: true);
      expect(run.fake.listens, 1);
    });
  });

  group('taps take over', () {
    test('from the first frame with a screen reader or reduce motion', () {
      expect(
        shakeOpensOnTaps(hasAssistiveNavigation: true, reducesMotion: false),
        isTrue,
      );
      expect(
        shakeOpensOnTaps(hasAssistiveNavigation: false, reducesMotion: true),
        isTrue,
      );
      expect(
        shakeOpensOnTaps(hasAssistiveNavigation: true, reducesMotion: true),
        isTrue,
      );
      expect(
        shakeOpensOnTaps(hasAssistiveNavigation: false, reducesMotion: false),
        isFalse,
      );
    });

    test('when a screen reader comes on with the challenge open', () {
      final run = _Run()..session.open(onTaps: false);
      run.fake.shake(3);
      run.session.useTaps();
      expect(run.session.input, ShakeInput.taps);
      expect(run.session.count, 3);
      run.session.tap();
      expect(run.session.count, 4);
    });

    test('when the phone has no sensor', () async {
      final sensor = _NoSensor();
      final run = _Run(sensor: sensor)..session.open(onTaps: false);
      await pumpEventQueue();
      expect(run.session.input, ShakeInput.taps);
      expect(run.session.isSensorOn, isFalse);
      expect(sensor.listens, 1);
      expect(sensor.cancels, 1);
      expect(run.activeTimers, 0);
      expect(run.changes, 1);
    });

    test('when asking for the sensor throws', () {
      final run = _Run(sensor: _FakeSensor(throwsOnAsk: true))
        ..session.open(onTaps: false);
      expect(run.session.input, ShakeInput.taps);
      expect(run.session.isSensorOn, isFalse);
      expect(run.activeTimers, 0);
      run.session.tap();
      expect(run.session.count, 1);
    });

    test('when the stream fails part of the way through', () async {
      final run = _Run()..session.open(onTaps: false);
      run.fake.shake(12);
      run.fake.fail();
      await pumpEventQueue();
      expect(run.session.input, ShakeInput.taps);
      expect(run.fake.listening, 0);
      expect(run.session.count, 12);
    });

    test('when the stream ends by itself', () async {
      final run = _Run()..session.open(onTaps: false);
      await run.fake.end();
      await pumpEventQueue();
      expect(run.session.input, ShakeInput.taps);
      expect(run.session.isSensorOn, isFalse);
      expect(run.activeTimers, 0);
    });

    test('when the sensor says nothing for five seconds', () {
      final run = _Run()..session.open(onTaps: false);
      expect(run.watch!.after, const Duration(seconds: 5));
      expect(run.session.input, ShakeInput.shake);
      run.watch!.fire();
      expect(run.session.input, ShakeInput.taps);
      expect(run.session.isSensorOn, isFalse);
      expect(run.fake.listening, 0);
      expect(run.activeTimers, 0);
      expect(run.changes, 1);
    });

    test('and not when the sensor is talking, even with no shake', () {
      final run = _Run()..session.open(onTaps: false);
      run.fake.still();
      run.watch!.fire();
      expect(run.session.input, ShakeInput.shake);
      expect(run.session.isSensorOn, isTrue);
      // The watch starts again, and catches a sensor that went quiet.
      expect(run.activeTimers, 1);
      run.watch!.fire();
      expect(run.session.input, ShakeInput.taps);
      expect(run.fake.listening, 0);
    });

    test('the five seconds start over when the app comes back', () {
      final run = _Run()..session.open(onTaps: false);
      final first = run.watch!;
      run.session.appMoved(isInFront: false);
      expect(first.isActive, isFalse);
      // A watch that fires late, after it was cancelled, changes nothing.
      first.fire();
      expect(run.session.input, ShakeInput.shake);
      run.session.appMoved(isInFront: true);
      expect(run.watch, isNot(same(first)));
      expect(run.watch!.after, const Duration(seconds: 5));
    });

    test('thirty taps pass, once', () {
      final run = _Run()..session.open(onTaps: true);
      for (var i = 0; i < 29; i++) {
        run.session.tap();
      }
      expect(run.session.count, 29);
      expect(run.passes, 0);
      run.session
        ..tap()
        ..tap()
        ..tap();
      expect(run.session.count, 30);
      expect(run.session.isPassed, isTrue);
      expect(run.passes, 1);
      expect(run.changes, 30);
    });

    test('shakes and taps add up to one count', () {
      final run = _Run()..session.open(onTaps: false);
      run.fake.shake(20);
      run.watch!.fire();
      expect(run.session.input, ShakeInput.shake);
      // The sensor dies here.
      run.watch!.fire();
      expect(run.session.input, ShakeInput.taps);
      for (var i = 0; i < 10; i++) {
        run.session.tap();
      }
      expect(run.session.count, 30);
      expect(run.passes, 1);
    });

    test('a run with a smaller target passes at it', () {
      final run = _Run(target: 3)..session.open(onTaps: false);
      run.fake.shake(5);
      expect(run.session.count, 3);
      expect(run.passes, 1);
      expect(run.fake.listening, 0);
    });
  });
}
