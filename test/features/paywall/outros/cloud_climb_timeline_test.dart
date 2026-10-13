import 'dart:math' as math;

import 'package:critalarm/features/paywall/presentation/layouts/kit/hero/hero_turns.dart';
import 'package:critalarm/features/paywall/presentation/outros/cloud_climb/cloud_climb_outro.dart';
import 'package:critalarm/features/paywall/presentation/outros/cloud_climb/cloud_climb_timeline.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

typedef T = CloudClimbTimeline;

const _phones = [Size(390, 844), Size(375, 667)];
const double _frame = 1 / 120;

Rect _landFor(Size size) => Rect.fromCenter(
  center: Offset(size.width / 2, 230),
  width: 174,
  height: 174,
);

Rect _mascotFor(Size size) => Rect.fromCenter(
  center: Offset(size.width / 2, 300),
  width: 120,
  height: 120,
);

Rect _crit(double t, Size size, {Rect? mascot}) =>
    T.critBox(t, size: size, mascot: mascot, land: _landFor(size));

List<double> _times(double step) => [
  for (var i = 0; i * step <= T.end + 1e-9; i++) i * step,
];

/// Each series is one number that moves with the clock.
Map<String, double Function(double t, Size size)> _series() => {
  'crit x': (t, s) => _crit(t, s, mascot: _mascotFor(s)).center.dx,
  'crit y': (t, s) => _crit(t, s, mascot: _mascotFor(s)).center.dy,
  'crit width': (t, s) => _crit(t, s, mascot: _mascotFor(s)).width,
  'moon x': (t, s) => T.moonCentre(t, s).dx,
  'moon y': (t, s) => T.moonCentre(t, s).dy,
  'moon radius': T.moonRadius,
  'ground': (t, s) => T.rise(t),
  'night edge': (t, s) => T.nightEdge(t),
  for (var i = 0; i < T.stars.length; i++)
    'star $i y': (t, s) => T.starAt(i, t, s).dy,
  for (var i = 0; i < T.far.length; i++) ...{
    'far $i x': (t, s) => T.farAt(i, t, s).dx,
    'far $i y': (t, s) => T.farAt(i, t, s).dy,
  },
  for (var i = 0; i < T.mid.length; i++) ...{
    'mid $i x': (t, s) => T.midAt(i, t, s).dx,
    'mid $i y': (t, s) => T.midAt(i, t, s).dy,
  },
  for (var i = 0; i < T.near.length; i++) ...{
    'near $i x': (t, s) => T.nearAt(i, t, s).dx,
    'near $i y': (t, s) => T.nearAt(i, t, s).dy,
  },
};

