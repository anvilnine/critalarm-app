import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/paywall/presentation/intros/countdown/countdown_intro.dart';
import 'package:critalarm/features/paywall/presentation/intros/countdown/countdown_timeline.dart';
import 'package:critalarm/features/paywall/presentation/intros/curtain/curtain_intro.dart';
import 'package:critalarm/features/paywall/presentation/intros/curtain/curtain_timeline.dart';
import 'package:critalarm/features/paywall/presentation/intros/snooze/snooze_intro.dart';
import 'package:critalarm/features/paywall/presentation/intros/snooze/snooze_timeline.dart';
import 'package:critalarm/features/paywall/presentation/intros/wake_up/wake_up_intro.dart';
import 'package:critalarm/features/paywall/presentation/intros/wake_up/wake_up_timeline.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_intro.dart';
import 'package:flutter_test/flutter_test.dart';

/// What every intro's timeline has in common, so one set of checks reads
/// all four.
typedef _Times = ({
  PaywallIntro intro,
  double reveal,
  double handover,
  double end,
  double Function(double) leave,
  double Function(double) words,
  bool Function(double) isOver,
});

void _keepsTheContract(String name, _Times times) {
  group('$name keeps the contract', () {
    test('it is registered with the seconds of its timeline', () {
      expect(times.intro.isSound, isTrue);
      expect(times.intro.seconds, times.end);
      expect(times.intro.handover, times.handover);
      expect(times.intro.skipTo, times.reveal);
      expect(times.end, inInclusiveRange(1.5, 2.5));
    });

    test('a tap skips to the reveal and does nothing after it', () {
      expect(paywallIntroSkip(times.intro, 0), times.reveal);
      expect(
        paywallIntroSkip(times.intro, times.reveal + 0.1),
        times.reveal + 0.1,
      );
    });

    test('the mascot is whole until the reveal and gone by the hand over', () {
      expect(times.leave(0), 0);
      expect(times.leave(times.reveal), 0);
      expect(times.leave(times.handover), 1);
      expect(times.leave(times.end + 1), 1);
    });

    test('no word of it lies over the layout as it comes in', () {
      expect(times.words(times.reveal), 1);
      expect(times.words(times.handover), 0);
    });

    test('nothing is drawn from the end on', () {
      expect(times.isOver(times.end - 0.01), isFalse);
      expect(times.isOver(times.end), isTrue);
      expect(times.isOver(times.end + 1), isTrue);
    });
  });
}

