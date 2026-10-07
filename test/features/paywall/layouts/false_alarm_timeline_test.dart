import 'dart:ui';

import 'package:critalarm/features/paywall/presentation/layouts/false_alarm/false_alarm_timeline.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/hero/hero_arrangement.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const tl = FalseAlarmTimeline.restAt;

  group('the order of the joke', () {
    test('ring, admit, reveal, buy block, the offer, gone', () {
      expect(FalseAlarmTimeline.ringEnd, lessThan(FalseAlarmTimeline.admit));
      expect(FalseAlarmTimeline.admit, lessThan(FalseAlarmTimeline.reveal));
      expect(FalseAlarmTimeline.reveal, lessThan(FalseAlarmTimeline.prelude));
      expect(
        FalseAlarmTimeline.prelude,
        lessThan(FalseAlarmTimeline.buyBlockAt),
      );
      expect(FalseAlarmTimeline.buyBlockAt, lessThan(FalseAlarmTimeline.end));
      // The red is all but gone from the foot before the buy block shows.
      expect(
        FalseAlarmTimeline.wipe(FalseAlarmTimeline.buyBlockAt),
        greaterThan(0.85),
      );
      // About a second and a half of joke, never a long one.
      expect(FalseAlarmTimeline.end, lessThanOrEqualTo(1.8));
    });

    test('the first frame is the whole alarm', () {
      expect(FalseAlarmTimeline.wipe(0), 0);
      expect(FalseAlarmTimeline.presence(0), 1);
      expect(FalseAlarmTimeline.saysAlarm(0), isTrue);
      expect(FalseAlarmTimeline.showsBuyBlock(0), isFalse);
      expect(FalseAlarmTimeline.face(0).from, FalseAlarmFace.alarmed);
      expect(FalseAlarmTimeline.face(0).blend, 0);
      expect(FalseAlarmTimeline.ring(0, 0), 0);
      expect(FalseAlarmTimeline.ring(1, 0), isNull);
    });

    test('the face goes alarmed, sheepish, glad', () {
      final admitted = FalseAlarmTimeline.face(FalseAlarmTimeline.admit);
      expect(admitted.to, FalseAlarmFace.sheepish);
      expect(admitted.blend, 1);
      final done = FalseAlarmTimeline.face(FalseAlarmTimeline.prelude);
      expect(done.to, FalseAlarmFace.glad);
      expect(done.blend, 1);
    });

    test('it blinks once, between the ring and the admission', () {
      expect(FalseAlarmTimeline.blink(0.5), 0);
      expect(FalseAlarmTimeline.blink(0.96), greaterThan(0.8));
      expect(FalseAlarmTimeline.blink(FalseAlarmTimeline.reveal), 0);
    });

    test('the red is still whole when the admission lands', () {
      expect(FalseAlarmTimeline.saysAlarm(FalseAlarmTimeline.admit), isFalse);
      expect(FalseAlarmTimeline.admission(FalseAlarmTimeline.reveal), 1);
      expect(FalseAlarmTimeline.wipe(FalseAlarmTimeline.reveal), 0);
      expect(FalseAlarmTimeline.wipe(FalseAlarmTimeline.end), 1);
    });
  });

  group('the shake', () {
    test('never leans past five degrees', () {
      for (var t = 0.0; t < 2; t += 0.004) {
        expect(
          FalseAlarmTimeline.shake(t).abs(),
          lessThanOrEqualTo(FalseAlarmTimeline.shakeReach + 1e-9),
        );
      }
    });

    test('moves while it rings', () {
      var widest = 0.0;
      for (var t = 0.0; t < FalseAlarmTimeline.ringEnd; t += 0.004) {
        final lean = FalseAlarmTimeline.shake(t).abs();
        if (lean > widest) widest = lean;
      }
      expect(widest, greaterThan(FalseAlarmTimeline.shakeReach * 0.8));
    });

    test('starts and ends at zero and stays there', () {
      expect(FalseAlarmTimeline.shake(0), 0);
      expect(FalseAlarmTimeline.shake(FalseAlarmTimeline.ringEnd), 0);
      for (var t = FalseAlarmTimeline.ringEnd; t < 6; t += 0.05) {
        expect(FalseAlarmTimeline.shake(t), 0);
        expect(FalseAlarmTimeline.ringing(t), 0);
      }
    });

    test('no ring starts once the ringing has stopped', () {
      for (var t = 1.25; t < 6; t += 0.05) {
        expect(FalseAlarmTimeline.ring(0, t), isNull);
        expect(FalseAlarmTimeline.ring(1, t), isNull);
      }
    });
  });

  group('the skip', () {
    test('a tap during the joke jumps to the reveal', () {
      expect(FalseAlarmTimeline.skip(0), FalseAlarmTimeline.reveal);
      expect(FalseAlarmTimeline.skip(0.7), FalseAlarmTimeline.reveal);
      expect(FalseAlarmTimeline.skip(1.1), FalseAlarmTimeline.reveal);
    });

    test('a tap after it changes nothing', () {
      expect(
        FalseAlarmTimeline.skip(FalseAlarmTimeline.reveal),
        FalseAlarmTimeline.reveal,
      );
      expect(FalseAlarmTimeline.skip(3), 3);
    });

    test('where it lands the admission is up and nothing leans', () {
      const at = FalseAlarmTimeline.reveal;
      expect(FalseAlarmTimeline.shake(at), 0);
      expect(FalseAlarmTimeline.admission(at), 1);
      expect(FalseAlarmTimeline.saysAlarm(at), isFalse);
    });
  });

  group('the resting frame', () {
    test('is the offer, with nothing of the joke left', () {
      expect(tl, greaterThan(FalseAlarmTimeline.end));
      expect(FalseAlarmTimeline.isOver(tl), isTrue);
      expect(FalseAlarmTimeline.wipe(tl), 1);
      expect(FalseAlarmTimeline.presence(tl), 0);
      expect(FalseAlarmTimeline.shake(tl), 0);
      expect(FalseAlarmTimeline.blink(tl), 0);
      expect(FalseAlarmTimeline.showsBuyBlock(tl), isTrue);
    });
  });

  group('room for the tag', () {
    test('a tall stage keeps it under the cross, beside the mascot', () {
      const stage = Size(390, 380);
      final arrangement = heroArrangementFor(stage);
      final room = falseAlarmTagRoom(stage: stage, arrangement: arrangement)!;
      expect(room.left, greaterThan(arrangement.mascot.right));
      expect(room.bottom, lessThan(arrangement.card.top));
      expect(room.top, greaterThanOrEqualTo(48));
      expect(room.right, lessThanOrEqualTo(stage.width - heroSideRoom));
    });

    test('a short stage keeps it beside the cross', () {
      const stage = Size(375, 235);
      final arrangement = heroArrangementFor(stage);
      final room = falseAlarmTagRoom(stage: stage, arrangement: arrangement)!;
      expect(room.right, lessThanOrEqualTo(stage.width - 48));
      expect(room.bottom, lessThan(arrangement.card.top));
    });

    test('a stage with no card has no tag', () {
      const stage = Size(375, 120);
      final arrangement = heroArrangementFor(stage);
      expect(arrangement.kind, isNot(HeroStageKind.pair));
      expect(
        falseAlarmTagRoom(stage: stage, arrangement: arrangement),
        isNull,
      );
    });
  });
}
