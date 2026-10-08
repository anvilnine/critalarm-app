import 'dart:ui';

import 'package:critalarm/features/paywall/presentation/layouts/kit/hero/hero_turns.dart';
import 'package:critalarm/features/paywall/presentation/layouts/receipt/receipt_rules.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const tl = ReceiptTimeline.restAt;

  group('the order of the print', () {
    test('feed, stamp, peek, rest', () {
      expect(ReceiptTimeline.feedStart, lessThan(ReceiptTimeline.feedEnd));
      expect(ReceiptTimeline.feedEnd, lessThan(ReceiptTimeline.stampAt));
      expect(ReceiptTimeline.stampAt, lessThan(ReceiptTimeline.stampLanded));
      // The card comes out only once the paper is there to hide it.
      expect(ReceiptTimeline.feedEnd, lessThan(ReceiptTimeline.peekStart));
      expect(ReceiptTimeline.stampLanded, lessThan(tl));
      expect(tl, ReceiptTimeline.prelude + heroEntranceSeconds);
      expect(tl, lessThanOrEqualTo(2));
    });

    test('the paper comes out a part at a time and never goes back', () {
      const stops = <double>[40, 70, 100, 130, 180, 240];
      expect(ReceiptTimeline.feed(0, stops), 0);
      expect(ReceiptTimeline.feed(ReceiptTimeline.feedStart, stops), 0);
      var last = 0.0;
      for (var t = 0.0; t <= tl; t += 0.01) {
        final out = ReceiptTimeline.feed(t, stops);
        expect(out, greaterThanOrEqualTo(last));
        last = out;
      }
      expect(ReceiptTimeline.feed(ReceiptTimeline.feedEnd, stops), 240);
      expect(ReceiptTimeline.feed(tl, stops), 240);
      // It waits between parts: at the end of the first share the first
      // part is out and no more.
      const share = (ReceiptTimeline.feedEnd - ReceiptTimeline.feedStart) / 6;
      expect(
        ReceiptTimeline.feed(ReceiptTimeline.feedStart + share * 0.9, stops),
        closeTo(40, 0.01),
      );
    });

    test('each part is printed after the one above it', () {
      const steps = 7;
      const mid = (ReceiptTimeline.feedStart + ReceiptTimeline.feedEnd) / 2;
      for (var i = 1; i < steps; i++) {
        expect(
          ReceiptTimeline.ink(mid, i, steps),
          lessThanOrEqualTo(ReceiptTimeline.ink(mid, i - 1, steps)),
        );
      }
      for (var i = 0; i < steps; i++) {
        expect(ReceiptTimeline.ink(0, i, steps), 0);
        expect(ReceiptTimeline.ink(ReceiptTimeline.feedEnd, i, steps), 1);
      }
    });

    test('the paper swings while it feeds and hangs square after', () {
      var swung = 0.0;
      for (var t = 0.0; t <= tl; t += 0.01) {
        final angle = ReceiptTimeline.sway(t).abs();
        expect(angle, lessThanOrEqualTo(ReceiptTimeline.swayMax));
        if (angle > swung) swung = angle;
      }
      expect(swung, greaterThan(0));
      expect(ReceiptTimeline.sway(0), 0);
      expect(ReceiptTimeline.sway(ReceiptTimeline.feedEnd), 0);
      expect(ReceiptTimeline.sway(tl), 0);
    });

    test('the stamp lands at its resting angle and size', () {
      expect(ReceiptTimeline.stamp(ReceiptTimeline.stampAt - 0.01).opacity, 0);
      final falling = ReceiptTimeline.stamp(ReceiptTimeline.stampAt + 0.02);
      expect(falling.scale, greaterThan(1.2));
      final rest = ReceiptTimeline.stamp(tl);
      expect(rest.opacity, 1);
      expect(rest.scale, closeTo(1, 1e-9));
      expect(rest.angle, closeTo(ReceiptTimeline.stampAngle, 1e-9));
      // A slight angle, never a tilted card.
      expect(ReceiptTimeline.stampAngle.abs(), lessThan(0.15));
    });

    test('the mascot watches the lines, is glad at the total, and is '
        'startled by the stamp', () {
      for (final count in [2, 4, 5]) {
        ReceiptActor at(double t) => ReceiptTimeline.actor(t, count: count);
        final total = ReceiptTimeline.totalAt(count);
        expect(total, greaterThan(0.5));
        expect(total, lessThan(ReceiptTimeline.stampAt - 0.2));

        expect(at(0).entrance, 0);
        expect(at(0.2).face, HeroFace.arriving);
        expect(at(total - 0.05).face, HeroFace.watching);
        expect(at(total + 0.05).face, HeroFace.glad);
        expect(at(ReceiptTimeline.stampAt - 0.01).hop, 0);
        final hit = at(ReceiptTimeline.stampAt + 0.2);
        expect(hit.face, HeroFace.startled);
        expect(hit.fromFace, HeroFace.glad);
        expect(hit.hop, greaterThan(0.5));
        final rest = at(tl);
        expect(rest.face, HeroFace.glad);
        expect(rest.faceBlend, 1);
        expect(rest.hop, 0);
        expect(rest.entrance, 1);
      }
    });

    test('the mascot nods once for each line and for nothing else', () {
      for (final count in [2, 4, 5]) {
        var nods = 0;
        var wasUp = false;
        var highest = 0.0;
        for (var t = 0.0; t <= tl; t += 0.002) {
          final nod = ReceiptTimeline.nod(t, count);
          expect(nod, greaterThanOrEqualTo(0));
          if (nod > highest) highest = nod;
          final isUp = nod > 0.01;
          if (isUp && !wasUp) nods++;
          wasUp = isUp;
        }
        expect(nods, count);
        expect(highest, closeTo(ReceiptTimeline.nodHeight, 0.01));
        // Level before the first line and once the total prints.
        expect(ReceiptTimeline.nod(ReceiptTimeline.feedStart, count), 0);
        expect(ReceiptTimeline.nod(ReceiptTimeline.totalAt(count), count), 0);
        expect(ReceiptTimeline.nod(tl, count), 0);
      }
    });

    test('the card is hidden until the peek and out at rest', () {
      expect(ReceiptTimeline.peek(ReceiptTimeline.peekStart), 0);
      expect(ReceiptTimeline.peek(tl), closeTo(1, 1e-9));
    });

    test('one preview gives way to the next behind the paper', () {
      expect(receiptTuck(0), closeTo(0, 1e-9));
      expect(receiptTuck(0.5), closeTo(1, 1e-9));
      expect(receiptTuck(1), closeTo(0, 1e-9));
      expect(receiptShowsNext(0.49), isFalse);
      expect(receiptShowsNext(0.5), isTrue);
    });
  });

  group('where things stand', () {
    const stages = [
      Size(390, 458),
      Size(390, 446),
      Size(375, 352),
      Size(375, 420),
      Size(375, 300),
    ];

    test('everything is on the stage and the paper keeps the left edge', () {
      for (final stage in stages) {
        for (final count in [2, 4, 5]) {
          if (stage.height < ReceiptPlan.minHeight(count)) continue;
          final plan = ReceiptPlan.of(stage, count: count);
          final all = Offset.zero & stage;
          expect(plan.paper.left, ReceiptPlan.side);
          for (final box in [plan.slot, plan.paper, plan.mascot, plan.card]) {
            expect(all.contains(box.topLeft), isTrue, reason: '$stage $box');
            expect(
              box.bottom,
              lessThanOrEqualTo(stage.height),
              reason: '$stage $count',
            );
            expect(box.right, lessThanOrEqualTo(stage.width));
          }
          // The mascot keeps clear of the close cross, and leans over the
          // paper's edge by less than the paper's own margin.
          expect(plan.mascot.top, greaterThanOrEqualTo(ReceiptPlan.crossRoom));
          expect(
            plan.mascot.left,
            greaterThanOrEqualTo(plan.paper.right - ReceiptPlan.lean),
          );
          expect(ReceiptPlan.lean, lessThan(ReceiptPlan.pad));
          // The card is whole beside the paper, under the mascot, at a
          // size its scene reads at.
          expect(plan.card.left, greaterThanOrEqualTo(plan.paper.right));
          expect(plan.card.top, greaterThanOrEqualTo(plan.mascot.bottom));
          expect(plan.card.bottom, lessThanOrEqualTo(plan.paper.bottom + 0.01));
          expect(
            plan.card.width,
            greaterThanOrEqualTo(ReceiptPlan.cardMin - 1e-6),
          );
          // To change previews it goes wholly behind the paper.
          expect(
            plan.card.right - plan.cardTravel,
            closeTo(plan.paper.right, 1e-6),
          );
        }
      }
    });

    test('the mascot is large where the stage has the room', () {
      final tall = ReceiptPlan.of(const Size(390, 358), count: 4);
      expect(tall.mascot.width, greaterThanOrEqualTo(145));
      expect(tall.card.width, closeTo(ReceiptPlan.cardMax, 1e-6));
      final small = ReceiptPlan.of(const Size(375, 352), count: 4);
      expect(small.mascot.width, greaterThanOrEqualTo(138));
      expect(small.card.width, closeTo(ReceiptPlan.cardMax, 1e-6));
    });

    test('every line is one size, the one the longest fits at', () {
      for (final width in [375.0, 390.0, 430.0]) {
        final plan = ReceiptPlan.of(Size(width, 400), count: 5);
        final room =
            plan.paper.width -
            ReceiptPlan.pad * 2 -
            ReceiptPlan.tick -
            ReceiptPlan.tickGap;
        for (final longest in [18, 25, 26]) {
          final font = plan.lineFont(longest);
          expect(font, lessThanOrEqualTo(ReceiptPlan.fontMax));
          expect(font, greaterThanOrEqualTo(ReceiptPlan.fontMin));
          expect(
            font * ReceiptPlan.monoAdvance * longest,
            lessThanOrEqualTo(room + 0.01),
          );
        }
        expect(plan.lineFont(26), lessThanOrEqualTo(plan.lineFont(18)));
      }
    });

    test('the lines take the height they are given, within limits', () {
      final tight = ReceiptPlan.of(
        Size(375, ReceiptPlan.minHeight(5)),
        count: 5,
      );
      expect(tight.row, ReceiptPlan.rowMin);
      final loose = ReceiptPlan.of(const Size(390, 900), count: 4);
      expect(loose.row, ReceiptPlan.rowMax);
      expect(loose.paper.height, lessThan(ReceiptPlan.maxHeight(4)));
    });

    test('the stops end at the foot of the paper, one per part', () {
      final plan = ReceiptPlan.of(const Size(390, 440), count: 5);
      expect(plan.stops.length, 5 + 3);
      expect(plan.stops.last, plan.paper.height);
      for (var i = 1; i < plan.stops.length; i++) {
        expect(plan.stops[i], greaterThan(plan.stops[i - 1]));
      }
    });

    test('a touch finds its line, and only on the paper', () {
      final plan = ReceiptPlan.of(const Size(390, 440), count: 4);
      final centres = plan.rowCentres;
      for (final (i, y) in centres.indexed) {
        expect(plan.rowAt(Offset(plan.paper.center.dx, y)), i);
        expect(plan.rowAt(Offset(plan.paper.center.dx, y + 10)), i);
      }
      expect(plan.rowAt(Offset(plan.paper.right + 30, centres.first)), isNull);
      expect(
        plan.rowAt(Offset(plan.paper.center.dx, plan.paper.bottom - 4)),
        isNull,
      );
    });
  });
}
