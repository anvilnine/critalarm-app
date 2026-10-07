import 'dart:ui';

import 'package:critalarm/features/paywall/domain/entities/paywall_preview_id.dart';
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
