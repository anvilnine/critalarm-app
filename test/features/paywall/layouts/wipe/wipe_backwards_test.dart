import 'package:critalarm/core/paywall/paywall_headline.dart';
import 'package:critalarm/core/ui_sound/paywall_cues.dart';
import 'package:critalarm/features/paywall/domain/entities/paywall_benefit.dart';
import 'package:critalarm/features/paywall/domain/entities/paywall_preview_id.dart';
import 'package:critalarm/features/paywall/domain/entities/paywall_product.dart';
import 'package:critalarm/features/paywall/domain/leaving_numbers.dart';
import 'package:critalarm/features/paywall/domain/paywall_leaving.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/hero/hero_turns.dart';
import 'package:critalarm/features/paywall/presentation/layouts/wipe/wipe_rules.dart';
import 'package:flutter_test/flutter_test.dart';

double _at(double t, {bool still = false, double settle = 0.3}) =>
    wipeDividerAt(t, settle: settle, isStill: still, reversed: true);

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
  group('the divider run backwards', () {
    test('the stage opens in full colour: the divider is at the left edge', () {
      expect(_at(0), 0);
      expect(_at(wipeBackSweepStart), 0);
    });

    test('grey covers the whole stage at the end of the sweep', () {
      expect(_at(wipeBackSweepEnd), closeTo(1, 1e-9));
      expect(_at((wipeBackSweepEnd + wipeBackHoldEnd) / 2), closeTo(1, 1e-9));
    });

    test('the sweep only goes one way', () {
      var last = 0.0;
      for (var t = wipeBackSweepStart; t <= wipeBackSweepEnd; t += 0.02) {
        final at = _at(t);
        expect(at, greaterThanOrEqualTo(last - 1e-9), reason: 'at $t');
        last = at;
      }
    });

    test('the grey pulls back and rests on Crit', () {
      expect(_at(wipeBackRestSeconds), closeTo(0.3, 1e-9));
      expect(_at(wipeBackRestSeconds + 5), closeTo(0.3, 1e-9));
      var last = 1.0;
      for (var t = wipeBackHoldEnd; t <= wipeBackRestSeconds; t += 0.02) {
        final at = _at(t);
        expect(at, lessThanOrEqualTo(last + 1e-9), reason: 'at $t');
        last = at;
      }
    });

    test('nothing may move: it rests on Crit from the first frame', () {
      expect(_at(0, still: true), 0.3);
    });

    test('a finger on the grip still works', () {
      const grip = WipeGrip(at: 0.6);
      expect(wipeDividerAt(1, settle: 0.3, grip: grip, reversed: true), 0.6);
    });

    test('the normal direction is unchanged', () {
      expect(wipeDividerAt(0, settle: 0.3), 1);
      expect(wipeDividerAt(wipeSweepEnd, settle: 0.3), closeTo(0.3, 1e-9));
    });

    test('the normal run keeps its cues', () {
      final cues = wipeSweepCues();
      expect(cues.map((c) => c.at), [wipeSweepStart, wipeLandsAt]);
      expect(cues.map((c) => c.cue), [PaywallCue.whoosh, PaywallCue.snap]);
    });

    test('the backwards run whooshes as the grey starts and snaps at rest', () {
      final cues = wipeSweepCues(reversed: true);
      expect(cues.first.at, wipeBackSweepStart);
      expect(cues.last.at, greaterThan(wipeBackHoldEnd));
      expect(cues.last.at, lessThan(wipeBackRestSeconds));
    });

    test('the backwards run rests later than the normal one', () {
      expect(wipeBackRestSeconds, greaterThan(wipeRestSeconds));
    });

    test('the head start of an intro moves the backwards run too', () {
      expect(
        wipeDividerAt(
          wipeBackSweepEnd - 0.3,
          settle: 0.3,
          reversed: true,
          lead: 0.3,
        ),
        closeTo(1, 1e-9),
      );
    });
  });

  group('the pictures on the colour side', () {
    test('they stay live until the grey has covered the stage', () {
      expect(wipeBackStrikeAt, greaterThanOrEqualTo(wipeBackSweepEnd));
      expect(wipeBackStrikeAt, lessThan(wipeBackHoldEnd));
    });

    test('nothing may move: the rows are struck from the first frame', () {
      expect(wipeLeavingStruckAt(0, isStill: true), isTrue);
    });

    test('with motion they are struck once the grey covers the stage', () {
      expect(wipeLeavingStruckAt(0, isStill: false), isFalse);
      expect(wipeLeavingStruckAt(wipeBackSweepStart, isStill: false), isFalse);
      expect(wipeLeavingStruckAt(wipeBackStrikeAt, isStill: false), isTrue);
      expect(wipeLeavingStruckAt(wipeBackRestSeconds, isStill: false), isTrue);
      expect(wipeLeavingStruckAt(60, isStill: false), isTrue);
    });
  });

  group('Crit on the leaving Wipe', () {
    test('sad through the sweep and the hold', () {
      for (final t in [0.0, 0.7, 1.0, 1.3, 1.4, wipeBackHoldEnd - 0.01]) {
        final face = wipeLeavingFaceAt(t);
        expect(face.face, HeroFace.sad, reason: 'at $t');
        expect(face.blend, 1, reason: 'at $t');
      }
    });

    test('calm by the time the grey has pulled back, and he stays', () {
      final mid = wipeLeavingFaceAt(
        (wipeBackHoldEnd + wipeBackRestSeconds) / 2,
      );
      expect(mid.from, HeroFace.sad);
      expect(mid.face, HeroFace.calm);
      expect(mid.blend, greaterThan(0));
      expect(mid.blend, lessThan(1));
      for (final t in [wipeBackRestSeconds, wipeBackRestSeconds + 10]) {
        final done = wipeLeavingFaceAt(t);
        expect(done.face, HeroFace.calm, reason: 'at $t');
        expect(done.blend, 1, reason: 'at $t');
      }
    });

    test('opened at rest he is calm from the first frame', () {
      for (final t in [0.0, 1.0, 5.0]) {
        final face = wipeLeavingFaceAt(t, atRest: true);
        expect(face.face, HeroFace.calm, reason: 'at $t');
        expect(face.from, HeroFace.calm, reason: 'at $t');
        expect(face.blend, 1, reason: 'at $t');
      }
    });

    test('never the purchase face, at any moment', () {
      for (var t = 0.0; t < 6; t += 0.05) {
        for (final atRest in [false, true]) {
          final face = wipeLeavingFaceAt(t, atRest: atRest);
          expect(_purchaseFaces, isNot(contains(face.face)), reason: '$t');
          expect(_purchaseFaces, isNot(contains(face.from)), reason: '$t');
        }
      }
    });
  });

  group('the list under the stage', () {
    test('history, pushes and critical topics, in the order of the table', () {
      final listed = paywallBenefitsFor(PaywallProduct.hosted);
      final rows = wipeLeavingRowsFor(listed);
      expect(rows.toSet(), {
        WipeLeavingRow.history,
        WipeLeavingRow.pushes,
        WipeLeavingRow.topics,
      });
      expect(rows, [
        WipeLeavingRow.history,
        WipeLeavingRow.pushes,
        WipeLeavingRow.topics,
      ]);
    });

    test('a benefit the product does not list is left out', () {
      final listed = [
        for (final b in paywallBenefitsFor(PaywallProduct.hosted))
          if (b.id != PaywallBenefitId.pushes) b,
      ];
      expect(wipeLeavingRowsFor(listed), [
        WipeLeavingRow.history,
        WipeLeavingRow.topics,
      ]);
    });

    test('benefits with no Free number never get a row', () {
      final listed = [
        for (final b in paywallBenefitsFor(PaywallProduct.hosted))
          if (b.id == PaywallBenefitId.appIcons ||
              b.id == PaywallBenefitId.reliabilityChecks)
            b,
      ];
      expect(wipeLeavingRowsFor(listed), isEmpty);
    });
  });

  group('which run a route gets', () {
    final listed = paywallBenefitsFor(PaywallProduct.hosted);
    final leaving = PaywallLeaving(
      endsOn: DateTime(2026, 10, 20),
      facts: const LeavingFacts(
        rang: 4,
        answered: 2,
        nights: 0,
        criticalTopics: 4,
        historyDaysHeld: 40,
      ),
    );

    test('a leaving Hosted route with its numbers runs backwards', () {
      expect(
        wipeRunsBackwards(
          isHosted: true,
          variant: PaywallHeadlineVariant.leaving,
          leaving: leaving,
          listed: listed,
        ),
        isTrue,
      );
    });

    test('a leaving route with no data draws the normal Wipe', () {
      expect(
        wipeRunsBackwards(
          isHosted: true,
          variant: PaywallHeadlineVariant.leaving,
          leaving: null,
          listed: listed,
        ),
        isFalse,
      );
    });

    test('a leaving route with no numbers still has a date to name', () {
      expect(
        wipeRunsBackwards(
          isHosted: true,
          variant: PaywallHeadlineVariant.leaving,
          leaving: PaywallLeaving(endsOn: DateTime(2026, 10, 20)),
          listed: listed,
        ),
        isTrue,
      );
    });

    test('every other headline keeps the normal run', () {
      for (final variant in [
        PaywallHeadlineVariant.none,
        PaywallHeadlineVariant.ended,
      ]) {
        expect(
          wipeRunsBackwards(
            isHosted: true,
            variant: variant,
            leaving: leaving,
            listed: listed,
          ),
          isFalse,
          reason: '$variant',
        );
      }
    });

    test('Pro never runs backwards', () {
      expect(
        wipeRunsBackwards(
          isHosted: false,
          variant: PaywallHeadlineVariant.leaving,
          leaving: leaving,
          listed: listed,
        ),
        isFalse,
      );
    });

    test('fewer than two rows to list keeps the normal run', () {
      final one = [
        for (final b in listed)
          if (b.id == PaywallBenefitId.history) b,
      ];
      expect(
        wipeRunsBackwards(
          isHosted: true,
          variant: PaywallHeadlineVariant.leaving,
          leaving: leaving,
          listed: one,
        ),
        isFalse,
      );
    });
  });

  group('the pictures the stage plays', () {
    final listed = paywallBenefitsFor(PaywallProduct.hosted);

    test('the leaving Wipe holds on its lead picture and never cycles', () {
      final loop = wipeLoopFor(listed, reversed: true, lead: 0.3);
      expect(loop.scenes, hasLength(1));
      expect(loop.scenes.single.preview, listed.first.previewId);
      for (final t in [0.0, 3, 9, 14, 30, 120, 600]) {
        final frame = loop.frameAt(t.toDouble());
        expect(frame.scene?.preview, listed.first.previewId, reason: 'at $t');
        expect(frame.activeIndex, 0, reason: 'at $t');
      }
    });

    test('the lead is the picture it holds on', () {
      final reordered = [listed[2], listed[0], listed[1]];
      final loop = wipeLoopFor(reordered, reversed: true, lead: 0);
      expect(loop.scenes.single.preview, reordered.first.previewId);
    });

    test('the normal Wipe still plays every picture, as it did', () {
      final loop = wipeLoopFor(listed, reversed: false, lead: 0.3);
      expect(
        [for (final s in loop.scenes) s.preview],
        [
          for (final b in listed) b.previewId,
        ],
      );
      expect(loop.prelude, -0.3);
      final seen = <PaywallPreviewId?>{
        for (var t = 0.0; t < 90; t += 0.5) loop.frameAt(t).scene?.preview,
      };
      expect(seen.length, greaterThan(1));
    });
  });
}
