import 'package:critalarm/features/paywall/presentation/intros/false_alarm/false_alarm_intro.dart';
import 'package:critalarm/features/paywall/presentation/intros/false_alarm/false_alarm_timeline.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_intro.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Any second after the intro is over.
  const tl = FalseAlarmTimeline.end + 1;

  group('the order of the joke', () {
    test('ring, admit, reveal, hand over, gone', () {
      expect(FalseAlarmTimeline.ringEnd, lessThan(FalseAlarmTimeline.admit));
      expect(FalseAlarmTimeline.admit, lessThan(FalseAlarmTimeline.reveal));
      expect(FalseAlarmTimeline.reveal, lessThan(FalseAlarmTimeline.handover));
      expect(FalseAlarmTimeline.handover, lessThan(FalseAlarmTimeline.end));
      // The red has opened past the mascot before the layout starts.
      expect(
        FalseAlarmTimeline.wipe(FalseAlarmTimeline.handover),
        greaterThan(0.5),
      );
      // About a second and a half of joke, never a long one.
      expect(FalseAlarmTimeline.end, lessThanOrEqualTo(1.8));
    });

    test('the intro is registered with the seconds of the timeline', () {
      expect(falseAlarmIntro.isSound, isTrue);
      expect(falseAlarmIntro.seconds, FalseAlarmTimeline.end);
      expect(falseAlarmIntro.handover, FalseAlarmTimeline.handover);
      expect(falseAlarmIntro.skipTo, FalseAlarmTimeline.reveal);
      for (final t in [0.0, 0.7, 1.1, 1.25, 1.6, 3.0]) {
        expect(
          paywallIntroSkip(falseAlarmIntro, t),
          FalseAlarmTimeline.skip(t),
        );
      }
    });

    test('the admission is read, then gone before the layout starts', () {
      expect(FalseAlarmTimeline.words(FalseAlarmTimeline.admit), 1);
      expect(FalseAlarmTimeline.words(FalseAlarmTimeline.reveal), 1);
      expect(FalseAlarmTimeline.words(FalseAlarmTimeline.handover), 0);
      expect(FalseAlarmTimeline.words(FalseAlarmTimeline.end), 0);
      // The mascot is gone by the hand over: the layout's own comes up
      // where it went, and two faces never show together.
      expect(FalseAlarmTimeline.leave(FalseAlarmTimeline.reveal), 0);
      expect(FalseAlarmTimeline.leave(FalseAlarmTimeline.handover), 1);
    });

    test('the first frame is the whole alarm', () {
      expect(FalseAlarmTimeline.wipe(0), 0);
      expect(FalseAlarmTimeline.leave(0), 0);
      expect(FalseAlarmTimeline.saysAlarm(0), isTrue);
      expect(FalseAlarmTimeline.face(0).from, FalseAlarmFace.alarmed);
      expect(FalseAlarmTimeline.face(0).blend, 0);
      expect(FalseAlarmTimeline.ring(0, 0), 0);
      expect(FalseAlarmTimeline.ring(1, 0), isNull);
    });

    test('the face goes alarmed, sheepish, glad', () {
      final admitted = FalseAlarmTimeline.face(FalseAlarmTimeline.admit);
      expect(admitted.to, FalseAlarmFace.sheepish);
      expect(admitted.blend, 1);
      final done = FalseAlarmTimeline.face(FalseAlarmTimeline.handover);
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

  group('after the intro', () {
    test('nothing of the joke is left once it is over', () {
      expect(tl, greaterThan(FalseAlarmTimeline.end));
      expect(FalseAlarmTimeline.isOver(tl), isTrue);
      expect(FalseAlarmTimeline.wipe(tl), 1);
      expect(FalseAlarmTimeline.leave(tl), 1);
      expect(FalseAlarmTimeline.shake(tl), 0);
      expect(FalseAlarmTimeline.blink(tl), 0);
    });
  });
}
