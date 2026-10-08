import 'package:critalarm/core/ui_sound/paywall_cues.dart';
import 'package:critalarm/design_system/haptics.dart';
import 'package:critalarm/features/paywall/presentation/intros/countdown/countdown_intro.dart';
import 'package:critalarm/features/paywall/presentation/intros/countdown/countdown_timeline.dart';
import 'package:critalarm/features/paywall/presentation/intros/curtain/curtain_intro.dart';
import 'package:critalarm/features/paywall/presentation/intros/curtain/curtain_timeline.dart';
import 'package:critalarm/features/paywall/presentation/intros/false_alarm/false_alarm_intro.dart';
import 'package:critalarm/features/paywall/presentation/intros/false_alarm/false_alarm_timeline.dart';
import 'package:critalarm/features/paywall/presentation/intros/snooze/snooze_intro.dart';
import 'package:critalarm/features/paywall/presentation/intros/snooze/snooze_timeline.dart';
import 'package:critalarm/features/paywall/presentation/intros/wake_up/wake_up_intro.dart';
import 'package:critalarm/features/paywall/presentation/intros/wake_up/wake_up_timeline.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_cue_rules.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_intro.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_intro_registry.dart';
import 'package:flutter_test/flutter_test.dart';

/// Records what is played.
class _Heard extends PaywallCues {
  final List<PaywallCue> cues = [];

  @override
  void play(PaywallCue cue) => cues.add(cue);
}

List<(double, HapticPattern)> _felt(PaywallIntro intro) => [
  for (final beat in intro.beats) (beat.at, beat.haptic),
];

/// Each intro with its score and the second its joke gives way.
const List<(PaywallIntro, PaywallCue, double)> _scored = [
  (falseAlarmIntro, PaywallCue.scoreFalseAlarm, FalseAlarmTimeline.reveal),
  (snoozeIntro, PaywallCue.scoreSnooze, SnoozeTimeline.reveal),
  (wakeUpIntro, PaywallCue.scoreWakeUp, WakeUpTimeline.reveal),
  (curtainIntro, PaywallCue.scoreCurtain, CurtainTimeline.reveal),
  (countdownIntro, PaywallCue.scoreCountdown, CountdownTimeline.reveal),
];

void main() {
  group('the scores', () {
    test('every intro opens on a score of its own and no other cue', () {
      for (final (intro, score, _) in _scored) {
        expect(intro.score, score);
        expect(intro.cue, PaywallEntranceCue.none);
      }
      expect(_scored.map((row) => row.$2).toSet(), hasLength(_scored.length));
      expect(
        paywallIntroBuilders.values.toSet(),
        _scored.map((row) => row.$1).toSet(),
      );
    });

    test('the score has the player alone: every beat is a haptic', () {
      for (final (intro, _, _) in _scored) {
        for (final beat in intro.beats) {
          expect(beat.cue, isNull);
          expect(beat.haptic, isNot(HapticPattern.none));
        }
      }
    });

    test('a tap to skip plays the arrival alone, from the reveal', () {
      for (final (intro, _, reveal) in _scored) {
        expect(intro.skipCue, PaywallCue.introArrive);
        expect(intro.skipTo, reveal);
      }
    });

    test('the layout keeps quiet until the arrival has rung out', () {
      // Played through or skipped, the arrival starts at the reveal.
      for (final (intro, _, reveal) in _scored) {
        expect(
          intro.handover + intro.quietAfter,
          closeTo(reveal + paywallIntroArrivalSeconds, 1e-9),
        );
        expect(intro.quietAfter, greaterThan(paywallQuietAfterIntro));
        expect(intro.quietAfter, lessThanOrEqualTo(1.0 + 1e-9));
      }
    });

    test('a score is not the sound of a purchase, a failure or a goodbye', () {
      for (final cue in [
        for (final (_, score, _) in _scored) score,
        PaywallCue.introArrive,
      ]) {
        for (final other in [
          PaywallCue.bought,
          PaywallCue.error,
          PaywallCue.close,
          PaywallCue.open,
        ]) {
          expect(cue.sound, isNot(other.sound), reason: cue.name);
        }
        expect(cue.haptic, isNot(PaywallCue.bought.haptic), reason: cue.name);
        expect(cue.haptic, isNot(HapticPattern.fallingPair), reason: cue.name);
        expect(cue.haptic, isNot(HapticPattern.doubleKnock), reason: cue.name);
      }
    });
  });

  group('what the hand feels', () {
    test('the false alarm: nothing while it rings, then the reveal', () {
      expect(_felt(falseAlarmIntro), [
        (FalseAlarmTimeline.reveal, HapticPattern.tripleRise),
      ]);
      expect(
        falseAlarmIntro.beats.single.at,
        greaterThanOrEqualTo(FalseAlarmTimeline.ringEnd),
      );
    });

    test('snooze: each hop, the gulp, the reveal', () {
      expect(_felt(snoozeIntro), [
        (SnoozeTimeline.dodgeLeft, HapticPattern.tripleFade),
        (SnoozeTimeline.dodgeRight, HapticPattern.tripleFade),
        (SnoozeTimeline.gulp, HapticPattern.medium),
        (SnoozeTimeline.reveal, HapticPattern.light),
      ]);
    });

    test('wake up: a knock as the message lands, then the start', () {
      expect(_felt(wakeUpIntro), [
        (WakeUpTimeline.bonk, HapticPattern.doubleKnock),
        (WakeUpTimeline.reveal, HapticPattern.risingPair),
      ]);
    });

    test('curtain: a tap as it sees you, and one as it opens', () {
      expect(_felt(curtainIntro), [
        (CurtainTimeline.spot, HapticPattern.light),
        (CurtainTimeline.reveal, HapticPattern.light),
      ]);
    });

    test('countdown: a tick for each count, the landing, the reveal', () {
      expect(_felt(countdownIntro), [
        (0.0, HapticPattern.tick),
        (CountdownTimeline.two, HapticPattern.tick),
        (CountdownTimeline.squash, HapticPattern.tripleFade),
        (CountdownTimeline.reveal, HapticPattern.light),
      ]);
    });
  });

  group('every intro', () {
    test('plays a beat through the cue player, once', () {
      const beat = PaywallIntroBeat(0.5, PaywallCue.pop);
      final heard = _Heard();
      beat.play(heard);
      expect(heard.cues, [PaywallCue.pop]);
    });

    test('has no beat that repeats fast: nothing rings or buzzes', () {
      for (final MapEntry(key: id, value: intro)
          in paywallIntroBuilders.entries) {
        for (var i = 1; i < intro.beats.length; i++) {
          expect(
            intro.beats[i].at - intro.beats[i - 1].at,
            greaterThanOrEqualTo(0.2),
            reason: id.key,
          );
        }
        // The reveal is a beat, so the hand over is felt.
        expect(intro.beats.last.at, intro.skipTo, reason: id.key);
      }
    });
  });
}
