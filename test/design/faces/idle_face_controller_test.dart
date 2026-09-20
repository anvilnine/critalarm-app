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

  final int stopAfter;
  final waits = <Duration>[];
  IdleFaceController? controller;

  Future<void> delay(Duration d) async {
    waits.add(d);
    if (waits.length >= stopAfter) controller!.stop();
  }
}

void main() {
  IdleFaceController make(_Beats driver, int Function(int max) next) {
    final controller = IdleFaceController(
      random: _FakeRandom(next),
      delay: driver.delay,
    );
    driver.controller = controller;
    addTearDown(controller.dispose);
    return controller;
  }

  /// Hands out 0, 1, 0, 1 for the beat pick, so the two faces take turns, and
  /// the shortest gap every time. The beat pick is the only draw that asks for
  /// a number under the number of beats.
  int Function(int max) takingTurns() {
    var beat = 0;
    return (max) => max == IdleFaceController.beats.length ? beat++ % max : 0;
  }

  group('the beats it picks', () {
    test('only watching and skeptical, with calm in between', () async {
      final driver = _Beats(stopAfter: 13);
      final controller = make(driver, takingTurns());
      final seen = <FaceState>[];
      controller.addListener(() {
        if (seen.isEmpty || seen.last != controller.beat) {
          seen.add(controller.beat);
        }
      });

      await controller.start();

      expect(seen, [
        FaceState.watching,
        FaceState.calm,
        FaceState.skeptical,
        FaceState.calm,
        FaceState.watching,
        FaceState.calm,
      ]);
      for (final face in seen) {
        expect(
          face == FaceState.calm || IdleFaceController.beats.contains(face),
          isTrue,
          reason: '$face is not allowed in an idle beat',
        );
      }
    });

    test('the safe set holds nothing that means something real', () {
      expect(IdleFaceController.beats, [
        FaceState.watching,
        FaceState.skeptical,
      ]);
      for (final face in const [
        FaceState.worried,
        FaceState.alarmed,
        FaceState.sad,
        FaceState.shocked,
        FaceState.dizzy,
        FaceState.determined,
        FaceState.surprised,
        FaceState.acked,
        FaceState.laughing,
      ]) {
        expect(IdleFaceController.beats, isNot(contains(face)));
      }
    });

    test('every phase of a beat runs in order', () async {
      final driver = _Beats(stopAfter: 5);
      final controller = make(driver, takingTurns());
      final phases = <IdleFacePhase>[];
      controller.addListener(() => phases.add(controller.phase));

      await controller.start();

      expect(phases, [
        IdleFacePhase.entering,
        IdleFacePhase.holding,
        IdleFacePhase.leaving,
        IdleFacePhase.resting,
      ]);
    });
  });

  group('timing', () {
    test('the shortest gap is 2.4s, then 420, 1100 and 520', () async {
      final driver = _Beats(stopAfter: 4);
      await make(driver, (max) => 0).start();

      expect(driver.waits, const [
        Duration(milliseconds: 2400),
        Duration(milliseconds: 420),
        Duration(milliseconds: 1100),
        Duration(milliseconds: 520),
      ]);
    });

    test('the longest gap is 4.8s', () async {
      final driver = _Beats(stopAfter: 1);
      await make(driver, (max) => max - 1).start();

      expect(driver.waits, const [Duration(milliseconds: 4800)]);
    });

    test('it keeps looping, one gap per beat', () async {
      final driver = _Beats(stopAfter: 9);
      await make(driver, (max) => 0).start();

      expect(
        driver.waits.where((d) => d == const Duration(milliseconds: 2400)),
        hasLength(3),
      );
      expect(driver.waits, hasLength(9));
    });
  });

  group('stopping', () {
    test('mid beat it lands on calm with nothing left waiting', () async {
      final driver = _Beats(stopAfter: 2);
      final controller = make(driver, takingTurns());

      await controller.start();

      expect(controller.phase, IdleFacePhase.resting);
      expect(controller.beat, FaceState.calm);
      expect(controller.isRunning, isFalse);
      // The wait it was in the middle of was the last one it asked for.
      expect(driver.waits, hasLength(2));
    });

    test('stopping twice is safe', () async {
      final driver = _Beats(stopAfter: 2);
      final controller = make(driver, takingTurns());
      await controller.start();
      controller.stop();

      expect(controller.phase, IdleFacePhase.resting);
      expect(driver.waits, hasLength(2));
    });

    test('it can start again after a stop', () async {
      final driver = _Beats(stopAfter: 2);
      final controller = make(driver, takingTurns());
      await controller.start();
      expect(controller.isRunning, isFalse);

      await controller.start();

      // It picked up again and asked for one more wait before stopping.
      expect(driver.waits, hasLength(3));
      expect(controller.phase, IdleFacePhase.resting);
      expect(controller.beat, FaceState.calm);
    });

    test('starting twice runs one loop', () async {
      final driver = _Beats(stopAfter: 5);
      final controller = make(driver, takingTurns());

      final first = controller.start();
      await controller.start();
      await first;

      expect(driver.waits, hasLength(5));
    });

    test('throwing it away mid beat stops the loop quietly', () async {
      final waits = <Duration>[];
      late final IdleFaceController controller;
      controller = IdleFaceController(
        random: _FakeRandom((max) => 0),
        delay: (d) async {
          waits.add(d);
          if (waits.length == 2) controller.dispose();
        },
      );

      // Would throw "used after being disposed" if it kept notifying.
      await controller.start();

      expect(waits, hasLength(2));
      expect(controller.isRunning, isFalse);
    });
  });
}
