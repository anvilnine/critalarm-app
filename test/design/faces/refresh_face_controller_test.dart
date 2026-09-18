import 'dart:async';

import 'package:critalarm/design/faces/refresh_face_controller.dart';
import 'package:flutter_test/flutter_test.dart';

/// A clock the test moves by hand. Every wait the controller asks for is
/// written down and jumps the clock forward at once.
class _Clock {
  DateTime now = DateTime(2026, 9, 19, 9);
  final waits = <Duration>[];

  Future<void> delay(Duration d) async {
    waits.add(d);
    now = now.add(d);
  }
}

void main() {
  late _Clock clock;
  late List<RefreshFacePhase> seen;

  RefreshFaceController make(Future<bool> Function() onRefresh) {
    final c = RefreshFaceController(
      onRefresh: onRefresh,
      now: () => clock.now,
      delay: clock.delay,
    );
    c.addListener(() {
      if (seen.isEmpty || seen.last != c.phase) seen.add(c.phase);
    });
    addTearDown(c.dispose);
    return c;
  }

  setUp(() {
    clock = _Clock();
    seen = [];
  });

  group('pulling', () {
    test('progress is the pull over 80, capped at 1', () {
      final c = make(() async => true)..pull(40);
      expect(c.phase, RefreshFacePhase.pulling);
      expect(c.progress, 0.5);
      c.pull(200);
      expect(c.progress, 1);
    });

    test('back at 0 is idle again', () {
      final c = make(() async => true)
        ..pull(40)
        ..pull(0);
      expect(c.phase, RefreshFacePhase.idle);
      expect(c.progress, 0);
    });

    test('letting go under 80 does not refresh and stays pulling', () async {
      var calls = 0;
      final c = make(() async {
        calls++;
        return true;
      })..pull(50);
      await c.release();
      expect(calls, 0);
      expect(c.phase, RefreshFacePhase.pulling);
      // The list springs back and takes the face with it.
      c.pull(0);
      expect(c.phase, RefreshFacePhase.idle);
    });
  });

  group('a refresh that works', () {
    test('goes working, success, settling, idle', () async {
      final c = make(() async => true)..pull(80);
      await c.release();
      expect(seen, [
        RefreshFacePhase.pulling,
        RefreshFacePhase.working,
        RefreshFacePhase.success,
        RefreshFacePhase.settling,
        RefreshFacePhase.idle,
      ]);
      expect(c.progress, 0);
    });

    test('a fast refresh still shows working for 600ms', () async {
      final c = make(() async => true)..pull(80);
      await c.release();
      expect(clock.waits, const [
        Duration(milliseconds: 600),
        Duration(milliseconds: 700),
        Duration(milliseconds: 300),
      ]);
    });

    test('a slow refresh adds no extra wait', () async {
      final c = make(() async {
        clock.now = clock.now.add(const Duration(milliseconds: 900));
        return true;
      })..pull(90);
      await c.release();
      expect(clock.waits, const [
        Duration(milliseconds: 700),
        Duration(milliseconds: 300),
      ]);
    });
  });

  group('a refresh that fails', () {
    test('returning false goes failed, holds 1s, then settles', () async {
      final c = make(() async => false)..pull(80);
      await c.release();
      expect(seen, [
        RefreshFacePhase.pulling,
        RefreshFacePhase.working,
        RefreshFacePhase.failed,
        RefreshFacePhase.settling,
        RefreshFacePhase.idle,
      ]);
      expect(clock.waits, const [
        Duration(milliseconds: 600),
        Duration(milliseconds: 1000),
        Duration(milliseconds: 300),
      ]);
    });

    test('throwing counts as failed', () async {
      final c = make(() async => throw StateError('offline'))..pull(80);
      await c.release();
      expect(seen, contains(RefreshFacePhase.failed));
      expect(c.phase, RefreshFacePhase.idle);
    });
  });

  test('a pull while working is ignored', () async {
    final done = Completer<bool>();
    final c = make(() => done.future)..pull(80);
    final run = c.release();
    expect(c.phase, RefreshFacePhase.working);
    c.pull(30);
    expect(c.phase, RefreshFacePhase.working);
    await c.release();
    expect(c.phase, RefreshFacePhase.working);
    done.complete(true);
    await run;
    expect(c.phase, RefreshFacePhase.idle);
  });

  test('closing the screen mid refresh stops the sequence quietly', () async {
    final done = Completer<bool>();
    final c = RefreshFaceController(
      onRefresh: () => done.future,
      now: () => clock.now,
      delay: clock.delay,
    )..pull(80);
    final run = c.release();
    c.dispose();
    done.complete(true);
    // Would throw "used after being disposed" if it kept notifying.
    await run;
    expect(clock.waits, isEmpty);
  });
}
