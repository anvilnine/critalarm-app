import 'dart:math' as math;
import 'dart:ui';

import 'package:critalarm/design/faces/face_state.dart';
import 'package:critalarm/features/paywall/presentation/outros/break_lift_ring/break_lift_ring_outro.dart';
import 'package:critalarm/features/paywall/presentation/outros/break_lift_ring/break_lift_ring_timeline.dart';
import 'package:flutter_test/flutter_test.dart';

typedef T = BreakLiftRingTimeline;

const _screens = [Size(390, 844), Size(375, 667)];

Rect _landFor(Size size) => Rect.fromCenter(
  center: Offset(size.width / 2, size.height * 0.28),
  width: 174,
  height: 174,
);

void main() {
  test('the beats are in order and the uncover comes before the swap', () {
    final marks = [0, T.hit, T.cut, T.sky, T.cobalt, T.uncover, T.end];
    expect(marks, orderedEquals([...marks]..sort()));
    expect(T.rings, orderedEquals([2.20, 2.46, 2.72]));
    expect(T.rings.first, greaterThanOrEqualTo(T.sky));
    expect(T.rings.last + T.ringSeconds, lessThan(T.cobalt + 0.2));
    expect(T.uncover, 3.55);
    expect(T.end, 3.75);
    expect(T.uncover, lessThan(T.end));
    expect(T.beats.map((b) => b.at), [T.hit, T.cut, 2.20, 2.46, 2.72]);
  });

  test('the outro is sound', () {
    expect(breakLiftRing.isSound, isTrue);
    expect(breakLiftRing.seconds, T.end);
    expect(breakLiftRing.uncover, T.uncover);
  });

  for (final size in _screens) {
    test('Crit is whole inside ${size.width}x${size.height} every 0.05 s', () {
      final land = _landFor(size);
      final screen = Offset.zero & size;
      for (final mascot in <Rect?>[
        null,
        Rect.fromCenter(
          center: Offset(size.width / 2, 300),
          width: 120,
          height: 120,
        ),
      ]) {
        for (var i = 0; i <= 80; i++) {
          final t = i * 0.05;
          final box = T
              .pose(t, size: size, land: land, mascot: mascot)
              .turnedBox;
          expect(
            screen.deflate(6).contains(box.topLeft) &&
                screen.deflate(6).contains(box.bottomRight),
            isTrue,
            reason: 't=$t box=$box',
          );
        }
      }
    });
  }

  test('the first frame is the layout: Crit on the mascot', () {
    const size = Size(390, 844);
    final mascot = Rect.fromCenter(
      center: const Offset(200, 260),
      width: 130,
      height: 130,
    );
    final pose = T.pose(0, size: size, land: _landFor(size), mascot: mascot);
    expect(pose.centre.dx, closeTo(200, 0.001));
    expect(pose.centre.dy, closeTo(260, 0.001));
    expect(pose.size, closeTo(130 * 1.05, 0.001));
    expect(T.scene(0), BreakLiftRingScene.wall);
    expect(T.crack(0), 0);
    expect(T.hitFlash(0), 0);
  });

  test('with no mascot Crit starts on the stage', () {
    const size = Size(390, 844);
    final pose = T.pose(0, size: size, land: _landFor(size));
    expect(pose.centre.dx, closeTo(195, 0.001));
    expect(pose.box.width, greaterThan(100));
  });

  for (final size in _screens) {
    test('at the swap Crit is on land, upright and unsquashed', () {
      for (final land in [
        _landFor(size),
        Rect.fromCenter(
          center: const Offset(183, 298),
          width: 209,
          height: 159,
        ),
      ]) {
        final pose = T.pose(T.end, size: size, land: land);
        expect(pose.box.left, closeTo(land.left, 0.001));
        expect(pose.box.top, closeTo(land.top, 0.001));
        expect(pose.box.width, closeTo(land.width, 0.001));
        expect(pose.box.height, closeTo(land.height, 0.001));
        expect(pose.angle, 0);
        expect(pose.squashX, 1);
        // Just before the swap he is close and has not jumped.
        final before = T.pose(T.end - 0.01, size: size, land: land);
        expect((before.centre - pose.centre).distance, lessThan(8));
      }
    });
  }

  test('his size does not jump at the cut to the rings', () {
    const size = Size(390, 844);
    final land = _landFor(size);
    double w(double t) => T.pose(t, size: size, land: land).box.width;
    expect((w(T.sky - 0.001) - w(T.sky)).abs(), lessThan(1));
    expect((w(T.cut - 0.001) - w(T.cut + 0.001)).abs(), greaterThan(0));
  });

  test(
    'he is upright after the flight and rocks only a little over the rings',
    () {
      const size = Size(390, 844);
      final land = _landFor(size);
      expect(T.pose(T.sky, size: size, land: land).angle.abs(), lessThan(0.01));
      for (var i = 0; i < 100; i++) {
        final t = T.sky + i * 0.0145;
        final a = T.pose(t, size: size, land: land).angle.abs();
        expect(a, lessThanOrEqualTo(3 * math.pi / 180 + 1e-9));
      }
    },
  );

  test('the faces', () {
    expect(T.face(0), FaceState.determined);
    expect(T.face(0.5), FaceState.happy);
    expect(T.face(1), FaceState.determined);
    expect(T.face(3), FaceState.happy);
    expect(T.face(3.6), FaceState.surprised);
  });

  test('there are 56 pieces and they tile the screen at the hit', () {
    for (final size in _screens) {
      final pieces = T.pieces(size);
      expect(pieces, hasLength(56));
      expect(T.pieces(size).first.a, pieces.first.a);
      bool inside(Offset p, BreakPiece t) {
        double side(Offset a, Offset b, Offset c) =>
            (a.dx - c.dx) * (b.dy - c.dy) - (b.dx - c.dx) * (a.dy - c.dy);
        const e = 1e-6;
        final d1 = side(p, t.a, t.b);
        final d2 = side(p, t.b, t.c);
        final d3 = side(p, t.c, t.a);
        final neg = d1 < -e || d2 < -e || d3 < -e;
        final pos = d1 > e || d2 > e || d3 > e;
        return !(neg && pos);
      }

      var gaps = 0;
      var area = 0.0;
      for (final p in pieces) {
        area +=
            ((p.b.dx - p.a.dx) * (p.c.dy - p.a.dy) -
                    (p.c.dx - p.a.dx) * (p.b.dy - p.a.dy))
                .abs() /
            2;
      }
      for (var y = 0.0; y <= size.height; y += 1) {
        for (var x = 0.0; x <= size.width; x += 1) {
          if (!pieces.any((p) => inside(Offset(x, y), p))) gaps++;
        }
      }
      expect(gaps, 0, reason: '$size');
      expect(area, closeTo(size.width * size.height, 1));
    }
  });

  test('the pieces are the same on every run', () {
    const size = Size(390, 844);
    final a = T.pieces(size);
    final b = T.pieces(size);
    for (var i = 0; i < a.length; i++) {
      expect(a[i].centre, b[i].centre);
      expect(a[i].velocity, b[i].velocity);
    }
  });

  test('words: three give three, five give three, one gives one', () {
    expect(T.words('Welcome to Pro'), ['WELCOME', 'TO', 'PRO']);
    expect(T.words('one two three four five'), [
      'ONE',
      'TWO',
      'THREE FOUR FIVE',
    ]);
    expect(T.words('Hosted'), ['HOSTED']);
    expect(T.words('  '), isEmpty);
  });

  test('the word shows from its ring', () {
    expect(T.wordIndex(2.19), -1);
    expect(T.wordIndex(2.20), 0);
    expect(T.wordIndex(2.5), 1);
    expect(T.wordIndex(3), 2);
  });

  test('every piece flies off slowly and stays on a finite path', () {
    const size = Size(390, 844);
    final p = T.pieces(size).first;
    final f = T.flightOf(p, T.cut, k: 1);
    expect(f.scale, greaterThanOrEqualTo(1));
    expect(T.slow(T.hit), 0);
    expect(T.slow(T.hit + 0.1), closeTo(0.1, 1e-9));
    expect(T.slow(T.hit + 0.2), closeTo(0.13, 1e-9));
  });
}
