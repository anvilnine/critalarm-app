import 'dart:ui';

import 'package:critalarm/design/components/pass_route.dart';
import 'package:critalarm/design/tokens/colors.dart';
import 'package:critalarm/design/tokens/curves.dart';
import 'package:critalarm/design/tokens/pass_tones.dart';
import 'package:flutter_test/flutter_test.dart';

const PassDisplay _display = PassDisplay.phone;

const _tops = [122.0, 256.0, 390.0, 524.0, 658.0];

PassOrigin _origin(int index, {double bottomRadius = 0}) => PassOrigin(
  pass: PassId.values[index],
  rect: Rect.fromLTWH(12, _tops[index], 366, index == 4 ? 220 : 260),
  tone: passToneFor(PassId.values[index], AppColors.light),
  label: 'Label',
  value: 'Value',
  display: _display,
  bottomRadius: bottomRadius,
);

/// The progress of the route at [ms] milliseconds into the way in.
double _in(double ms) => ms / 600;

/// The progress of the route at [ms] milliseconds into the way out.
double _out(double ms) => 1 - ms / 520;

PassFrame _forward(double progress, [PassOrigin? origin]) =>
    passFrameAt(progress, origin ?? _origin(0));

PassFrame _back(double progress, [PassOrigin? origin]) =>
    passFrameAt(progress, origin ?? _origin(0), reverse: true);

