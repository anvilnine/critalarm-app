import 'dart:math' as math;

import 'package:critalarm/features/onboarding/domain/welcome_stays_silent_timeline.dart';
import 'package:flutter_test/flutter_test.dart';

WelcomeStaysSilentFrame at(double seconds) =>
    welcomeStaysSilentFrameAt(seconds, reducedMotion: false);

/// The frame at [fraction] of the loop.
WelcomeStaysSilentFrame atFraction(double fraction) =>
    at(fraction * welcomeStaysSilentLoopSeconds);

void main() {
  group('the loop', () {
    test('is 8 seconds', () {
      expect(welcomeStaysSilentLoopSeconds, 8);
    });

    test('every part repeats every 8 seconds', () {
      for (final s in [0.0, 0.5, 1.9, 3.3, 4.2, 4.8, 5.6, 7.7]) {
        final a = at(s + welcomeStaysSilentLoopSeconds);
        final b = at(s + 3 * welcomeStaysSilentLoopSeconds);
        expect(a.jolt, closeTo(b.jolt, 1e-9));
        expect(a.alarm.scale, closeTo(b.alarm.scale, 1e-9));
        expect(a.alarm.opacity, closeTo(b.alarm.opacity, 1e-9));
        expect(a.alarm.glow, closeTo(b.alarm.glow, 1e-9));
        expect(a.alarm.shiver, closeTo(b.alarm.shiver, 1e-9));
        for (var i = 0; i < welcomeStaysSilentRowCount; i++) {
          expect(a.rows[i].offset, closeTo(b.rows[i].offset, 1e-9));
          expect(a.rows[i].scale, closeTo(b.rows[i].scale, 1e-9));
          expect(a.rows[i].opacity, closeTo(b.rows[i].opacity, 1e-9));
        }
      }
    });

    test('starts over from an empty queue', () {
      final start = at(0);
      final end = atFraction(0.999);
      for (var i = 0; i < welcomeStaysSilentRowCount; i++) {
        expect(start.rows[i].opacity, closeTo(0, 1e-6));
        expect(end.rows[i].opacity, closeTo(0, 0.01));
      }
      expect(start.alarm.opacity, closeTo(0, 1e-6));
      expect(end.alarm.opacity, closeTo(0, 0.05));
    });

    test('every value stays in its range over the whole loop', () {
      for (var ms = 0; ms < 8000; ms += 20) {
        final frame = at(ms / 1000);
        for (final row in frame.rows) {
          expect(row.opacity, inInclusiveRange(0, 1), reason: 'at $ms ms');
          expect(row.scale, inInclusiveRange(0.9, 1), reason: 'at $ms ms');
        }
        expect(frame.alarm.opacity, inInclusiveRange(0, 1));
        expect(frame.alarm.scale, greaterThanOrEqualTo(0));
        expect(frame.alarm.glow, inInclusiveRange(0, 1));
        expect(frame.jolt.abs(), lessThanOrEqualTo(7));
      }
    });
  });

  group('the muted rows', () {
    test('slide in one after another, from the top', () {
      for (var i = 0; i < welcomeStaysSilentRowCount; i++) {
        final before = atFraction(welcomeStaysSilentRowFrom[i]);
        expect(before.rows[i].opacity, closeTo(0, 1e-6));
        expect(before.rows[i].offset, -welcomeStaysSilentRowDrop);
        final after = atFraction(welcomeStaysSilentRowBy[i]);
        expect(after.rows[i].opacity, closeTo(1, 1e-6));
        expect(after.rows[i].offset, closeTo(0, 1e-6));
      }
      final inOrder = atFraction(0.13);
      expect(inOrder.rows[0].opacity, closeTo(1, 1e-6));
      expect(inOrder.rows[1].opacity, lessThan(1));
      expect(inOrder.rows[2].opacity, closeTo(0, 1e-6));
    });

    test('all three sit in place until 50 percent', () {
      final frame = atFraction(welcomeStaysSilentRowsHoldUntil);
      for (final row in frame.rows) {
        expect(row.offset, closeTo(0, 1e-6));
        expect(row.scale, closeTo(1, 1e-6));
        expect(row.opacity, closeTo(1, 1e-6));
      }
    });

    test('give way and dim from 50 to 56 percent: the top one up, the others '
        'down', () {
      final frame = atFraction(welcomeStaysSilentRowsAsideBy);
      expect(frame.rows[0].offset, -70);
      expect(frame.rows[1].offset, 90);
      expect(frame.rows[2].offset, 100);
      for (final row in frame.rows) {
        expect(row.scale, welcomeStaysSilentRowAsideScale);
        expect(row.opacity, welcomeStaysSilentRowAsideOpacity);
      }
    });

    test('stay dim and aside while the alarm rings', () {
      final frame = atFraction(0.8);
      for (final row in frame.rows) {
        expect(row.opacity, welcomeStaysSilentRowAsideOpacity);
      }
    });

    test('fade out from 94 percent', () {
      expect(
        atFraction(welcomeStaysSilentRowsLeaveFrom).rows[0].opacity,
        welcomeStaysSilentRowAsideOpacity,
      );
      expect(atFraction(0.97).rows[0].opacity, lessThan(0.35));
    });
  });

  group('the alarm', () {
    test('is unseen and small until 50 percent', () {
      final frame = atFraction(welcomeStaysSilentAlarmFrom);
      expect(frame.alarm.opacity, closeTo(0, 1e-6));
      expect(frame.alarm.scale, welcomeStaysSilentAlarmFromScale);
    });

    test('is in at its size and fully shown by 58 percent', () {
      final frame = atFraction(welcomeStaysSilentAlarmBy);
      expect(frame.alarm.opacity, closeTo(1, 1e-6));
      expect(frame.alarm.scale, closeTo(1, 1e-6));
    });

    test('lands past its size on the way in, then settles', () {
      var biggest = 0.0;
      for (var p = 0.5; p <= 0.58; p += 0.002) {
        biggest = math.max(biggest, atFraction(p).alarm.scale);
      }
      expect(biggest, greaterThan(1));
      expect(biggest, lessThan(1.2));
    });

    test('rings until 94 percent and then leaves', () {
      expect(atFraction(0.7).alarm.opacity, closeTo(1, 1e-6));
      expect(
        atFraction(welcomeStaysSilentAlarmLeavesFrom).alarm.opacity,
        closeTo(1, 1e-6),
      );
      expect(atFraction(0.999).alarm.opacity, lessThan(0.1));
    });

    test('the rows are aside by the time the alarm is in', () {
      final frame = atFraction(welcomeStaysSilentAlarmBy);
      expect(frame.rows[0].opacity, welcomeStaysSilentRowAsideOpacity);
    });

    test('the haptic plays when the alarm lands', () {
      expect(welcomeStaysSilentAlarmLandsAt, closeTo(4.64, 1e-9));
      expect(
        at(welcomeStaysSilentAlarmLandsAt).alarm.opacity,
        closeTo(1, 1e-6),
      );
    });

    test('the ring around it spreads over 1.2 seconds and starts over', () {
      expect(at(0).alarm.glow, closeTo(0, 1e-6));
      expect(at(0.6).alarm.glow, greaterThan(0.5));
      expect(
        at(1.2 + 0.3).alarm.glow,
        closeTo(at(0.3).alarm.glow, 1e-9),
      );
    });

    test('the face on it turns 3 degrees each way every 0.45 seconds', () {
      expect(at(0).alarm.shiver * 180 / math.pi, closeTo(-3, 1e-3));
      expect(
        at(welcomeStaysSilentShiverSeconds / 2).alarm.shiver * 180 / math.pi,
        closeTo(3, 1e-3),
      );
      expect(
        at(welcomeStaysSilentShiverSeconds).alarm.shiver,
        closeTo(at(0).alarm.shiver, 1e-9),
      );
    });
  });

  group('the jolt', () {
    test('is still before 52 percent and after 62', () {
      expect(atFraction(0.3).jolt, closeTo(0, 1e-6));
      expect(atFraction(0.52).jolt, closeTo(0, 1e-6));
      expect(atFraction(0.62).jolt, closeTo(0, 1e-6));
      expect(atFraction(0.9).jolt, closeTo(0, 1e-6));
    });

    test('shakes -7, 7, -4, 4 as the alarm lands', () {
      expect(atFraction(0.54).jolt, closeTo(-7, 1e-9));
      expect(atFraction(0.56).jolt, closeTo(7, 1e-9));
      expect(atFraction(0.58).jolt, closeTo(-4, 1e-9));
      expect(atFraction(0.60).jolt, closeTo(4, 1e-9));
    });
  });

  group('reduced motion', () {
    test('is the same frame at every time', () {
      for (final s in [0.0, 1.0, 3.3, 4.7, 7.9, 123.4]) {
        final frame = welcomeStaysSilentFrameAt(s, reducedMotion: true);
        expect(identical(frame, welcomeStaysSilentSettled), isTrue);
      }
    });

    test('is the frame where the alarm has got through', () {
      const frame = welcomeStaysSilentSettled;
      expect(frame.alarm.opacity, closeTo(1, 1e-6));
      expect(frame.alarm.scale, closeTo(1, 1e-6));
      for (final row in frame.rows) {
        expect(row.opacity, welcomeStaysSilentRowAsideOpacity);
        expect(row.scale, welcomeStaysSilentRowAsideScale);
      }
      expect(frame.rows[0].offset, welcomeStaysSilentRowAside[0]);
      expect(frame.rows[1].offset, welcomeStaysSilentRowAside[1]);
      expect(frame.rows[2].offset, welcomeStaysSilentRowAside[2]);
    });

    test('matches the loop while the alarm rings, apart from the motion', () {
      final ringing = atFraction(0.8);
      const frame = welcomeStaysSilentSettled;
      expect(ringing.alarm.scale, frame.alarm.scale);
      expect(ringing.alarm.opacity, frame.alarm.opacity);
      for (var i = 0; i < welcomeStaysSilentRowCount; i++) {
        expect(ringing.rows[i].offset, frame.rows[i].offset);
        expect(ringing.rows[i].opacity, frame.rows[i].opacity);
      }
    });

    test('shakes and turns nothing', () {
      const frame = welcomeStaysSilentSettled;
      expect(frame.jolt, closeTo(0, 1e-6));
      expect(frame.alarm.shiver, closeTo(0, 1e-6));
    });
  });

  group('the size of a design unit', () {
    /// The picture on a phone [phone] points wide: 24 less on each side.
    double widthFor(double phone) => phone - 2 * 24;

    test('is 1 at the design size and above it', () {
      expect(
        welcomeStaysSilentUnit(
          welcomeStaysSilentDesignWidth,
          welcomeStaysSilentDesignHeight,
        ),
        closeTo(1, 1e-6),
      );
      expect(welcomeStaysSilentUnit(900, 900), closeTo(1, 1e-6));
    });

    test('from a 320 point phone to a 430 point phone it stays between the '
        'smallest size and 1, and grows with the width', () {
      for (final height in [340.0, 380.0, 457.0, 560.0]) {
        var last = 0.0;
        for (var phone = 320.0; phone <= 430; phone += 5) {
          final unit = welcomeStaysSilentUnit(widthFor(phone), height);
          expect(unit, inInclusiveRange(welcomeStaysSilentMinUnit, 1));
          expect(unit, greaterThanOrEqualTo(last));
          last = unit;
        }
      }
    });

    test('is 0.78 on a 320 point phone where the room is tall enough', () {
      expect(welcomeStaysSilentUnit(widthFor(320), 460), closeTo(0.777, 0.001));
    });

    test('is held by the height when the room is short', () {
      expect(
        welcomeStaysSilentUnit(350, 324),
        closeTo(324 / welcomeStaysSilentDesignHeight, 1e-9),
      );
    });

    test('never goes below the smallest size while the rows are drawn', () {
      for (final height in [260.0, 300.0, 457.0]) {
        expect(
          welcomeStaysSilentIsCompact(widthFor(320), height),
          isFalse,
          reason: 'height $height',
        );
        expect(
          welcomeStaysSilentUnit(widthFor(320), height),
          greaterThanOrEqualTo(welcomeStaysSilentMinUnit),
        );
      }
    });

    test('draws the alarm alone where the rows would need a smaller size', () {
      // A 320 point phone at a 1.3 text size leaves about 187 points.
      expect(welcomeStaysSilentIsCompact(widthFor(320), 187), isTrue);
      expect(welcomeStaysSilentIsCompact(widthFor(320), 259), isTrue);
      expect(welcomeStaysSilentIsCompact(widthFor(320), 260), isFalse);
      expect(welcomeStaysSilentIsCompact(widthFor(390), 400), isFalse);
    });

    test('sizes the compact picture by its own height', () {
      expect(
        welcomeStaysSilentUnit(widthFor(320), 187),
        closeTo(187 / welcomeStaysSilentCompactDesignHeight, 1e-9),
      );
      // It fits: the alarm card and the status line, with the unit it gets.
      for (final height in [140.0, 187.0, 230.0, 259.0]) {
        final unit = welcomeStaysSilentUnit(widthFor(320), height);
        expect(
          welcomeStaysSilentCompactDesignHeight * unit,
          lessThanOrEqualTo(height + 1e-9),
        );
      }
    });

    test(
      'keeps its text readable down to the room an animation is dropped at',
      () {
        // An animation is dropped below 120 points of room.
        expect(welcomeStaysSilentUnit(widthFor(320), 120), greaterThan(0.45));
      },
    );

    test(
      'the smallest text on the card stays readable at the smallest unit',
      () {
        // The smallest text is the topic name, 12 design units.
        expect(12 * welcomeStaysSilentMinUnit, greaterThanOrEqualTo(7));
      },
    );
  });
}
