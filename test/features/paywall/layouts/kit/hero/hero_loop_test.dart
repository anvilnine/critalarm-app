import 'package:critalarm/features/paywall/domain/entities/paywall_preview_id.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/hero/hero_loop.dart';
import 'package:flutter_test/flutter_test.dart';

/// The five turns the loop was first written for. The untouched loop is
/// still tested against this table, second for second.
const List<PaywallPreviewId> _hosted = [
  PaywallPreviewId.topics,
  PaywallPreviewId.pushes,
  PaywallPreviewId.history,
  PaywallPreviewId.widgets,
  PaywallPreviewId.appIcons,
];

/// Clock second [since] seconds into the turn that starts [start] seconds
/// into the first pass.
double _at(double start, double since) => heroEntranceSeconds + start + since;

void main() {
  final loop = HeroLoop(_hosted);

  group('which benefit plays when', () {
    test('the five benefits take turns in a loop of 12 seconds', () {
      expect(loop.period, closeTo(12, 1e-9));
      expect(loop.scenes.map((s) => s.preview), _hosted);
      final starts = loop.scenes.map((s) => s.start).toList();
      expect(starts[0], 0);
      expect(starts[1], closeTo(2.4, 1e-9));
      expect(starts[2], closeTo(5.0, 1e-9));
      expect(starts[3], closeTo(7.4, 1e-9));
      expect(starts[4], closeTo(9.7, 1e-9));
    });

    test('the first benefit is on stage through the entrance', () {
      for (final t in [0.0, 0.3, 0.99]) {
        final frame = loop.frameAt(t);
        expect(frame.activeIndex, 0);
        expect(frame.entrance, closeTo(t / heroEntranceSeconds, 1e-9));
        expect(frame.previous, isNull);
        expect(frame.cardEnter, 1);
      }
    });

    test('each turn starts when the one before it ends', () {
      expect(loop.frameAt(_at(0, 0)).activeIndex, 0);
      expect(loop.frameAt(_at(2.4, -0.01)).activeIndex, 0);
      expect(loop.frameAt(_at(2.4, 0.01)).activeIndex, 1);
      expect(loop.frameAt(_at(5, 0.01)).activeIndex, 2);
      expect(loop.frameAt(_at(7.4, 0.01)).activeIndex, 3);
      expect(loop.frameAt(_at(9.7, 0.01)).activeIndex, 4);
    });

    test('after the last benefit the first plays again', () {
      final frame = loop.frameAt(_at(12, 0.1));
      expect(frame.activeIndex, 0);
      expect(frame.previous!.index, 4);
      expect(frame.sceneSeconds, closeTo(0.1, 1e-9));
    });

    test('a new preview comes in over the one before it', () {
      final early = loop.frameAt(_at(2.4, heroCardBlend / 2));
      expect(early.previous!.preview, PaywallPreviewId.topics);
      expect(early.cardEnter, closeTo(0.5, 1e-9));
      expect(loop.frameAt(_at(2.4, heroCardBlend + 0.01)).cardEnter, 1);
    });

    test('the first turn of all has nothing to come in over', () {
      final frame = loop.frameAt(_at(0, 0.05));
      expect(frame.previous, isNull);
      expect(frame.cardEnter, 1);
    });
  });

  group('the preview cue', () {
    test('a preview is cued so its own loop is `lead` seconds in when its '
        'turn starts', () {
      // Topics leads by 0.3 and starts the loop.
      expect(loop.frameAt(_at(0, 1)).playFrom, closeTo(1 - 0.3, 1e-9));
      // App icons leads by 2.3, so the swap to the crown falls in its turn.
      expect(
        loop.frameAt(_at(9.7, 1)).playFrom,
        closeTo(heroEntranceSeconds + 9.7 - 2.3, 1e-9),
      );
    });

    test('the cue moves on by one period on each pass', () {
      final first = loop.frameAt(_at(2.4, 1)).playFrom;
      final second = loop.frameAt(_at(12 + 2.4, 1)).playFrom;
      expect(second - first, closeTo(12, 1e-9));
    });

    test('the preview on its way out keeps the cue it had', () {
      final t = _at(2.4, 0.1);
      final frame = loop.frameAt(t);
      expect(
        frame.previousPlayFrom,
        closeTo(loop.frameAt(_at(0, 1)).playFrom, 1e-9),
      );

      // The last benefit of one pass hands over to the first of the next.
      final wrap = _at(12, 0.1);
      expect(
        loop.frameAt(wrap).previousPlayFrom,
        closeTo(loop.frameAt(_at(9.7, 1)).playFrom, 1e-9),
      );
    });
  });

  group('which face', () {
    test('the mascot lands startled and is glad before the first turn', () {
      final landing = loop.frameAt(0.3);
      expect(landing.fromFace, HeroFace.arriving);
      expect(landing.face, HeroFace.glad);
      expect(landing.faceBlend, 0);
      expect(loop.frameAt(0.9).faceBlend, 1);
    });

    test('topics: watching, doubtful at the refusal, glad when it goes on', () {
      expect(loop.frameAt(_at(0, 0.5)).face, HeroFace.watching);
      expect(loop.frameAt(_at(0, 1)).face, HeroFace.doubtful);
      final glad = loop.frameAt(_at(0, 2));
      expect(glad.face, HeroFace.glad);
      expect(glad.fromFace, HeroFace.doubtful);
      expect(glad.hop, greaterThan(0));
    });

    test('every turn ends on a pleased face, and each a different one', () {
      final last = [
        for (final scene in loop.scenes)
          loop.frameAt(_at(scene.start, scene.script.seconds - 0.05)).face,
      ];
      expect(last, [
        HeroFace.glad,
        HeroFace.winning,
        HeroFace.proud,
        HeroFace.winking,
        HeroFace.cool,
      ]);
    });

    test('a turn starts from the face the turn before ended on', () {
      final frame = loop.frameAt(_at(2.4, 0.05));
      expect(frame.fromFace, HeroFace.glad);
      expect(frame.face, HeroFace.watching);
      expect(frame.faceBlend, greaterThan(0));
      expect(frame.faceBlend, lessThan(1));
    });

    test('the hop is over well before the turn ends', () {
      final frame = loop.frameAt(_at(0, 1.85 + heroHopSeconds + 0.01));
      expect(frame.hop, 0);
    });

    test('it blinks for a moment every few seconds', () {
      expect(loop.frameAt(_at(0, 1)).blink, 0);
      const mid = heroBlinkEvery - heroBlinkSeconds / 2;
      expect(loop.frameAt(_at(0, mid)).blink, closeTo(1, 1e-9));
      expect(loop.frameAt(_at(0, heroBlinkEvery + 0.01)).blink, 0);
    });
  });

  group('what it wears', () {
    test('nothing, until the app icons play', () {
      for (final scene in loop.scenes.take(4)) {
        expect(loop.frameAt(_at(scene.start, 1.5)).props, isEmpty);
      }
    });

    test('the crown lands as the icon gets its crown, then the shades', () {
      expect(loop.frameAt(_at(9.7, 0.6)).props, isEmpty);

      final crowned = loop.frameAt(_at(9.7, 0.7 + heroPropBlend));
      expect(crowned.props[HeroProp.crown], 1);
      expect(crowned.props.containsKey(HeroProp.shades), isFalse);

      final both = loop.frameAt(_at(9.7, 1.2 + heroPropBlend));
      expect(both.props[HeroProp.crown], 1);
      expect(both.props[HeroProp.shades], 1);
    });

    test('both are off again when the turn ends', () {
      expect(loop.frameAt(_at(9.7, 2.3 - 0.001)).props.values, [
        closeTo(0, 0.01),
        closeTo(0, 0.01),
      ]);
      expect(loop.frameAt(_at(12, 0.01)).props, isEmpty);
    });
  });

  group('the resting frame', () {
    test('is the first benefit with the mascot glad, and nothing half way', () {
      final rest = loop.rest;
      expect(rest.activeIndex, 0);
      expect(rest.face, HeroFace.glad);
      expect(rest.faceBlend, 1);
      expect(rest.props, isEmpty);
      expect(rest.previous, isNull);
      expect(rest.cardEnter, 1);
      expect(rest.entrance, 1);
      expect(rest.hop, 0);
      expect(rest.blink, 0);
      expect(rest.bob, 0);
    });

    test('is what a still clock gets, whatever second it reads', () {
      for (final t in [0.0, 0.4, 6.0, 11.9, 40.0]) {
        final frame = loop.frameAt(t, isStill: true);
        expect(frame.activeIndex, 0);
        expect(frame.face, HeroFace.glad);
        expect(frame.props, isEmpty);
        expect(frame.entrance, 1);
        expect(frame.bob, 0);
      }
    });
  });

  group('a product with one benefit', () {
    final solo = HeroLoop(const [PaywallPreviewId.weeklyCheck]);

    test('its turn is the whole loop of the preview, so the picture never '
        'jumps', () {
      expect(solo.period, 9);
      expect(solo.frameAt(_at(0, 4)).playFrom, heroEntranceSeconds);
      expect(solo.frameAt(_at(9, 4)).playFrom, heroEntranceSeconds + 9);
    });

    test('nothing ever fades over it', () {
      for (final t in [0.5, 1.05, 5.0, 10.05, 19.1]) {
        final frame = solo.frameAt(t);
        expect(frame.previous, isNull);
        expect(frame.cardEnter, 1);
        expect(frame.activeIndex, 0);
      }
    });

    test('the mascot watches the push travel and wins when the week is '
        'ticked', () {
      expect(solo.frameAt(_at(0, 1)).face, HeroFace.watching);
      expect(solo.frameAt(_at(0, 2.5)).face, HeroFace.keen);
      final win = solo.frameAt(_at(0, 3.4));
      expect(win.face, HeroFace.winning);
      expect(win.hop, greaterThan(0));
      expect(solo.frameAt(_at(0, 8.5)).face, HeroFace.glad);
    });

    test('the next pass starts from the face the last one ended on', () {
      final frame = solo.frameAt(_at(9, 0.05));
      expect(frame.fromFace, HeroFace.glad);
      expect(frame.face, HeroFace.watching);
    });
  });

  group('other products', () {
    test('every preview has a turn of its own', () {
      for (final preview in PaywallPreviewId.values) {
        final script = heroScriptFor(preview, count: 5);
        expect(script.beats.first.at, 0, reason: preview.name);
        expect(script.beats.last.isReaction, isTrue, reason: preview.name);
        expect(
          script.beats.last.at + heroHopSeconds,
          lessThanOrEqualTo(script.seconds),
          reason: '${preview.name}: the hop ends inside the turn',
        );
      }
    });

    test('the weekly check among others takes a short turn, not its whole '
        'loop', () {
      final many = HeroLoop(const [
        PaywallPreviewId.weeklyCheck,
        PaywallPreviewId.widgets,
      ]);
      expect(many.scenes.first.script.seconds, closeTo(2.6, 1e-9));
    });

    test('a product with nothing to show draws the empty frame', () {
      final none = HeroLoop(const []);
      expect(none.period, 0);
      expect(none.frameAt(3).scene, isNull);
      expect(none.frameAt(3).activeIndex, 0);
      expect(none.touch(3), isNull);
    });
  });

  group('Hosted, as listed now', () {
    final hosted = HeroLoop(const [
      PaywallPreviewId.topics,
      PaywallPreviewId.pushes,
      PaywallPreviewId.history,
      PaywallPreviewId.appIcons,
    ]);

    test('four turns, each as long as before, in a loop of 9.7 seconds', () {
      expect(hosted.period, closeTo(9.7, 1e-9));
      expect(hosted.scenes.map((s) => s.script.seconds), [2.4, 2.6, 2.4, 2.3]);
      expect(
        hosted.frameAt(_at(7.4, 0.01)).scene!.preview,
        PaywallPreviewId.appIcons,
      );
    });

    test('its first three turns are the same frames as in the table', () {
      for (final t in [0.2, 1.0, 1.9, 2.5, 3.3, 4.6, 5.2, 6.4, 7.3]) {
        final now = hosted.frameAt(t);
        final then = loop.frameAt(t);
        expect(now.activeIndex, then.activeIndex, reason: '$t');
        expect(now.face, then.face, reason: '$t');
        expect(now.sceneSeconds, closeTo(then.sceneSeconds, 1e-9));
        expect(now.playFrom, closeTo(then.playFrom, 1e-9));
        expect(now.hop, closeTo(then.hop, 1e-9));
      }
    });
  });

  group('Pro', () {
    const previews = [
      PaywallPreviewId.wakeUpChallenges,
      PaywallPreviewId.widgets,
      PaywallPreviewId.weeklyCheck,
      PaywallPreviewId.customSounds,
      PaywallPreviewId.customAlarmScreens,
    ];
    final pro = HeroLoop(previews);
    double start(int i) => pro.scenes[i].start;

    test('five turns in a loop of 14.2 seconds', () {
      expect(pro.scenes.map((s) => s.preview), previews);
      expect(pro.scenes.map((s) => s.script.seconds), [3.1, 2.3, 2.6, 3.2, 3]);
      expect(pro.period, closeTo(14.2, 1e-9));
    });

    test('the challenge: startled, leaning in at the scan, relieved when '
        'the lock opens', () {
      expect(pro.frameAt(_at(0, 0.3)).face, HeroFace.startled);
      expect(pro.frameAt(_at(0, 1.2)).face, HeroFace.keen);
      final relief = pro.frameAt(_at(0, 2.5));
      expect(relief.face, HeroFace.relieved);
      expect(relief.hop, greaterThan(0));
    });

    test('the sound: headphones on to listen while it records, then it '
        'loves the result', () {
      final listening = pro.frameAt(_at(start(3), 1.5));
      expect(listening.face, HeroFace.listening);
      expect(listening.props[HeroProp.headphones], 1);
      final loving = pro.frameAt(_at(start(3), 2.6));
      expect(loving.face, HeroFace.loving);
      expect(loving.hop, greaterThan(0));
      expect(pro.frameAt(_at(start(3), 3.2 - 0.001)).props.values, [
        closeTo(0, 0.01),
      ]);
    });

    test('the screens: shades for the dark look, then a bow tie for the '
        'poster, never both', () {
      final dark = pro.frameAt(_at(start(4), 1.2));
      expect(dark.face, HeroFace.cool);
      expect(dark.props[HeroProp.shades], 1);
      expect(dark.props.containsKey(HeroProp.bowTie), isFalse);

      final poster = pro.frameAt(_at(start(4), 2.1 + heroPropBlend));
      expect(poster.face, HeroFace.proud);
      expect(poster.props[HeroProp.bowTie], 1);
      expect(poster.props.containsKey(HeroProp.shades), isFalse);
    });

    test('every turn ends on a pleased face, and each a different one', () {
      final last = [
        for (final scene in pro.scenes)
          pro.frameAt(_at(scene.start, scene.script.seconds - 0.05)).face,
      ];
      expect(last, [
        HeroFace.relieved,
        HeroFace.winking,
        HeroFace.winning,
        HeroFace.loving,
        HeroFace.proud,
      ]);
    });
  });
}