void main() {
  _keepsTheContract('the snooze snack', (
    intro: snoozeIntro,
    reveal: SnoozeTimeline.reveal,
    handover: SnoozeTimeline.handover,
    end: SnoozeTimeline.end,
    leave: SnoozeTimeline.leave,
    words: SnoozeTimeline.words,
    isOver: SnoozeTimeline.isOver,
  ));
  _keepsTheContract('the rude awakening', (
    intro: wakeUpIntro,
    reveal: WakeUpTimeline.reveal,
    handover: WakeUpTimeline.handover,
    end: WakeUpTimeline.end,
    leave: WakeUpTimeline.leave,
    words: WakeUpTimeline.words,
    isOver: WakeUpTimeline.isOver,
  ));
  _keepsTheContract('the curtain call', (
    intro: curtainIntro,
    reveal: CurtainTimeline.reveal,
    handover: CurtainTimeline.handover,
    end: CurtainTimeline.end,
    leave: CurtainTimeline.leave,
    words: CurtainTimeline.words,
    isOver: CurtainTimeline.isOver,
  ));
  _keepsTheContract('the countdown', (
    intro: countdownIntro,
    reveal: CountdownTimeline.reveal,
    handover: CountdownTimeline.handover,
    end: CountdownTimeline.end,
    leave: CountdownTimeline.leave,
    words: CountdownTimeline.words,
    isOver: CountdownTimeline.isOver,
  ));

  group('the snooze snack', () {
    test('dodge left, dodge right, jump, gulp, reveal', () {
      expect(SnoozeTimeline.dodgeLeft, lessThan(SnoozeTimeline.dodgeRight));
      expect(SnoozeTimeline.dodgeRight, lessThan(SnoozeTimeline.jump));
      expect(SnoozeTimeline.jump, lessThan(SnoozeTimeline.gulp));
      expect(SnoozeTimeline.gulp, lessThan(SnoozeTimeline.reveal));
    });

    test('the first frame is a drowsy mascot over a button at home', () {
      expect(SnoozeTimeline.buttonSide(0), 0);
      expect(SnoozeTimeline.buttonHop(0), 0);
      expect(SnoozeTimeline.swallowed(0), 0);
      expect(SnoozeTimeline.face(0).from, FaceState.sleepy);
      expect(SnoozeTimeline.fingerPresence(0), 1);
      expect(SnoozeTimeline.finger(0).below, greaterThan(1));
    });

    test('the finger always gets to where the button just was', () {
      expect(
        SnoozeTimeline.finger(SnoozeTimeline.dodgeLeft).side,
        closeTo(0, 1e-9),
      );
      expect(
        SnoozeTimeline.finger(SnoozeTimeline.dodgeLeft).below,
        closeTo(0, 1e-9),
      );
      expect(
        SnoozeTimeline.finger(SnoozeTimeline.dodgeRight).side,
        closeTo(-1, 1e-9),
      );
      expect(SnoozeTimeline.finger(SnoozeTimeline.jump).side, closeTo(1, 1e-9));
      // And the button is there when it does, then leaves.
      expect(
        SnoozeTimeline.buttonSide(SnoozeTimeline.dodgeRight),
        closeTo(-1, 1e-9),
      );
      expect(SnoozeTimeline.buttonSide(SnoozeTimeline.jump), closeTo(1, 1e-9));
    });

    test('the button is eaten and the finger gives up', () {
      expect(SnoozeTimeline.swallowed(SnoozeTimeline.gulp), 1);
      expect(SnoozeTimeline.buttonSide(SnoozeTimeline.gulp), 0);
      expect(
        SnoozeTimeline.face(SnoozeTimeline.gulp - 0.01).to,
        FaceState.yawn,
      );
      expect(
        SnoozeTimeline.face(SnoozeTimeline.gulp + 0.2).to,
        FaceState.cheeky,
      );
      expect(SnoozeTimeline.fingerPresence(SnoozeTimeline.reveal), 0);
      expect(SnoozeTimeline.swell(SnoozeTimeline.reveal), closeTo(0, 1e-9));
      expect(SnoozeTimeline.line(SnoozeTimeline.gulp), 0);
      expect(SnoozeTimeline.line(SnoozeTimeline.reveal), closeTo(1, 1e-9));
    });
  });

  group('the rude awakening', () {
    test('drop, bonk, up, reveal', () {
      expect(WakeUpTimeline.drop, lessThan(WakeUpTimeline.bonk));
      expect(WakeUpTimeline.bonk, lessThan(WakeUpTimeline.up));
      expect(WakeUpTimeline.up, lessThan(WakeUpTimeline.reveal));
    });

    test('the first frame is the mascot asleep in a whole night', () {
      expect(WakeUpTimeline.face(0).from, FaceState.dozing);
      expect(WakeUpTimeline.face(0).blend, 0);
      expect(WakeUpTimeline.wipe(0), 0);
      expect(WakeUpTimeline.fall(0), 0);
      expect(WakeUpTimeline.line(0), 0);
    });

    test('the hit wakes it, and it ends upright and level', () {
      expect(WakeUpTimeline.fall(WakeUpTimeline.bonk), 1);
      expect(
        WakeUpTimeline.face(WakeUpTimeline.bonk + 0.07).to,
        FaceState.shocked,
      );
      expect(WakeUpTimeline.face(WakeUpTimeline.bonk + 0.07).blend, 1);
      expect(WakeUpTimeline.jolt(WakeUpTimeline.bonk + 0.15), closeTo(1, 1e-9));
      expect(WakeUpTimeline.rock(WakeUpTimeline.bonk), 0);
      expect(WakeUpTimeline.rock(WakeUpTimeline.reveal), 0);
      expect(WakeUpTimeline.jolt(WakeUpTimeline.reveal), closeTo(0, 1e-9));
      expect(WakeUpTimeline.breath(WakeUpTimeline.reveal), 0);
      expect(WakeUpTimeline.bounce(WakeUpTimeline.reveal), 1);
      for (var t = 0.0; t < WakeUpTimeline.end; t += 0.01) {
        expect(
          WakeUpTimeline.rock(t).abs(),
          lessThanOrEqualTo(WakeUpTimeline.rockReach),
        );
      }
    });

    test('the night is all rolled up at the end', () {
      expect(WakeUpTimeline.wipe(WakeUpTimeline.reveal), 0);
      expect(WakeUpTimeline.wipe(WakeUpTimeline.end), 1);
    });
  });

  group('the curtain call', () {
    test('peek, look left, look right, spot, reveal', () {
      expect(CurtainTimeline.peek, lessThan(CurtainTimeline.lookLeft));
      expect(CurtainTimeline.lookLeft, lessThan(CurtainTimeline.lookRight));
      expect(CurtainTimeline.lookRight, lessThan(CurtainTimeline.spot));
      expect(CurtainTimeline.spot, lessThan(CurtainTimeline.reveal));
    });

    test('the first frame is a closed curtain', () {
      expect(CurtainTimeline.gap(0), 0);
      expect(CurtainTimeline.rustle(0), 0);
      expect(CurtainTimeline.isBehind(0), isTrue);
      expect(CurtainTimeline.line(0), 0);
    });

    test('it peeks through a narrow gap, then is out in front', () {
      expect(
        CurtainTimeline.gap(CurtainTimeline.spot),
        closeTo(CurtainTimeline.peekGap, 1e-9),
      );
      expect(CurtainTimeline.rustle(CurtainTimeline.peek), 0);
      expect(
        CurtainTimeline.face(CurtainTimeline.lookRight - 0.01).to,
        FaceState.lookLeft,
      );
      expect(
        CurtainTimeline.face(CurtainTimeline.spot - 0.01).to,
        FaceState.lookRight,
      );
      expect(
        CurtainTimeline.face(CurtainTimeline.spot + 0.1).to,
        FaceState.realization,
      );
      expect(CurtainTimeline.isBehind(CurtainTimeline.spot), isFalse);
      expect(CurtainTimeline.pokeOut(CurtainTimeline.reveal), 1);
      // The layout is not seen through the gap before the curtain opens.
      expect(CurtainTimeline.backstage(CurtainTimeline.reveal), 1);
      expect(CurtainTimeline.backstage(CurtainTimeline.handover), 0);
    });

    test('both halves are off the screen at the end', () {
      expect(CurtainTimeline.gap(CurtainTimeline.end), greaterThan(1));
      var last = 0.0;
      for (var t = 0.0; t <= CurtainTimeline.end; t += 0.01) {
        expect(CurtainTimeline.gap(t), greaterThanOrEqualTo(last - 1e-9));
        last = CurtainTimeline.gap(t);
      }
    });
  });

  group('the countdown', () {
    test('three, two, one, squash, reveal', () {
      expect(CountdownTimeline.number(0), 3);
      expect(CountdownTimeline.number(CountdownTimeline.two), 2);
      expect(CountdownTimeline.number(CountdownTimeline.one), 1);
      expect(CountdownTimeline.one, lessThan(CountdownTimeline.squash));
      expect(CountdownTimeline.squash, lessThan(CountdownTimeline.reveal));
      // The one never gets its whole turn.
      expect(
        CountdownTimeline.squash - CountdownTimeline.one,
        lessThan(CountdownTimeline.count),
      );
    });

    test('the first frame is a three with the hand at the top', () {
      expect(CountdownTimeline.sweep(0), 0);
      expect(CountdownTimeline.fall(0), 0);
      expect(CountdownTimeline.flat(0), 0);
      expect(CountdownTimeline.burst(0), 0);
      expect(CountdownTimeline.wipe(0), 0);
    });

    test('the hand goes round for each number and stops at the landing', () {
      expect(
        CountdownTimeline.sweep(CountdownTimeline.two - 0.01),
        greaterThan(0.9),
      );
      expect(CountdownTimeline.sweep(CountdownTimeline.two), closeTo(0, 1e-9));
      expect(
        CountdownTimeline.sweep(CountdownTimeline.reveal),
        CountdownTimeline.sweep(CountdownTimeline.squash),
      );
      expect(CountdownTimeline.sweep(CountdownTimeline.squash), lessThan(0.5));
    });

    test('the mascot lands, the one goes flat and is gone', () {
      expect(CountdownTimeline.fall(CountdownTimeline.one), 0);
      expect(CountdownTimeline.fall(CountdownTimeline.squash), 1);
      expect(CountdownTimeline.flat(CountdownTimeline.squash + 0.05), 1);
      expect(CountdownTimeline.number(CountdownTimeline.squash + 0.1), 0);
      expect(
        CountdownTimeline.squat(CountdownTimeline.reveal),
        closeTo(0, 1e-9),
      );
      expect(CountdownTimeline.burst(CountdownTimeline.reveal), 1);
      expect(
        CountdownTimeline.face(CountdownTimeline.reveal - 0.01).to,
        FaceState.cheeky,
      );
      expect(CountdownTimeline.wipe(CountdownTimeline.end), 1);
    });
  });
}
