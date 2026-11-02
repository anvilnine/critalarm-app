import 'package:critalarm/features/paywall/presentation/intros/false_alarm/false_alarm_intro.dart';
import 'package:critalarm/features/paywall/presentation/intros/false_alarm/false_alarm_timeline.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_intro.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Any second after the intro is over.
  const tl = FalseAlarmTimeline.end + 1;

  group('the order of the joke', () {
    test('enter, ring, admit, reveal, hand over, gone', () {
      expect(FalseAlarmTimeline.ringStart, greaterThan(0));
      expect(
        FalseAlarmTimeline.ringStart,
        lessThan(FalseAlarmTimeline.ringEnd),
      );
      expect(FalseAlarmTimeline.ringEnd, lessThan(FalseAlarmTimeline.admit));
      expect(FalseAlarmTimeline.admit, lessThan(FalseAlarmTimeline.reveal));
      expect(FalseAlarmTimeline.reveal, lessThan(FalseAlarmTimeline.handover));
      expect(FalseAlarmTimeline.handover, lessThan(FalseAlarmTimeline.end));
      // The red has opened past the mascot before the layout starts.
      expect(
        FalseAlarmTimeline.wipe(FalseAlarmTimeline.handover),
        greaterThan(0.5),
      );
      // An entrance and about a second and a half of joke, never a long
      // one.
      expect(FalseAlarmTimeline.ringStart, lessThanOrEqualTo(0.5));
      expect(FalseAlarmTimeline.end, lessThanOrEqualTo(2.4));
    });

    test('the intro is registered with the seconds of the timeline', () {
      expect(falseAlarmIntro.isSound, isTrue);
      expect(falseAlarmIntro.seconds, FalseAlarmTimeline.end);
      expect(falseAlarmIntro.handover, FalseAlarmTimeline.handover);
      expect(falseAlarmIntro.skipTo, FalseAlarmTimeline.reveal);
      for (final t in [0.0, 0.7, 1.1, 1.25, 1.6, 1.8, 2.1, 3.0]) {
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

    test('the first frame is bare: no red, no mascot, no word', () {
      expect(FalseAlarmTimeline.flood(0), 0);
      expect(FalseAlarmTimeline.arrive(0), 0);
      expect(FalseAlarmTimeline.wordIn(0), 0);
      expect(FalseAlarmTimeline.ringing(0), 0);
      expect(FalseAlarmTimeline.shake(0), 0);
      expect(FalseAlarmTimeline.ring(0, 0), isNull);
      expect(FalseAlarmTimeline.ring(1, 0), isNull);
      expect(FalseAlarmTimeline.wipe(0), 0);
      expect(FalseAlarmTimeline.leave(0), 0);
    });

    test('the red comes first, then the mascot, then the word', () {
      // The mascot pops up on red: where it stands is red before it shows.
      expect(FalseAlarmTimeline.flood(0.08), greaterThan(0.2));
      expect(FalseAlarmTimeline.arrive(0.08), 0);
      // The red has the whole screen before the mascot is all the way up.
      expect(FalseAlarmTimeline.flood(0.38), 1);
      expect(FalseAlarmTimeline.arrive(0.38), lessThan(1));
      expect(FalseAlarmTimeline.wordIn(0.26), 0);
      // Each part only comes in, never back out.
      var last = (flood: 0.0, arrive: 0.0, word: 0.0);
      for (var t = 0.0; t <= FalseAlarmTimeline.ringStart; t += 0.01) {
        final now = (
          flood: FalseAlarmTimeline.flood(t),
          arrive: FalseAlarmTimeline.arrive(t),
          word: FalseAlarmTimeline.wordIn(t),
        );
        expect(now.flood, greaterThanOrEqualTo(last.flood));
        expect(now.arrive, greaterThanOrEqualTo(last.arrive));
        expect(now.word, greaterThanOrEqualTo(last.word));
        last = now;
      }
    });

    test('the ringing starts on the whole alarm', () {
      const at = FalseAlarmTimeline.ringStart;
      expect(FalseAlarmTimeline.flood(at), 1);
      expect(FalseAlarmTimeline.arrive(at), 1);
      expect(FalseAlarmTimeline.wordIn(at), 1);
      expect(FalseAlarmTimeline.saysAlarm(at), isTrue);
      expect(FalseAlarmTimeline.face(at).from, FalseAlarmFace.alarmed);
      expect(FalseAlarmTimeline.face(at).blend, 0);
      expect(FalseAlarmTimeline.ring(0, at), 0);
      expect(FalseAlarmTimeline.ring(1, at), isNull);
      // Nothing rings during the entrance.
      for (var t = 0.0; t <= at; t += 0.01) {
        expect(FalseAlarmTimeline.ringing(t), 0);
        expect(FalseAlarmTimeline.shake(t), 0);
        expect(FalseAlarmTimeline.ring(0, t - 0.001), isNull);
      }
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
      expect(FalseAlarmTimeline.blink(FalseAlarmTimeline.ringStart + 0.5), 0);
      expect(
        FalseAlarmTimeline.blink(FalseAlarmTimeline.ringEnd + 0.06),
        greaterThan(0.8),
      );
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
      for (var t = 0.0; t < 3; t += 0.004) {
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
      expect(FalseAlarmTimeline.shake(FalseAlarmTimeline.ringStart), 0);
      expect(FalseAlarmTimeline.shake(FalseAlarmTimeline.ringEnd), 0);
      for (var t = FalseAlarmTimeline.ringEnd; t < 6; t += 0.05) {
        expect(FalseAlarmTimeline.shake(t), 0);
        expect(FalseAlarmTimeline.ringing(t), 0);
      }
    });

    test('no ring starts once the ringing has stopped', () {
      for (var t = FalseAlarmTimeline.reveal; t < 6; t += 0.05) {
        expect(FalseAlarmTimeline.ring(0, t), isNull);
        expect(FalseAlarmTimeline.ring(1, t), isNull);
      }
    });
  });

  group('the skip', () {
    test('a tap during the joke jumps to the reveal', () {
      expect(FalseAlarmTimeline.skip(0), FalseAlarmTimeline.reveal);
      expect(FalseAlarmTimeline.skip(0.2), FalseAlarmTimeline.reveal);
      expect(FalseAlarmTimeline.skip(0.7), FalseAlarmTimeline.reveal);
      expect(FalseAlarmTimeline.skip(1.6), FalseAlarmTimeline.reveal);
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
      // A tap during the entrance lands on the whole red too.
      expect(FalseAlarmTimeline.flood(at), 1);
      expect(FalseAlarmTimeline.arrive(at), 1);
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
