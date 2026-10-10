import 'package:critalarm/features/onboarding/domain/hero_haptic_cues.dart';
import 'package:critalarm/features/onboarding/domain/welcome_timing.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const schedule = <TimedCue>[
    (at: 1.0, cue: HeroCue.cardLands),
    (at: 1.5, cue: HeroCue.typeTick),
    (at: 1.54, cue: HeroCue.typeTick),
    (at: 1.58, cue: HeroCue.typeTick),
    (at: 2.0, cue: HeroCue.ringPulse),
  ];

  group('heroCuesBetween', () {
    test('plays a cue in the frame that passes it', () {
      expect(heroCuesBetween(schedule, 0.99, 1.006), [HeroCue.cardLands]);
    });

    test('plays nothing in a frame that passes no cue', () {
      expect(heroCuesBetween(schedule, 1.1, 1.116), isEmpty);
    });

    test('the end of the window counts and the start does not', () {
      expect(heroCuesBetween(schedule, 0.95, 1), [HeroCue.cardLands]);
      expect(heroCuesBetween(schedule, 1, 1.016), isEmpty);
    });

    test('plays nothing when the clock does not move forward', () {
      expect(heroCuesBetween(schedule, 1.2, 1.2), isEmpty);
      expect(heroCuesBetween(schedule, 1.2, 0.9), isEmpty);
    });

    test('a long dropped frame plays no burst of late cues', () {
      // The card and all three ticks are behind by more than the limit.
      expect(heroCuesBetween(schedule, 0.9, 1.9), isEmpty);
    });

    test('several of one kind in a frame play once', () {
      expect(heroCuesBetween(schedule, 1.49, 1.59), [HeroCue.typeTick]);
    });

    test('different kinds in one frame each play', () {
      const both = <TimedCue>[
        (at: 1.0, cue: HeroCue.cardLands),
        (at: 1.01, cue: HeroCue.ringPulse),
      ];
      expect(heroCuesBetween(both, 0.99, 1.02), [
        HeroCue.cardLands,
        HeroCue.ringPulse,
      ]);
    });
  });

  group('HeroCueClock', () {
    test('plays each cue once as the frames go by', () {
      final clock = HeroCueClock(schedule);
      final played = <HeroCue>[];
      for (var frame = 1; frame <= 150; frame++) {
        played.addAll(clock.advanceTo(frame / 60));
      }
      expect(played, [
        HeroCue.cardLands,
        HeroCue.typeTick,
        HeroCue.typeTick,
        HeroCue.typeTick,
        HeroCue.ringPulse,
      ]);
    });

    test('a hero that was hidden plays nothing it missed', () {
      final clock = HeroCueClock(schedule);
      expect(clock.advanceTo(0.5), isEmpty);
      // Hidden from 0.5 to 1.95, then back.
      expect(clock.advanceTo(1.95), isEmpty);
      expect(clock.advanceTo(2.01), [HeroCue.ringPulse]);
    });

    test('a tick that played late is not chased by the next one', () {
      final clock = HeroCueClock(schedule)..advanceTo(1.45);
      // A slow frame: the 1.5 tick plays at 1.535.
      expect(clock.advanceTo(1.535), [HeroCue.typeTick]);
      // The 1.54 tick is due 8 ms later, too soon after the last one.
      expect(clock.advanceTo(1.543), isEmpty);
      expect(clock.advanceTo(1.58), [HeroCue.typeTick]);
    });

    test('a story that does not loop plays once', () {
      final clock = HeroCueClock(ladderCues())..advanceTo(10);
      final played = <HeroCue>[];
      for (var frame = 1; frame <= 600; frame++) {
        played.addAll(clock.advanceTo(10 + frame / 60));
      }
      expect(played, isEmpty);
    });

    test('a story that loops plays the same cues on every pass', () {
      final clock = HeroCueClock(ladderCues(), loopsEvery: 10);
      List<HeroCue> pass(int number) => [
        for (var frame = 1; frame <= 600; frame++)
          ...clock.advanceTo(number * 10 + frame / 60),
      ];
      final first = pass(0);
      expect(first.where((cue) => cue == HeroCue.cardLands), hasLength(3));
      expect(
        first.where((cue) => cue == HeroCue.ringPulse),
        hasLength(ringPulseMax),
      );
      expect(pass(1), first);
      expect(pass(2), first);
    });

    test('a hero hidden across a loop plays nothing it missed', () {
      final clock = HeroCueClock(schedule, loopsEvery: 10)..advanceTo(0.5);
      // Hidden from 0.5 on the first pass to 1.95 on the second.
      expect(clock.advanceTo(11.95), isEmpty);
      expect(clock.advanceTo(12.01), [HeroCue.ringPulse]);
    });
  });

  group('typingCues', () {
    List<double> ticksOf(List<TimedCue> cues) => [
      for (final timed in cues)
        if (timed.cue == HeroCue.typeTick) timed.at,
    ];

    test('never ticks faster than 25 a second', () {
      for (final isAndroid in [false, true]) {
        for (final length in [1, 4, 30, 47, 133, 400]) {
          final ticks = ticksOf(
            typingCues(length: length, isAndroid: isAndroid),
          );
          for (var i = 1; i < ticks.length; i++) {
            expect(
              ticks[i] - ticks[i - 1],
              greaterThanOrEqualTo(typeTickMinGap - 1e-9),
              reason: 'length $length, android $isAndroid, tick $i',
            );
          }
        }
      }
    });

    test('a slow command ticks on every character but the last', () {
      // 30 characters in 1.9 s is about 16 a second, under the limit.
      final ticks = ticksOf(typingCues(length: 30, isAndroid: false));
      expect(ticks, hasLength(29));
      expect(ticks.first, closeTo(0.3 + 1.9 / 30, 1e-9));
    });

    test('Android ticks on every third character', () {
      final ticks = ticksOf(typingCues(length: 30, isAndroid: true));
      expect(ticks, hasLength(9));
      expect(ticks.first, closeTo(0.3 + 1.9 * 3 / 30, 1e-9));
      expect(ticks[1] - ticks[0], closeTo(1.9 * 3 / 30, 1e-9));
    });

    test('the send plays once, when the typing ends', () {
      final cues = typingCues(length: 133, isAndroid: false);
      final sends = cues.where((timed) => timed.cue == HeroCue.commandSent);
      expect(sends, hasLength(1));
      expect(cues.last.cue, HeroCue.commandSent);
      expect(
        cues.last.at,
        closeTo(terminalTypingStartsAt + terminalTypingTakes, 1e-9),
      );
    });

    test('no tick lands on top of the send', () {
      final cues = typingCues(length: 133, isAndroid: false);
      final ticks = ticksOf(cues);
      expect(
        cues.last.at - ticks.last,
        greaterThanOrEqualTo(typeTickMinGap - 1e-9),
      );
    });

    test('a terminal with its own timing ticks on that timing', () {
      final cues = typingCues(
        length: 130,
        isAndroid: false,
        startsAt: 0,
        takes: 2.6,
      );
      final ticks = ticksOf(cues);
      // 130 characters in 2.6 s is 50 a second, so every other one ticks.
      expect(ticks.first, closeTo(2.6 / 130, 1e-9));
      for (var i = 1; i < ticks.length; i++) {
        expect(
          ticks[i] - ticks[i - 1],
          greaterThanOrEqualTo(typeTickMinGap - 1e-9),
        );
      }
      expect(cues.last.cue, HeroCue.commandSent);
      expect(cues.last.at, closeTo(2.6, 1e-9));
    });

    test('an empty command plays nothing', () {
      expect(typingCues(length: 0, isAndroid: false), isEmpty);
    });
  });

  group('ringCues', () {
    test('pulses once every four shakes, from the first shake', () {
      final cues = ringCues(from: 2.5, to: 8.8);
      const gap = 4 * 2 * 3.141592653589793 / 50;
      expect(cues.first.at, 2.5);
      expect(cues[1].at - cues[0].at, closeTo(gap, 1e-9));
      expect(cues.every((timed) => timed.cue == HeroCue.ringPulse), isTrue);
    });

    test('a long ring pulses four times, all at its start', () {
      final cues = ringCues(from: 2.5, to: 8.8);
      const gap = 4 * 2 * 3.141592653589793 / 50;
      expect(cues, hasLength(ringPulseMax));
      expect(ringPulseMax, 4);
      expect(cues.last.at, closeTo(2.5 + 3 * gap, 1e-9));
    });

    test('every pulse lands on a whole number of shakes', () {
      const rate = 60.0;
      for (final timed in ringCues(from: 1.2, to: 6.6, shakeRate: rate)) {
        final shakes = (timed.at - 1.2) * rate / (2 * 3.141592653589793);
        expect(shakes, closeTo(shakes.roundToDouble(), 1e-9));
        expect(shakes.round() % ringPulseEveryShakes, 0);
      }
    });

    test('a ring shorter than four pulses stops when the ringing stops', () {
      final cues = ringCues(from: 2.5, to: 3.2);
      expect(cues, hasLength(2));
      expect(cues.last.at, lessThan(3.2));
    });

    test('a phone that never rings has no pulses', () {
      expect(ringCues(from: 3, to: 3), isEmpty);
    });
  });

  group('ladderCues', () {
    test('a card lands when it is fully shown', () {
      final lands = [
        for (final timed in ladderCues())
          if (timed.cue == HeroCue.cardLands) timed.at,
      ];
      expect(lands, [
        ladderCardShownAt(0),
        ladderCardShownAt(1),
        ladderCardShownAt(2),
      ]);
    });

    test('four pulses from the ring starting, none near the acknowledge', () {
      final pulses = [
        for (final timed in ladderCues())
          if (timed.cue == HeroCue.ringPulse) timed.at,
      ];
      expect(pulses, hasLength(4));
      expect(pulses.first, ladderRingStartsAt);
      expect(pulses.last, lessThan(ladderRingStartsAt + 1.3));
      expect(pulses.last, lessThan(ladderRingEndsAt));
    });
  });
}
