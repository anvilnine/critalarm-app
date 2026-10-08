import 'dart:ui';

import 'package:critalarm/core/ui_sound/paywall_cues.dart';
import 'package:critalarm/features/paywall/domain/entities/paywall_preview_id.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_cue_rules.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_hero.dart';
import 'package:critalarm/features/paywall/presentation/layouts/previews/history_preview.dart';
import 'package:critalarm/features/paywall/presentation/layouts/previews/pushes_preview.dart';
import 'package:critalarm/features/paywall/presentation/layouts/previews/topics_preview.dart';
import 'package:critalarm/features/paywall/presentation/layouts/wipe/wipe_rules.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const settle = 0.27;

  group('the divider', () {
    test('opens at the right edge, so the whole stage is Free', () {
      expect(wipeDividerAt(0, settle: settle), 1);
      expect(wipeDividerAt(wipeSweepStart, settle: settle), 1);
    });

    test('sweeps left and never turns back', () {
      var last = 1.0;
      for (var t = wipeSweepStart; t <= wipeSweepEnd; t += 0.05) {
        final at = wipeDividerAt(t, settle: settle);
        expect(at, lessThanOrEqualTo(last));
        last = at;
      }
    });

    test('rests where it settles, moving or not', () {
      expect(wipeDividerAt(wipeRestSeconds, settle: settle), settle);
      expect(wipeDividerAt(60, settle: settle), settle);
      expect(wipeDividerAt(0, settle: settle, isStill: true), settle);
    });

    test('the entrance is over by the resting second', () {
      expect(wipeRestSeconds, greaterThanOrEqualTo(heroEntranceSeconds));
      expect(wipeRestSeconds, greaterThanOrEqualTo(wipeSweepEnd));
    });

    test('stays under a finger and inside the edges', () {
      const grip = WipeGrip(at: 0.5);
      expect(wipeDividerAt(3, settle: settle, grip: grip), 0.5);
      expect(grip.moved(0.2).at, closeTo(0.7, 1e-9));
      expect(grip.moved(2).at, wipeMax);
      expect(grip.moved(-2).at, wipeMin);
    });

    test('holds where it was left, then goes home', () {
      final grip = const WipeGrip(at: 0.7).released(10);
      expect(wipeDividerAt(10, settle: settle, grip: grip), 0.7);
      expect(
        wipeDividerAt(10 + wipeHoldSeconds, settle: settle, grip: grip),
        0.7,
      );
      final half = wipeDividerAt(
        10 + wipeHoldSeconds + wipeReturnSeconds / 2,
        settle: settle,
        grip: grip,
      );
      expect(half, inExclusiveRange(settle, 0.7));
      expect(
        wipeDividerAt(
          10 + wipeHoldSeconds + wipeReturnSeconds,
          settle: settle,
          grip: grip,
        ),
        closeTo(settle, 1e-9),
      );
    });

    test('never goes home by itself when nothing may move', () {
      final grip = const WipeGrip(at: 0.7).released(1);
      expect(
        wipeDividerAt(99, settle: settle, grip: grip, isStill: true),
        0.7,
      );
    });
  });

  group('the sweep after an intro', () {
    test('starts part of the way in and ends on the same place', () {
      expect(wipeLeadFor(followsIntro: false), 0);
      final lead = wipeLeadFor(followsIntro: true);
      expect(lead, greaterThan(0));
      expect(
        wipeDividerAt(wipeSweepStart - lead, settle: 0.3, lead: lead),
        1,
      );
      expect(
        wipeDividerAt(wipeSweepEnd - lead, settle: 0.3, lead: lead),
        closeTo(0.3, 1e-9),
      );
    });
  });

  group('the landing', () {
    test('is when the divider is on the mascot to the eye', () {
      expect(wipeLandsAt, inExclusiveRange(wipeSweepStart, wipeSweepEnd));
      final at = wipeDividerAt(wipeLandsAt, settle: 0.3);
      expect(at, closeTo(0.3, 0.03));
    });

    test('the sweep is a whoosh as it starts and a snap as it lands', () {
      expect(wipeSweepCues(), const [
        PaywallCueBeat(wipeSweepStart, PaywallCue.whoosh),
        PaywallCueBeat(wipeLandsAt, PaywallCue.snap),
      ]);
      final lead = wipeLeadFor(followsIntro: true);
      expect(wipeSweepCues(lead: lead).last.at, wipeLandsAt - lead);
      expect(wipeEntranceCues().single.cue, PaywallCue.pop);
      expect(wipeEntranceCues().single.at, lessThan(wipeSweepStart));
    });
  });

  group('the drag', () {
    test('ticks once at every tenth of the width', () {
      expect(wipeDragCue(0.42, 0.44), isNull);
      expect(wipeDragCue(0.48, 0.51), PaywallCue.ratchet);
      expect(wipeDragCue(0.51, 0.48), PaywallCue.ratchet);
      expect(wipeDragCue(0.51, 0.59), isNull);
      expect(wipeDragCue(0.5, 0.5), isNull);
      var ticks = 0;
      var at = 0.2;
      for (var i = 0; i < 60; i++) {
        final to = at + 0.01;
        if (wipeDragCue(at, to) == PaywallCue.ratchet) ticks++;
        at = to;
      }
      // From 0.2 to 0.8: the notches at 0.3 to 0.8.
      expect(ticks, inInclusiveRange(5, 6));
    });

    test('knocks once on reaching either stop, and not again there', () {
      const grip = WipeGrip(at: 0.88);
      final stopped = grip.moved(0.05);
      expect(stopped.at, wipeMax);
      expect(wipeDragCue(grip.at, stopped.at), PaywallCue.refuse);
      // Pushed further it has not moved, so nothing more is felt.
      expect(wipeDragCue(stopped.at, stopped.moved(0.05).at), isNull);
      expect(
        wipeDragCue(0.13, const WipeGrip(at: 0.13).moved(-0.2).at),
        PaywallCue.refuse,
      );
      // Coming back off the stop is a notch like any other.
      expect(wipeDragCue(wipeMax, 0.86), PaywallCue.ratchet);
    });
  });

  group('the lean', () {
    test('both sides are one mascot: the same entrance and idle', () {
      expect(wipeMotion.entrance, wipeFreeMotion.entrance);
      expect(wipeMotion.idle, wipeFreeMotion.idle);
      expect(wipeMotion.idle, HeroIdleStyle.lean);
      expect(wipeMotion.entrance, HeroEntranceStyle.pop);
    });

    test('bubbles rise on the product side only', () {
      expect(wipeMotion.atmosphere, HeroAtmosphereStyle.bubbles);
      expect(wipeFreeMotion.atmosphere, isNot(HeroAtmosphereStyle.bubbles));
    });

    test('the divider stays put at rest and between leans', () {
      expect(wipeLeanShiftAt(0, mascot: 160), 0);
      expect(wipeLeanShiftAt(0.5, mascot: 160), closeTo(0, 1e-9));
      expect(wipeLeanShiftAt(heroLeanEvery, mascot: 160), closeTo(0, 1e-9));
    });

    test('it goes toward the product with the mascot, and comes back', () {
      const peak = (1.4 + 3.2) / 2;
      final shift = wipeLeanShiftAt(peak, mascot: 160);
      expect(shift, greaterThan(4));
      expect(shift, lessThan(160 * 0.12));
      expect(wipeLeanShiftAt(peak - 0.5, mascot: 160), lessThan(shift));
      expect(wipeLeanShiftAt(peak + 0.5, mascot: 160), lessThan(shift));
    });
  });

  group('where it settles', () {
    test('down the middle of the mascot', () {
      const size = Size(390, 380);
      final arrangement = wipeArrangementFor(size);
      expect(arrangement.kind, HeroStageKind.pair);
      expect(
        wipeSettleFor(arrangement, size.width) * size.width,
        closeTo(arrangement.mascot.center.dx, 1e-9),
      );
    });

    test('a fifth of the way in with no mascot', () {
      final arrangement = wipeArrangementFor(const Size(390, 20));
      expect(arrangement.kind, HeroStageKind.none);
      expect(wipeSettleFor(arrangement, 390), wipeSettleAlone);
    });

    test('the tags have the top of the stage', () {
      const size = Size(390, 380);
      final arrangement = wipeArrangementFor(size);
      expect(
        arrangement.mascot.top,
        greaterThanOrEqualTo(heroTopRoom + wipeTagRoom),
      );
      expect(arrangement.card.bottom, lessThanOrEqualTo(size.height));
      final grip = wipeGripCentreFor(arrangement, size);
      expect(grip, greaterThan(arrangement.mascot.bottom));
      expect(grip, lessThan(size.height));
    });
  });

  group('the tags', () {
    test('a tag is gone before its side is too narrow for it', () {
      expect(wipeTagShow(30, 40), 0);
      expect(wipeTagShow(40, 40), 0);
      expect(wipeTagShow(56, 40), 1);
      expect(wipeTagShow(48, 40), closeTo(0.5, 1e-9));
    });
  });

  group('the Free side', () {
    test('the limit previews hold on the limit', () {
      expect(
        topicsPreviewPhaseAt(
          TopicsPreviewTimes.reset + wipeFreeOffsetFor(PaywallPreviewId.topics),
        ),
        TopicsPreviewPhase.refused,
      );
      expect(
        pushesPreviewPhaseAt(
          PushesPreviewTimes.drain + wipeFreeOffsetFor(PaywallPreviewId.pushes),
        ),
        PushesPreviewPhase.stalled,
      );
      expect(
        historyPreviewPhaseAt(
          HistoryPreviewTimes.rewind +
              wipeFreeOffsetFor(PaywallPreviewId.history),
        ),
        HistoryPreviewPhase.stopped,
      );
    });

    test('every preview has a moment, early in its loop', () {
      for (final id in PaywallPreviewId.values) {
        expect(wipeFreeOffsetFor(id), inInclusiveRange(0, 2));
      }
    });

    test('is the same turn in the same place with a doubtful mascot', () {
      final loop = HeroLoop(const [
        PaywallPreviewId.topics,
        PaywallPreviewId.pushes,
      ]);
      for (final t in [0.4, 1.5, 3.0, loop.period - 0.1, loop.period + 0.2]) {
        final frame = loop.frameAt(t);
        final free = wipeFreeFrame(frame);
        expect(free.scene, same(frame.scene));
        expect(free.previous, same(frame.previous));
        expect(free.cardEnter, frame.cardEnter);
        expect(free.entrance, frame.entrance);
        expect(free.hop, frame.hop);
        expect(free.bob, frame.bob);
        expect(free.blink, frame.blink);
        expect(free.direction, frame.direction);
        expect(free.face, HeroFace.doubtful);
        expect(free.faceBlend, 1);
        expect(free.props, isEmpty);
        // Its preview is cued in the past, so it never waits to start.
        expect(free.playFrom, lessThanOrEqualTo(wipeFrozenSecond));
      }
    });
  });

  group('the muted picture', () {
    test('full saturation changes nothing', () {
      expect(wipeMutedMatrix(1), [
        1, 0, 0, 0, 0, //
        0, 1, 0, 0, 0, //
        0, 0, 1, 0, 0, //
        0, 0, 0, 1, 0, //
      ]);
    });

    test('white stays white and grey stays grey', () {
      final m = wipeMutedMatrix(wipeFreeSaturation);
      for (var row = 0; row < 3; row++) {
        expect(m[row * 5] + m[row * 5 + 1] + m[row * 5 + 2], closeTo(1, 1e-9));
      }
    });
  });
}
