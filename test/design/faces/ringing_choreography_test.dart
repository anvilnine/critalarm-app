import 'dart:math' as math;

import 'package:critalarm/design/faces/faces.dart';
import 'package:flutter_test/flutter_test.dart';

/// Every number that decides where something is drawn, in one list, so two
/// frames can be compared and checked for NaN in one go.
List<double> _numbers(RingingFrame f) {
  final face = f.face;
  final out = <double>[
    f.tilt % (2 * math.pi),
    f.nudge.dx,
    f.nudge.dy,
    f.scale,
    f.flush,
    f.flash,
    face.head.squashX,
    face.head.squashY,
    face.head.strokeWidth,
    face.mouth.fill,
    face.mouth.width,
  ];
  void add(Offset o) => out.addAll([o.dx, o.dy]);
  face.mouth.points.forEach(add);
  for (final eye in [face.leftEye, face.rightEye]) {
    add(eye.centre);
    add(eye.pupilOffset);
    out.addAll([eye.ball, eye.pupilRadius, eye.lid, eye.spiral]);
  }
  for (final brow in [face.leftBrow, face.rightBrow]) {
    brow.points.forEach(add);
    out.add(brow.alpha);
  }
  return out;
}

/// The extras, in the same order every frame.
List<RingFx> _extras(RingingFrame f) => f.fx;

void main() {
  test('there are between 10 and 20 ringing styles, all named', () {
    expect(RingingStyle.values.length, inInclusiveRange(10, 20));
    final labels = RingingStyle.values.map((s) => s.label).toSet();
    expect(labels.length, RingingStyle.values.length);
    for (final style in RingingStyle.values) {
      expect(style.description, isNotEmpty, reason: style.name);
      expect(style.period.inMilliseconds, greaterThan(0), reason: style.name);
      expect(style.stillT, inInclusiveRange(0, 1), reason: style.name);
    }
  });

  for (final style in RingingStyle.values) {
    group(style.name, () {
      test('every frame of the loop is well formed', () {
        for (var i = 0; i <= 200; i++) {
          final frame = ringingFrameFor(style, i / 200);
          expect(
            frame.face.mouth.points,
            hasLength(MouthShape.pointCount),
            reason: 't=${i / 200}',
          );
          final numbers = [
            ..._numbers(frame),
            for (final fx in frame.fx) ...[fx.at.dx, fx.at.dy, fx.scale],
          ];
          for (final n in numbers) {
            expect(n.isFinite, isTrue, reason: 't=${i / 200}');
          }
          expect(frame.scale, greaterThan(0));
          expect(frame.flush, inInclusiveRange(0, 1));
          expect(frame.flash, inInclusiveRange(0, 1));
        }
      });

      test('the end of the loop lands where the start begins', () {
        final start = ringingFrameFor(style, 0);
        final end = ringingFrameFor(style, 1 - 1e-6);
        expect(end.fx.length, start.fx.length);
        final a = _numbers(start);
        final b = _numbers(end);
        for (var i = 0; i < a.length; i++) {
          // Tilt is compared on the circle, so a full spin still matches.
          final gap = i == 0
              ? math.min((a[i] - b[i]).abs(), 2 * math.pi - (a[i] - b[i]).abs())
              : (a[i] - b[i]).abs();
          expect(gap, lessThan(0.5), reason: 'number $i: ${a[i]} vs ${b[i]}');
        }
        // A drop that has finished its flight starts a new one, so an extra
        // may jump. It has to be out of sight when it does.
        final fa = _extras(start);
        final fb = _extras(end);
        for (var i = 0; i < fa.length; i++) {
          final what = '${fa[i].kind.name} $i';
          expect(
            (fa[i].alpha - fb[i].alpha).abs(),
            lessThan(0.05),
            reason: '$what alpha',
          );
          if (fa[i].alpha > 0.05 && fa[i].scale > 0.05) {
            expect(
              (fa[i].at - fb[i].at).distance,
              lessThan(0.5),
              reason: '$what moved',
            );
            expect(
              (fa[i].scale - fb[i].scale).abs(),
              lessThan(0.05),
              reason: '$what scale',
            );
          }
        }
      });

      test('time past the loop wraps back into it', () {
        final a = _numbers(ringingFrameFor(style, 1.3));
        final b = _numbers(ringingFrameFor(style, 0.3));
        expect(a.length, b.length);
        for (var i = 0; i < a.length; i++) {
          final gap = (a[i] - b[i]).abs();
          // Tilt is on the circle: just under a full turn is just over none.
          final onCircle = i == 0 ? math.min(gap, 2 * math.pi - gap) : gap;
          expect(onCircle, lessThan(1e-6), reason: 'number $i');
        }
      });
    });
  }
}