void main() {
  group('the climb', () {
    test('rise never goes down and speed is zero at both ends', () {
      var last = -1.0;
      for (final t in _times(_frame)) {
        final rise = T.rise(t);
        expect(rise, greaterThanOrEqualTo(last));
        last = rise;
      }
      expect(T.rise(0), 0);
      expect(T.rise(T.end), 1500);
      expect(T.speed(0.4), 0);
      expect(T.speed(3.5), closeTo(0, 1e-9));
      expect(T.speed(1.95), closeTo(1, 1e-9));
    });

    test('sine eases both ends', () {
      expect(T.sine(0), 0);
      expect(T.sine(1), closeTo(1, 1e-12));
      expect(T.sine(0.5), closeTo(0.5, 1e-12));
    });
  });

  group('smoothness', () {
    for (final size in _phones) {
      test(
        'nothing steps on ${size.width.toInt()} x ${size.height.toInt()}',
        () {
          _series().forEach((name, value) {
            var previous = value(0, size);
            var lastStep = 0.0;
            for (var i = 1; i * _frame <= T.end + 1e-9; i++) {
              final now = value(i * _frame, size);
              final step = now - previous;
              expect(
                step.abs(),
                lessThan(14),
                reason: '$name moves $step at ${i * _frame}',
              );
              // A step that is eased changes a little from one frame to the
              // next. A jump or a start from rest does not.
              expect(
                (step - lastStep).abs(),
                lessThan(0.6),
                reason:
                    '$name changes pace by ${step - lastStep} at ${i * _frame}',
              );
              lastStep = step;
              previous = now;
            }
          });
        },
      );
    }

    test('the server dots glow without a step', () {
      for (var i = 0; i * _frame < T.end; i++) {
        final a = T.glow(i * _frame);
        final b = T.glow((i + 1) * _frame);
        expect((a.a - b.a).abs(), lessThan(0.05));
        expect((a.b - b.b).abs(), lessThan(0.05));
      }
    });

    test(
      'his cloud leaves by opacity, continuously, and is gone at the swap',
      () {
        var last = T.cloudAlpha(0);
        for (final t in _times(_frame).skip(1)) {
          final alpha = T.cloudAlpha(t);
          expect((alpha - last).abs(), lessThan(0.05));
          last = alpha;
        }
        expect(T.cloudAlpha(3.3), 1);
        expect(T.cloudAlpha(3.75), lessThan(0.2));
        expect(T.cloudAlpha(T.end), 0);
      },
    );

    test('he goes from asleep to glad with no wide-eyed face between', () {
      final seen = <HeroFace>{};
      for (final t in _times(_frame)) {
        final face = T.face(t);
        seen
          ..add(face.from)
          ..add(face.to);
      }
      expect(seen, {HeroFace.glad, HeroFace.relieved, HeroFace.listening});
      final waking = T.face(3.4);
      expect(waking.from, HeroFace.listening);
      expect(waking.to, HeroFace.glad);
      expect(T.face(3.6).blend, 1);
    });

    test('the faces blend and never cut', () {
      var last = T.face(0);
      for (final t in _times(_frame).skip(1)) {
        final face = T.face(t);
        if (face.from == last.from && face.to == last.to) {
          expect((face.blend - last.blend).abs(), lessThan(0.06));
        }
        last = face;
      }
    });
  });

  group('Crit', () {
    test('his box is whole inside the screen at every 0.05 s', () {
      for (final size in _phones) {
        for (final mascot in [_mascotFor(size), null]) {
          for (final t in _times(0.05)) {
            final box = _crit(t, size, mascot: mascot);
            expect(
              Offset.zero & size,
              isA<Rect>().having(
                (r) => r.contains(box.topLeft) && r.contains(box.bottomRight),
                'holds the box at $t on $size',
                isTrue,
              ),
            );
          }
        }
      }
    });

    test('first frame: on the layout mascot, the stage with none', () {
      for (final size in _phones) {
        expect(_crit(0, size, mascot: _mascotFor(size)), _mascotFor(size));
        expect(_crit(0, size), T.stageBox(size));
        expect(T.rise(0), 0);
        expect(T.hasNight(0), isFalse);
        expect(T.cloudGrow(0), 0);
      }
    });

    test('at the swap he is on land, upright and not stretched', () {
      for (final size in _phones) {
        for (final mascot in [_mascotFor(size), null]) {
          expect(_crit(T.end, size, mascot: mascot), _landFor(size));
          expect(T.angle(T.end), 0);
          expect(T.stretch(T.end), 1);
        }
      }
    });

    test('he is upright and level from the end of his rise', () {
      for (final t in _times(0.05).where((t) => t >= 3.85)) {
        expect(T.angle(t), 0);
        expect(T.stretch(t), 1);
      }
    });
  });

  group('the sky at the swap', () {
    test('the cloud, trail, near clouds and words are gone', () {
      expect(T.cloudMelt(T.end), 1);
      expect(T.cloudAlpha(T.end), 0);
      expect(T.trailAlpha(T.end, 0), 0);
      expect(T.nearAlpha(T.end), 0);
      expect(T.wordsAlpha(T.end), 0);
      expect(T.boxAlpha(T.end), 0);
    });

    test('the moon covers every corner', () {
      for (final size in [..._phones, const Size(412, 915)]) {
        final centre = T.moonCentre(T.end, size);
        final radius = T.moonRadius(T.end, size);
        for (final corner in [
          Offset.zero,
          Offset(size.width, 0),
          Offset(0, size.height),
          Offset(size.width, size.height),
        ]) {
          expect((corner - centre).distance, lessThan(radius));
        }
      }
    });

    test('the hand over fades the last frame out over 0.2 s', () {
      expect(T.fadeOut(T.uncover), 0);
      expect(T.fadeOut(T.end), 1);
      expect(T.fadeOut(T.uncover + 0.1), closeTo(0.5, 1e-9));
    });
  });

  group('the near clouds', () {
    test('never touch his box', () {
      for (final size in _phones) {
        for (final mascot in [_mascotFor(size), null]) {
          for (final t in _times(0.05)) {
            final box = _crit(t, size, mascot: mascot);
            for (var i = 0; i < T.near.length; i++) {
              expect(
                T.nearBox(i, t, size).overlaps(box),
                isFalse,
                reason: 'near $i meets him at $t on $size',
              );
            }
          }
        }
      }
    });
  });

  group('the sky lists', () {
    test('22 seeded stars, 3 to 8 wide, that slide at 5 to 12 percent', () {
      expect(T.stars, hasLength(22));
      for (final star in T.stars) {
        expect(star.radius, inInclusiveRange(3, 8));
        expect(star.slide, inInclusiveRange(0.05, 0.12));
      }
      expect(T.far, hasLength(5));
      expect(T.mid, hasLength(4));
      expect(T.near, hasLength(4));
      for (final cloud in T.near) {
        expect(cloud.width, inInclusiveRange(300, 340));
      }
    });

    test('stars do not twinkle', () {
      for (var i = 0; i < T.stars.length; i++) {
        final a = T.starAt(i, 2, const Size(390, 844)).dx;
        final b = T.starAt(i, 3, const Size(390, 844)).dx;
        expect(a, b);
      }
    });
  });

  group('the words', () {
    test('fade in from 1.25 and out to 3.0', () {
      expect(T.wordsAlpha(1.25), 0);
      expect(T.wordsAlpha(1.75), closeTo(1, 1e-9));
      expect(T.wordsAlpha(2.6), closeTo(1, 1e-9));
      expect(T.wordsAlpha(3), 0);
      expect(math.max(T.wordsAlpha(2), 0), 1);
    });

    test('split at the last space', () {
      expect(T.splitWords('Welcome to Hosted'), ('Welcome to', 'Hosted'));
      expect(T.splitWords('Hosted'), ('Hosted', ''));
    });
  });

  group('the outro', () {
    test('is sound', () {
      expect(cloudClimb.isSound, isTrue);
      expect(cloudClimb.seconds, 4.1);
      expect(cloudClimb.uncover, 3.9);
      expect(cloudClimb.beats.map((b) => b.at), [0.0, 1.25, 2.6, 3.6]);
    });
  });
}