void main() {
  group('opening, for the card at each of five positions', () {
    for (var i = 0; i < 5; i++) {
      group('position $i', () {
        final origin = _origin(i);

        test('starts as the card', () {
          final frame = _forward(0, origin);
          expect(frame.rect, origin.rect);
          expect(frame.topRadius, 32);
          expect(frame.bottomRadius, 0);
          expect(frame.valueSize, 30);
          expect(frame.grow, 0);
          expect(frame.thumbOpacity, 1);
          expect(frame.thumbOffset, Offset.zero);
          expect(frame.thumbScale, 1);
          expect(frame.headerOffset.dx, origin.rect.left + 20 - 20);
          expect(frame.headerOffset.dy, origin.rect.top + 18 - (47 + 71));
        });

        test('ends as the page', () {
          final frame = _forward(1, origin);
          expect(frame.rect, _display.rect);
          expect(frame.topRadius, 0);
          expect(frame.bottomRadius, 0);
          expect(frame.valueSize, 42);
          expect(frame.grow, 1);
          expect(frame.headerOffset, Offset.zero);
          expect(frame.thumbOpacity, 0);
          expect(frame.shadowOpacity, 0);
        });

        test('is part way at 0.5', () {
          final frame = _forward(0.5, origin);
          final grow = AppCurves.passGrow.transform(300 / 520);
          expect(frame.grow, closeTo(grow, 1e-9));
          expect(frame.rect.top, closeTo(origin.rect.top * (1 - grow), 1e-9));
          expect(frame.rect.height, greaterThan(origin.rect.height));
          expect(frame.valueSize, closeTo(30 + 12 * grow, 1e-9));
          expect(
            frame.headerOffset.dy,
            closeTo((origin.rect.top - 100) * (1 - grow), 1e-9),
          );
        });

        test('closes back into the card', () {
          final start = _back(1, origin);
          expect(start.rect, _display.rect);
          expect(start.valueSize, 42);
          final end = _back(0, origin);
          expect(end.rect, origin.rect);
          expect(end.valueSize, 30);
          expect(end.topRadius, 32);
          expect(end.headerOffset.dy, origin.rect.top + 18 - (47 + 71));
        });
      });
    }
  });

  group('the grow', () {
    test('only gets bigger on the way in', () {
      var last = -1.0;
      for (var p = 0.0; p <= 1.0; p += 0.05) {
        final frame = _forward(p);
        expect(frame.grow, greaterThanOrEqualTo(last));
        last = frame.grow;
      }
    });

    test('is done at 520 ms, before the route is', () {
      expect(_forward(_in(520)).rect, _display.rect);
      expect(_forward(_in(520)).valueSize, 42);
      expect(_forward(_in(519)).rect, isNot(_display.rect));
    });

    test('runs back over 520 ms and is done when the route is', () {
      expect(_back(_out(520)).rect, _origin(0).rect);
      expect(_back(_out(0)).rect, _display.rect);
    });

    test('rounds the bottom corners of a flat card', () {
      final origin = _origin(0, bottomRadius: 32);
      expect(_forward(0, origin).bottomRadius, 32);
      expect(_forward(1, origin).bottomRadius, 0);
    });

    test('keeps the radius between its ends on the way', () {
      final frame = _forward(0.3);
      expect(frame.topRadius, inInclusiveRange(0, 32));
    });
  });

  group('the value', () {
    test('goes from 30 to 42 points', () {
      expect(_forward(0).valueSize, 30);
      expect(_forward(1).valueSize, 42);
      expect(_back(0).valueSize, 30);
    });
  });

  group('the back ring', () {
    test('is clear until 200 ms and full by 500 ms', () {
      expect(_forward(_in(0)).ringOpacity, 0);
      expect(_forward(_in(200)).ringOpacity, 0);
      expect(_forward(_in(350)).ringOpacity, inExclusiveRange(0, 1));
      expect(_forward(_in(500)).ringOpacity, 1);
      expect(_forward(1).ringOpacity, 1);
    });

    test('fades out over 300 ms after 200 ms on the way back', () {
      expect(_back(_out(0)).ringOpacity, 1);
      expect(_back(_out(200)).ringOpacity, 1);
      expect(_back(_out(350)).ringOpacity, inExclusiveRange(0, 1));
      expect(_back(_out(500)).ringOpacity, 0);
    });
  });

  group('the body', () {
    test('is clear until 300 ms and full by 600 ms', () {
      expect(_forward(_in(0)).bodyOpacity, 0);
      expect(_forward(_in(300)).bodyOpacity, 0);
      expect(_forward(_in(450)).bodyOpacity, inExclusiveRange(0, 1));
      expect(_forward(_in(600)).bodyOpacity, 1);
    });

    test('fades out over 300 ms with no delay on the way back', () {
      expect(_back(_out(0)).bodyOpacity, 1);
      expect(_back(_out(150)).bodyOpacity, inExclusiveRange(0, 1));
      expect(_back(_out(300)).bodyOpacity, 0);
      expect(_back(_out(520)).bodyOpacity, 0);
    });
  });

  group('the other cards', () {
    test('rest at the start', () {
      final frame = _forward(0);
      expect(frame.othersOffset, 0);
      expect(frame.othersOpacity, 1);
    });

    test('are 120 points down by 450 ms and clear by 300 ms', () {
      expect(_forward(_in(450)).othersOffset, closeTo(120, 1e-9));
      expect(_forward(_in(300)).othersOpacity, 0);
      expect(_forward(_in(150)).othersOpacity, inExclusiveRange(0, 1));
      expect(_forward(1).othersOffset, closeTo(120, 1e-9));
      expect(_forward(1).othersOpacity, 0);
    });

    test('come back over the same times', () {
      expect(_back(_out(0)).othersOffset, closeTo(120, 1e-9));
      expect(_back(_out(0)).othersOpacity, 0);
      expect(_back(_out(300)).othersOpacity, 1);
      expect(_back(_out(450)).othersOffset, closeTo(0, 1e-9));
      expect(_back(0).othersOffset, closeTo(0, 1e-9));
      expect(_back(0).othersOpacity, 1);
    });
  });

  group('the thumbnail', () {
    test('flies with the grow and is gone when it ends', () {
      final mid = _forward(0.5);
      expect(mid.thumbScale, greaterThan(1));
      expect(mid.thumbOffset.dx, lessThan(0));
      expect(mid.thumbOffset.dy, greaterThan(0));
      final end = _forward(1);
      expect(end.thumbScale, closeTo(2.6, 1e-9));
      expect(end.thumbOffset.dx, closeTo(-112, 1e-9));
      expect(end.thumbOffset.dy, closeTo(236, 1e-9));
    });

    test('is whole until 55% of the grow, then fades to nothing', () {
      expect(_forward(_in(0.55 * 520 - 1)).thumbOpacity, 1);
      expect(_forward(_in(0.8 * 520)).thumbOpacity, inExclusiveRange(0, 1));
      expect(_forward(_in(520)).thumbOpacity, 0);
    });

    test('is back before the card is on the way out', () {
      expect(_back(_out(0)).thumbOpacity, 0);
      expect(_back(_out(0.45 * 520)).thumbOpacity, 1);
      expect(_back(0).thumbOpacity, 1);
    });

    test('flies a shorter way on a small display', () {
      const small = PassDisplay(Size(320, 640), safeTop: 24);
      final frame = passFrameAt(1, _origin(0), display: small);
      expect(frame.thumbOffset.dx, greaterThan(-112));
      expect(frame.thumbOffset.dy, lessThan(236));
    });
  });

  group('reduce motion', () {
    PassFrame reduced(double p, {bool reverse = false}) => passFrameAt(
      p,
      _origin(2),
      reverse: reverse,
      reduceMotion: true,
    );

    test('fades the finished page and grows nothing', () {
      for (final p in [0.0, 0.25, 0.5, 1.0]) {
        final frame = reduced(p);
        expect(frame.rect, _display.rect);
        expect(frame.topRadius, 0);
        expect(frame.valueSize, 42);
        expect(frame.headerOffset, Offset.zero);
        expect(frame.thumbOpacity, 0);
        expect(frame.pageOpacity, p);
      }
    });

    test('has the back ring and body on from the first frame', () {
      final frame = reduced(0);
      expect(frame.ringOpacity, 1);
      expect(frame.bodyOpacity, 1);
    });

    test('moves none of the other cards', () {
      final frame = reduced(0.5);
      expect(frame.othersOffset, 0);
      expect(frame.othersOpacity, 1);
    });

    test('fades the same way out', () {
      expect(reduced(0.3, reverse: true).pageOpacity, 0.3);
    });

    test('is taken from the origin when not asked', () {
      final origin = PassOrigin(
        pass: PassId.sound,
        rect: const Rect.fromLTWH(12, 256, 366, 260),
        tone: passToneFor(PassId.sound, AppColors.light),
        label: 'Sound',
        value: 'Classic siren',
        display: _display,
        reduceMotion: true,
      );
      final frame = passFrameAt(0.5, origin);
      expect(frame.rect, _display.rect);
      expect(frame.pageOpacity, 0.5);
    });
  });

  group('with no origin', () {
    test('the page is already in place', () {
      for (final p in [0.0, 0.5, 1.0]) {
        final frame = passFrameAt(p, null, display: _display);
        expect(frame, PassFrame.settled(_display));
        expect(frame.rect, _display.rect);
        expect(frame.ringOpacity, 1);
        expect(frame.bodyOpacity, 1);
        expect(frame.pageOpacity, 1);
        expect(frame.headerOffset, Offset.zero);
      }
    });
  });

  group('the display', () {
    test('keeps the header in a centred column of 560', () {
      const wide = PassDisplay(Size(1024, 768));
      expect(wide.columnLeft, 232);
      final frame = passFrameAt(0, _origin(0), display: wide);
      expect(frame.headerOffset.dx, 12 + 20 - (232 + 20));
      expect(frame.headerOffset.dy, 122 + 18 - 71);
    });
  });
}
