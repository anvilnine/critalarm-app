import 'dart:ui';

import 'package:critalarm/features/paywall/domain/leaving_numbers.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/hero/hero_loop.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/hero/hero_turns.dart';
import 'package:critalarm/features/paywall/presentation/layouts/receipt/leaving/leaving_receipt_rules.dart';
import 'package:critalarm/features/paywall/presentation/layouts/receipt/receipt_rules.dart';
import 'package:flutter_test/flutter_test.dart';

/// The faces a purchase wears. A leaving layout never does.
const Set<HeroFace> _purchaseFaces = {
  HeroFace.glad,
  HeroFace.winking,
  HeroFace.winning,
  HeroFace.proud,
  HeroFace.loving,
  HeroFace.cool,
  HeroFace.relieved,
  HeroFace.startled,
};

void main() {
  group('LeavingReceiptTimeline.actor', () {
    test('Crit is sad from the first frame through the whole print', () {
      for (final t in [
        0.0,
        0.4,
        1.0,
        ReceiptTimeline.stampAt,
        ReceiptTimeline.stampLanded,
        2.0,
      ]) {
        final actor = LeavingReceiptTimeline.actor(t);
        expect(actor.face, HeroFace.sad, reason: 'at $t');
        expect(actor.faceBlend, 1, reason: 'at $t');
      }
    });

    test('he never wears the purchase face and never hops, at any moment', () {
      for (var t = 0.0; t < 6; t += 0.05) {
        for (final atRest in [false, true]) {
          final actor = LeavingReceiptTimeline.actor(t, atRest: atRest);
          expect(_purchaseFaces, isNot(contains(actor.face)), reason: '$t');
          expect(_purchaseFaces, isNot(contains(actor.fromFace)), reason: '$t');
          expect(actor.hop, 0, reason: '$t');
        }
      }
    });

    test('after the entrance he settles to calm and stays', () {
      final start = LeavingReceiptTimeline.actor(LeavingReceiptTimeline.restAt);
      expect(start.face, HeroFace.calm);
      expect(start.fromFace, HeroFace.sad);
      expect(start.faceBlend, 0);
      for (final t in [
        LeavingReceiptTimeline.restAt + heroFaceBlend,
        LeavingReceiptTimeline.restAt + 10,
      ]) {
        final done = LeavingReceiptTimeline.actor(t);
        expect(done.face, HeroFace.calm, reason: 'at $t');
        expect(done.faceBlend, 1, reason: 'at $t');
      }
    });

    test('opened at rest he is calm from the first frame, no tear to fade', () {
      for (final t in [0.0, 1.0, 5.0]) {
        final actor = LeavingReceiptTimeline.actor(t, atRest: true);
        expect(actor.face, HeroFace.calm, reason: 'at $t');
        expect(actor.fromFace, HeroFace.calm, reason: 'at $t');
        expect(actor.faceBlend, 1, reason: 'at $t');
        expect(actor.entrance, 1, reason: 'at $t');
      }
    });

    test('the entrance pops in over the first second', () {
      expect(LeavingReceiptTimeline.actor(0).entrance, 0);
      expect(LeavingReceiptTimeline.actor(heroEntranceSeconds).entrance, 1);
    });
  });

  test('the print ends before Crit settles', () {
    expect(
      LeavingReceiptTimeline.restAt,
      greaterThan(ReceiptTimeline.stampLanded),
    );
  });

  group('leavingReceiptCues', () {
    test('one cue per row, then the stamp, nothing for a total', () {
      final beats = leavingReceiptCues(4);
      expect(beats.length, 5);
      expect(beats.last.at, ReceiptTimeline.stampAt);
    });

    test('each row cue comes as the row leaves the slot, in order', () {
      for (final rows in [2, 3, 4]) {
        final beats = leavingReceiptCues(rows);
        for (var i = 1; i < beats.length; i++) {
          expect(beats[i].at, greaterThan(beats[i - 1].at));
        }
        expect(beats[rows - 1].at, lessThan(ReceiptTimeline.feedEnd));
      }
    });
  });

  group('leavingSpanDays', () {
    LeavingFacts held(int days) => LeavingFacts(
      rang: 12,
      answered: 4,
      nights: 3,
      criticalTopics: 1,
      historyDaysHeld: days,
    );

    test('a phone holding the whole window says the window', () {
      expect(leavingSpanDays(held(90)), 90);
      expect(leavingSpanDays(held(400)), 90);
    });

    test('a phone holding fewer days says the days it holds', () {
      expect(leavingSpanDays(held(30)), 30);
      expect(leavingSpanDays(held(12)), 12);
    });

    test('a phone holding under a day says one', () {
      expect(leavingSpanDays(held(0)), 1);
    });
  });

  group('leavingReceiptLayoutFor', () {
    const stage = Size(390, 520);
    const narrow = Size(320, 480);

    test('the face stands on the slip bottom right corner, 2 rows and 4', () {
      for (final size in [stage, narrow]) {
        for (final rows in [2, 3, 4]) {
          final layout = leavingReceiptLayoutFor(
            size,
            rows: rows,
            textScale: 1,
          );
          final corner = layout.paper.bottomRight;
          expect(
            (layout.mascot.center - corner).distance,
            lessThanOrEqualTo(layout.mascot.width * 0.9),
            reason: '$size $rows rows',
          );
          // It leans over the slip's edge by a little and covers no row.
          expect(
            layout.mascot.left,
            greaterThanOrEqualTo(layout.paper.right - ReceiptPlan.lean - 0.5),
          );
          expect(layout.mascot.bottom, closeTo(layout.paper.bottom, 1));
          expect(layout.mascot.right, lessThanOrEqualTo(size.width));
          expect(
            layout.mascot.width,
            greaterThanOrEqualTo(ReceiptPlan.mascotMin),
          );
          expect(layout.isStacked, isFalse);
        }
      }
    });

    test('the slip hangs from the slot on the left edge', () {
      final layout = leavingReceiptLayoutFor(stage, rows: 3, textScale: 1);
      expect(layout.paper.left, ReceiptPlan.side);
      expect(layout.slot.top, lessThan(layout.paper.top));
    });

    test('above text scale 1.3 the slip is full width, the face below it', () {
      final layout = leavingReceiptLayoutFor(
        const Size(390, 760),
        rows: 4,
        textScale: 1.5,
      );
      expect(layout.isStacked, isTrue);
      expect(layout.paper.width, 390 - ReceiptPlan.side * 2);
      expect(layout.mascot.top, greaterThanOrEqualTo(layout.paper.bottom));
      expect(layout.mascot.bottom, lessThanOrEqualTo(760));
    });

    test('at exactly 1.3 it is not stacked yet', () {
      expect(
        leavingReceiptLayoutFor(stage, rows: 3, textScale: 1.3).isStacked,
        isFalse,
      );
    });

    test('stacked needs more height than side by side', () {
      expect(
        leavingReceiptMinHeight(4, textScale: 1.5),
        greaterThan(leavingReceiptMinHeight(4, textScale: 1)),
      );
    });
  });
}
