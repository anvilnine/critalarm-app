import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/paywall/presentation/intros/alarm_snack/alarm_snack_intro.dart';
import 'package:critalarm/features/paywall/presentation/intros/alarm_snack/alarm_snack_timeline.dart';
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
  _keepsTheContract('the alarm snack', (
    intro: alarmSnackIntro,
    reveal: AlarmSnackTimeline.reveal,
    handover: AlarmSnackTimeline.handover,
    end: AlarmSnackTimeline.end,
    leave: AlarmSnackTimeline.leave,
    words: AlarmSnackTimeline.words,
    isOver: AlarmSnackTimeline.isOver,
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

  group('the alarm snack', () {
    const tl = AlarmSnackTimeline.end + 1;

    test('dodge left, dodge right, jump, gulp, reveal, hand over', () {
      expect(
        AlarmSnackTimeline.dodgeLeft,
        lessThan(AlarmSnackTimeline.dodgeRight),
      );
      expect(AlarmSnackTimeline.dodgeRight, lessThan(AlarmSnackTimeline.jump));
      expect(AlarmSnackTimeline.jump, lessThan(AlarmSnackTimeline.gulp));
      expect(AlarmSnackTimeline.gulp, lessThan(AlarmSnackTimeline.reveal));
      expect(AlarmSnackTimeline.reveal, lessThan(AlarmSnackTimeline.handover));
      // One joke, not two end to end: it hands over sooner than the two
      // it is made of would together.
      expect(AlarmSnackTimeline.handover, lessThan(2.6));
      // The red has opened past the mascot before the layout starts.
      expect(
        AlarmSnackTimeline.wipe(AlarmSnackTimeline.handover),
        greaterThan(0.5),
      );
      expect(AlarmSnackTimeline.wipe(AlarmSnackTimeline.end), 1);
    });

    test('the first frame is the whole alarm with its button at home', () {
      expect(AlarmSnackTimeline.wipe(0), 0);
      expect(AlarmSnackTimeline.leave(0), 0);
      expect(AlarmSnackTimeline.saysAlarm(0), isTrue);
      expect(AlarmSnackTimeline.face(0).from, FaceState.alarmed);
      expect(AlarmSnackTimeline.face(0).blend, 0);
      expect(AlarmSnackTimeline.pulse(0, 0), 0);
      expect(AlarmSnackTimeline.pulse(1, 0), isNull);
      expect(AlarmSnackTimeline.buttonSide(0), 0);
      expect(AlarmSnackTimeline.buttonHop(0), 0);
      expect(AlarmSnackTimeline.swallowed(0), 0);
      expect(AlarmSnackTimeline.fingerPresence(0), 1);
      expect(AlarmSnackTimeline.finger(0).below, greaterThan(1));
    });

    test('it rings three times and the button hops as a new ring starts', () {
      expect(
        3 * AlarmSnackTimeline.ringPeriod,
        closeTo(AlarmSnackTimeline.gulp, 1e-9),
      );
      expect(AlarmSnackTimeline.dodgeLeft, AlarmSnackTimeline.ringPeriod);
      expect(
        AlarmSnackTimeline.dodgeRight,
        closeTo(2 * AlarmSnackTimeline.ringPeriod, 1e-9),
      );
      for (final ring in [0, 1, 2]) {
        final middle = (ring + 0.5) * AlarmSnackTimeline.ringPeriod;
        expect(AlarmSnackTimeline.ringing(middle), closeTo(1, 1e-6));
      }
    });

    test('the lean stays inside five degrees', () {
      for (var t = 0.0; t <= AlarmSnackTimeline.end; t += 0.004) {
        expect(
          AlarmSnackTimeline.shake(t).abs(),
          lessThanOrEqualTo(AlarmSnackTimeline.shakeReach + 1e-9),
        );
      }
    });

    test('the gulp stops the ringing dead: no lean, no ring, no word', () {
      for (final t in [
        AlarmSnackTimeline.gulp,
        AlarmSnackTimeline.gulp + 0.01,
        AlarmSnackTimeline.reveal,
        AlarmSnackTimeline.handover,
        tl,
      ]) {
        expect(AlarmSnackTimeline.ringing(t), 0, reason: '$t');
        expect(AlarmSnackTimeline.shake(t), 0, reason: '$t');
        expect(AlarmSnackTimeline.pulse(0, t), isNull, reason: '$t');
        expect(AlarmSnackTimeline.pulse(1, t), isNull, reason: '$t');
        expect(AlarmSnackTimeline.saysAlarm(t), isFalse, reason: '$t');
      }
      expect(
        AlarmSnackTimeline.saysAlarm(AlarmSnackTimeline.gulp - 0.01),
        isTrue,
      );
    });

    test('the finger always gets to where the button just was', () {
      final first = AlarmSnackTimeline.finger(AlarmSnackTimeline.dodgeLeft);
      expect(first.side, closeTo(0, 1e-9));
      expect(first.below, closeTo(0, 1e-9));
      expect(
        AlarmSnackTimeline.finger(AlarmSnackTimeline.dodgeRight).side,
        closeTo(-1, 1e-9),
      );
      expect(
        AlarmSnackTimeline.finger(AlarmSnackTimeline.jump).side,
        closeTo(1, 1e-9),
      );
      // And the button is there when it does, then leaves.
      expect(
        AlarmSnackTimeline.buttonSide(AlarmSnackTimeline.dodgeRight),
        closeTo(-1, 1e-9),
      );
      expect(
        AlarmSnackTimeline.buttonSide(AlarmSnackTimeline.jump),
        closeTo(1, 1e-9),
      );
      expect(
        AlarmSnackTimeline.buttonHop(AlarmSnackTimeline.dodgeRight),
        closeTo(0, 1e-9),
      );
      expect(
        AlarmSnackTimeline.buttonHop(AlarmSnackTimeline.jump),
        closeTo(0, 1e-9),
      );
    });

    test('the button is eaten, the finger gives up, the line is said', () {
      expect(AlarmSnackTimeline.swallowed(AlarmSnackTimeline.jump), 0);
      expect(AlarmSnackTimeline.swallowed(AlarmSnackTimeline.gulp), 1);
      expect(AlarmSnackTimeline.buttonScale(AlarmSnackTimeline.jump), 1);
      expect(AlarmSnackTimeline.buttonScale(AlarmSnackTimeline.gulp), 0);
      expect(
        AlarmSnackTimeline.buttonSide(AlarmSnackTimeline.gulp),
        closeTo(0, 1e-9),
      );
      expect(AlarmSnackTimeline.fingerPresence(AlarmSnackTimeline.reveal), 0);
      expect(AlarmSnackTimeline.line(AlarmSnackTimeline.gulp), 0);
      expect(AlarmSnackTimeline.line(AlarmSnackTimeline.reveal), 1);
      expect(
        AlarmSnackTimeline.swell(AlarmSnackTimeline.gulp),
        closeTo(0, 1e-9),
      );
      expect(
        AlarmSnackTimeline.swell(AlarmSnackTimeline.reveal),
        closeTo(0, 1e-9),
      );
    });

    test('the face goes alarmed, wide for the button, cheeky, glad', () {
      expect(
        AlarmSnackTimeline.face(AlarmSnackTimeline.gulp - 0.01).to,
        FaceState.yawn,
      );
      final grin = AlarmSnackTimeline.face(AlarmSnackTimeline.reveal - 0.01);
      expect(grin.to, FaceState.cheeky);
      expect(grin.blend, 1);
      final glad = AlarmSnackTimeline.face(tl);
      expect(glad.to, FaceState.happy);
      expect(glad.blend, 1);
    });
  });
}
