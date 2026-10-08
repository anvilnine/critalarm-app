import 'package:critalarm/core/ui_sound/paywall_cues.dart';
import 'package:critalarm/features/paywall/domain/entities/paywall_preview_id.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/hero/hero_loop.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/hero/hero_motion.dart';
import 'package:critalarm/features/paywall/presentation/layouts/sheet/sheet_motion.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final loop = HeroLoop(const [
    PaywallPreviewId.topics,
    PaywallPreviewId.pushes,
    PaywallPreviewId.history,
  ], prelude: SheetMotion.prelude);
  final lead = loop.scenes.first.script;

  group('the entrance', () {
    test('the sheet starts below the screen and ends in its seat', () {
      expect(SheetMotion.rise(0), 0);
      expect(SheetMotion.rise(SheetMotion.restAt), closeTo(1, 0.001));
      expect(SheetMotion.scrim(0), 0);
      expect(SheetMotion.scrim(SheetMotion.restAt), 1);
    });

    test('the sheet has landed before the approved entrance starts', () {
      expect(SheetMotion.rise(SheetMotion.prelude), greaterThan(0.8));
      expect(SheetMotion.buyBlockAt, lessThan(SheetMotion.prelude));
    });

    test('it rests where the loop starts', () {
      expect(SheetMotion.restAt, loop.entranceEnd);
    });
  });

  group('the lit row', () {
    test('answers at the beat where the feature has done its job', () {
      expect(SheetMotion.proofAt(lead), 1.85);
    });

    test('a script with no such beat answers most of the way through', () {
      const script = HeroScript(
        seconds: 2,
        beats: [HeroBeat(0, HeroFace.watching)],
      );
      expect(SheetMotion.proofAt(script), closeTo(1.4, 0.001));
    });

    test('shows the limit through the entrance and the start of the turn', () {
      for (final t in [0.0, 0.5, 1.0, loop.entranceEnd, loop.entranceEnd + 1]) {
        expect(SheetMotion.proofFor(loop, loop.frameAt(t)), 0, reason: '$t');
      }
    });

    test('has answered by the end of the lead turn and stays answered', () {
      final end = loop.entranceEnd + lead.seconds;
      expect(SheetMotion.proofFor(loop, loop.frameAt(end - 0.05)), 1);
      // Through every other benefit's turn.
      for (var t = end; t < loop.entranceEnd + loop.period; t += 0.25) {
        expect(SheetMotion.proofFor(loop, loop.frameAt(t)), 1, reason: '$t');
      }
    });

    test('shows the limit again when the lead comes round', () {
      final again = loop.entranceEnd + loop.period + 0.1;
      expect(SheetMotion.proofFor(loop, loop.frameAt(again)), 0);
    });

    test('a line the hand picks leaves it answered', () {
      final t = loop.entranceEnd + 0.2;
      final hand = loop.touch(t, index: 2);
      expect(
        SheetMotion.proofFor(loop, loop.frameAt(t + 0.1, hand: hand)),
        1,
      );
    });

    test('is the limit, always, when nothing may move', () {
      expect(
        SheetMotion.proofFor(loop, loop.rest, isStill: true),
        0,
      );
      expect(
        SheetMotion.proofFor(loop, loop.restFor(2), isStill: true),
        0,
      );
    });

    test('a product with nothing to show has nothing to answer', () {
      final empty = HeroLoop(const []);
      expect(SheetMotion.proofFor(empty, HeroFrame.empty), 0);
    });
  });

  group('the motion of the sheet', () {
    test('the stage picks its own variants', () {
      expect(SheetMotion.stage.atmosphere, HeroAtmosphereStyle.bubbles);
      expect(SheetMotion.stage.entrance, HeroEntranceStyle.peek);
      expect(SheetMotion.stage.idle, HeroIdleStyle.lean);
      expect(SheetMotion.stage.arrival, HeroCardArrival.fade);
    });

    test('the mascot hops as the sheet lands, and only then', () {
      expect(SheetMotion.landingHop(0), 0);
      expect(SheetMotion.landingHop(SheetMotion.landAt), 0);
      expect(
        SheetMotion.landingHop(
          SheetMotion.landAt + SheetMotion.landSeconds / 2,
        ),
        closeTo(SheetMotion.landHopHeight, 1e-9),
      );
      expect(SheetMotion.landingHop(SheetMotion.restAt), 0);
      // The sheet is in its seat by then.
      expect(SheetMotion.rise(SheetMotion.landAt), greaterThan(0.98));
      // And the hop is over before the loop starts.
      expect(
        SheetMotion.landAt + SheetMotion.landSeconds,
        lessThan(SheetMotion.restAt),
      );
    });

    test('after an intro the preview comes with the sheet', () {
      expect(SheetMotion.preludeFor(followsIntro: false), SheetMotion.prelude);
      expect(
        SheetMotion.preludeFor(followsIntro: true),
        lessThan(SheetMotion.prelude),
      );
    });

    test('the landing is heard as the mascot is bumped into its hop', () {
      expect(SheetMotion.cues.single.at, SheetMotion.landAt);
      expect(SheetMotion.cues.single.cue, PaywallCue.pop);
      expect(SheetMotion.landingHop(SheetMotion.landAt), 0);
      expect(SheetMotion.landingHop(SheetMotion.landAt + 0.1), greaterThan(0));
    });
  });
}
