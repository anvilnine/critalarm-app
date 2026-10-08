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

List<(double, PaywallCue?)> _table(PaywallIntro intro) => [
  for (final beat in intro.beats) (beat.at, beat.cue),
];

void main() {
  group('the false alarm', () {
    test('opens on the gag, which has no haptic', () {
      expect(falseAlarmIntro.cue, PaywallEntranceCue.gag);
      expect(PaywallCue.gag.haptic, HapticPattern.none);
    });

    test('plays no sound of its own and nothing while it rings', () {
      for (final beat in falseAlarmIntro.beats) {
        expect(beat.cue, isNull);
        expect(beat.at, greaterThanOrEqualTo(FalseAlarmTimeline.ringEnd));
      }
    });

    test('one light haptic alone marks the reveal', () {
      final beat = falseAlarmIntro.beats.single;
      expect(beat.at, FalseAlarmTimeline.reveal);
      expect(beat.haptic, HapticPattern.light);
      expect(beat.cue, isNull);
    });

    test('a tap to skip plays the release', () {
      expect(falseAlarmIntro.skipCue, PaywallCue.kidding);
      expect(falseAlarmIntro.skipTo, FalseAlarmTimeline.reveal);
    });

    test('keeps the layout quiet until the gag has sounded out', () {
      expect(
        falseAlarmIntro.handover + falseAlarmIntro.quietAfter,
        closeTo(FalseAlarmTimeline.gagEnds, 1e-9),
      );
      expect(falseAlarmIntro.quietAfter, greaterThan(paywallQuietAfterIntro));
    });
  });

  group('the other intros', () {
    test('snooze: a bounce for each dodge, a pop, then the release', () {
      expect(_table(snoozeIntro), [
        (SnoozeTimeline.dodgeLeft, PaywallCue.introBounce),
        (SnoozeTimeline.dodgeRight, PaywallCue.introBounce),
        (SnoozeTimeline.gulp, PaywallCue.pop),
        (SnoozeTimeline.reveal, PaywallCue.kidding),
      ]);
    });

    test('wake up: a knock at the bonk, then the release', () {
      expect(_table(wakeUpIntro), [
        (WakeUpTimeline.bonk, PaywallCue.introKnock),
        (WakeUpTimeline.reveal, PaywallCue.kidding),
      ]);
    });

    test('curtain: a swish, a pop as it sees you, a swish to open', () {
      expect(_table(curtainIntro), [
        (CurtainTimeline.peek, PaywallCue.introSwish),
        (CurtainTimeline.spot, PaywallCue.pop),
        (CurtainTimeline.reveal, PaywallCue.introSwish),
      ]);
    });

    test('countdown: a tick for each count, a drop, then the release', () {
      expect(_table(countdownIntro), [
        (0.0, PaywallCue.tick),
        (CountdownTimeline.two, PaywallCue.tick),
        (CountdownTimeline.squash, PaywallCue.drop),
        (CountdownTimeline.reveal, PaywallCue.kidding),
      ]);
    });

    test('each opens with no cue: its beats are the sound', () {
      for (final intro in [
        snoozeIntro,
        wakeUpIntro,
        curtainIntro,
        countdownIntro,
      ]) {
        expect(intro.cue, PaywallEntranceCue.none);
        expect(intro.skipCue, isNull);
        expect(intro.quietAfter, paywallQuietAfterIntro);
      }
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
