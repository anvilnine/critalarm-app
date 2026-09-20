import 'dart:math' as math;

import 'package:critalarm/design/faces/face_state.dart';
import 'package:critalarm/design/faces/idle_face_controller.dart';
import 'package:flutter_test/flutter_test.dart';

/// A random the test writes by hand.
class _FakeRandom implements math.Random {
  _FakeRandom(this._next);

  final int Function(int max) _next;

  @override
  int nextInt(int max) => _next(max);

  @override
  bool nextBool() => false;

  @override
  double nextDouble() => 0;
}

/// Every wait the loop asks for is written down and granted at once, so the
/// beats run without real time. The loop never ends on its own, so the test
/// says which wait stops it.
class _Beats {
  _Beats({required this.stopAfter});

  int stopAfter;

  final waits = <Duration>[];
  final faces = <FaceState>[];
  final phases = <IdleFacePhase>[];
  IdleFaceController? controller;

  void watch(IdleFaceController c) {
    controller = c;
    c.addListener(() {
      phases.add(c.phase);
      faces.add(c.beat);
    });
  }

  Future<void> delay(Duration d) async {
    waits.add(d);
    if (waits.length >= stopAfter) controller!.stop();
  }
}

void main() {
  /// Nine in the morning, so nothing is tired unless a test says so.
  final daytime = DateTime(2026, 9, 21, 9);
  final nighttime = DateTime(2026, 9, 21, 23);

  IdleFaceController make(
    _Beats driver,
    int Function(int max) next, {
    DateTime? clock,
  }) {
    final controller = IdleFaceController(
      random: _FakeRandom(next),
      delay: driver.delay,
      now: () => clock ?? daytime,
    );
    driver.watch(controller);
    addTearDown(controller.dispose);
    return controller;
  }

  /// The gap draw is the only one that asks for a number of milliseconds, so
  /// anything that big is the gap and everything else is the beat roll.
  bool isGapDraw(int max) => max > 1000;

  /// Always picks the first beat in the table and the shortest gap.
  int Function(int max) alwaysFirst() => (max) => 0;

  /// The beat draw is a roll across the weights, so landing on one beat means
  /// rolling into its band rather than naming its place in the list.
  int rollFor(FaceState face) {
    var start = 0;
    for (final beat in IdleFaceController.beats) {
      if (beat.face == face) return start;
      start += beat.weight;
    }
    throw ArgumentError('$face is not a beat');
  }

  group('what it can do', () {
    test('every beat is a face the app actually has', () {
      for (final beat in IdleFaceController.beats) {
        expect(FaceState.values, contains(beat.face));
        var next = beat.thenPlay;
        while (next != null) {
          expect(FaceState.values, contains(next.face));
          next = next.thenPlay;
        }
      }
    });

    test('nothing in the table means something real is wrong', () {
      const loaded = {
        FaceState.alarmed,
        FaceState.worried,
        FaceState.shocked,
        FaceState.sad,
        FaceState.acked,
        FaceState.working,
        FaceState.success,
        FaceState.dizzy,
      };
      for (final beat in IdleFaceController.beats) {
        expect(loaded, isNot(contains(beat.face)), reason: '${beat.face}');
      }
    });

    test('blinking is what it does most', () {
      final blinkWeight = IdleFaceController.beats
          .where((b) => b.face == FaceState.blink)
          .fold(0, (sum, b) => sum + b.weight);
      final rest = IdleFaceController.beats
          .where((b) => b.face != FaceState.blink)
          .fold(0, (sum, b) => sum + b.weight);
      expect(blinkWeight, greaterThan(rest ~/ 2));
    });

    test('every beat has a weight it can actually be picked with', () {
      for (final beat in IdleFaceController.beats) {
        expect(beat.weight, greaterThan(0), reason: '${beat.face}');
      }
    });
  });

  group('one beat', () {
    test('waits, puts a face on, holds it, takes it off, rests', () async {
      final driver = _Beats(stopAfter: 4);
      final controller = make(driver, alwaysFirst());
      await controller.start();

      expect(driver.phases, [
        IdleFacePhase.entering,
        IdleFacePhase.holding,
        IdleFacePhase.leaving,
        IdleFacePhase.resting,
      ]);
      expect(driver.faces.last, FaceState.calm);
    });

    test('the waits are the gap and then the beat own three', () async {
      final driver = _Beats(stopAfter: 4);
      final controller = make(driver, alwaysFirst());
      await controller.start();

      final first = IdleFaceController.beats.first;
      expect(driver.waits, [
        IdleFaceController.minGap,
        first.enter,
        first.hold,
        first.leave,
      ]);
    });

    test('a beat with a follow up plays both, with no gap between', () async {
      // The breathe in beat is the one that breathes out straight after.
      final roll = rollFor(FaceState.breatheIn);
      final driver = _Beats(stopAfter: 6);
      final controller = make(driver, (max) => isGapDraw(max) ? 0 : roll);
      await controller.start();

      expect(
        driver.faces,
        containsAllInOrder([FaceState.breatheIn, FaceState.breatheOut]),
      );
      // One gap, then in (enter, hold), then out (enter, hold, leave).
      expect(driver.waits.first, IdleFaceController.minGap);
      expect(driver.waits.skip(1).length, 5);
    });
  });

  group('timing', () {
    test('the gap runs from 2.2s to 5.2s', () async {
      Future<Duration> gapWith(int Function(int max) next) async {
        final driver = _Beats(stopAfter: 1);
        await make(driver, next).start();
        return driver.waits.single;
      }

      expect(await gapWith((max) => 0), IdleFaceController.minGap);
      expect(
        await gapWith((max) => isGapDraw(max) ? max - 1 : 0),
        IdleFaceController.maxGap,
      );
    });

    test('one gap per beat, over and over', () async {
      final driver = _Beats(stopAfter: 9);
      await make(driver, alwaysFirst()).start();

      final gaps = driver.waits.where(
        (d) => d >= IdleFaceController.minGap && d <= IdleFaceController.maxGap,
      );
      expect(gaps, hasLength(3));
    });
  });

  group('nodding off', () {
    /// Enough gaps to run the idle budget out. Every gap is the longest one.
    int Function(int max) longGaps() =>
        (max) => isGapDraw(max) ? max - 1 : 0;

    test('gets sleepy, then drops off, and the loop ends there', () async {
      final driver = _Beats(stopAfter: 500);
      final controller = make(driver, longGaps());
      await controller.start();

      expect(driver.faces, contains(FaceState.sleepy));
      expect(driver.faces, contains(FaceState.dozing));
      expect(driver.phases.last, IdleFacePhase.dozing);
      expect(controller.isDozing, isTrue);
      // It stopped asking for waits once it was asleep.
      expect(driver.waits.length, lessThan(500));
    });

    test('a tap wakes it, and it goes back to calm', () async {
      final driver = _Beats(stopAfter: 500);
      final controller = make(driver, longGaps());
      await controller.start();
      expect(controller.isDozing, isTrue);

      // Let the woken loop run a little and then end it.
      driver.stopAfter = driver.waits.length + 6;

      driver.faces.clear();
      driver.phases.clear();
      await controller.wake();

      expect(driver.faces, contains(FaceState.wakesUp));
      expect(driver.faces.last, FaceState.calm);
      expect(controller.isDozing, isFalse);
    });

    test('a tap does nothing while it is awake', () async {
      final driver = _Beats(stopAfter: 4);
      final controller = make(driver, alwaysFirst());
      await controller.start();

      final before = driver.waits.length;
      await controller.wake();
      expect(driver.waits, hasLength(before));
    });
  });

  group('late at night', () {
    test('it calls itself night outside 7am to 9pm', () {
      final driver = _Beats(stopAfter: 1);
      expect(make(driver, alwaysFirst(), clock: daytime).isNight, isFalse);
      expect(make(driver, alwaysFirst(), clock: nighttime).isNight, isTrue);
      expect(
        make(driver, alwaysFirst(), clock: DateTime(2026, 9, 21, 3)).isNight,
        isTrue,
      );
      expect(
        make(driver, alwaysFirst(), clock: DateTime(2026, 9, 21, 7)).isNight,
        isFalse,
      );
    });

    test('it gives up sooner at night than during the day', () {
      expect(
        IdleFaceController.dozeAfterAtNight,
        lessThan(IdleFaceController.dozeAfter),
      );
    });

    test('yawning is one of the beats that comes up more', () {
      expect(IdleFaceController.tiredFaces, contains(FaceState.yawn));
      expect(IdleFaceController.nightLift, greaterThan(0));
    });
  });

  group('stopping', () {
    test('it settles on calm and leaves nothing waiting', () async {
      final driver = _Beats(stopAfter: 2);
      final controller = make(driver, alwaysFirst());
      await controller.start();

      expect(controller.isRunning, isFalse);
      expect(controller.beat, FaceState.calm);
      expect(controller.phase, IdleFacePhase.resting);
    });

    test('starting twice does not run two loops', () async {
      final driver = _Beats(stopAfter: 4);
      final controller = make(driver, alwaysFirst());
      final first = controller.start();
      final second = controller.start();
      await Future.wait([first, second]);

      expect(driver.waits, hasLength(4));
    });
  });
}
