import 'dart:ui';

import 'package:critalarm/core/ui_sound/paywall_cues.dart';
import 'package:critalarm/features/paywall/presentation/layouts/bento/bento_rules.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_cue_rules.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_hero.dart';
import 'package:flutter_test/flutter_test.dart';

BentoPlan _plan({
  int small = 3,
  double height = 455,
  bool isCompact = true,
}) => bentoPlanFor(
  width: 335,
  height: height,
  small: small,
  smallHeight: 62,
  words: 32,
  isCompact: isCompact,
);

void main() {
  group('the board', () {
    test('starts in the order the product lists, the first on the stage', () {
      final board = BentoBoard.of(4);
      expect(board.order, [0, 1, 2, 3]);
      expect(board.staged, 0);
      expect(board.tradedSlot, isNull);
      expect(bentoTradeAt(board, 99), 1);
    });

    test('a benefit takes the stage by trading places, nothing else moves', () {
      final board = BentoBoard.of(4).stage(2, at: 5);
      expect(board.order, [2, 1, 0, 3]);
      expect(board.staged, 2);
      expect(board.unstaged, 0);
      expect(board.tradedSlot, 2);
      expect(board.began, 5);
    });

    test('the benefit already on the stage trades with nothing', () {
      final board = BentoBoard.of(4).stage(2, at: 5);
      expect(identical(board.stage(2, at: 9), board), isTrue);
      expect(identical(board.stage(7, at: 9), board), isTrue);
    });

    test('a whole pass of the loop keeps every benefit on the board', () {
      var board = BentoBoard.of(5);
      for (var turn = 1; turn <= 10; turn++) {
        board = board.stage(turn % 5, at: turn * 4.0);
        expect(board.staged, turn % 5);
        expect(board.order.toSet(), {0, 1, 2, 3, 4});
      }
    });
  });

  group('a trade', () {
    final plan = _plan();
    final board = BentoBoard.of(4).stage(2, at: 5);

    test('runs from when it began for its length, then is over', () {
      expect(bentoTradeAt(board, 5), 0);
      expect(
        bentoTradeAt(board, 5 + bentoTradeSeconds / 2),
        closeTo(0.5, 0.001),
      );
      expect(bentoTradeAt(board, 5 + bentoTradeSeconds), 1);
      expect(bentoTradeAt(board, 60), 1);
    });

    test('starts with both tiles where they were', () {
      Rect at(int benefit) => bentoTileRect(
        board: board,
        plan: plan,
        benefit: benefit,
        trade: 0,
      );
      expect(at(2), plan.small[1]);
      expect(at(0), plan.stage);
    });

    test('ends with both tiles in each other’s place', () {
      Rect at(int benefit) => bentoTileRect(
        board: board,
        plan: plan,
        benefit: benefit,
        trade: 1,
      );
      expect(at(2), plan.stage);
      expect(at(0), plan.small[1]);
    });

    test('moves only the two tiles that traded', () {
      for (final trade in [0.0, 0.3, 0.7, 1.0]) {
        Rect at(int benefit) => bentoTileRect(
          board: board,
          plan: plan,
          benefit: benefit,
          trade: trade,
        );
        expect(at(1), plan.small[0]);
        expect(at(3), plan.small[2]);
      }
    });

    test('grows one tile as it shrinks the other, never past the stage', () {
      var grown = 0.0;
      var shrunk = plan.stage.height;
      for (var trade = 0.0; trade <= 1; trade += 0.05) {
        final up = bentoTileRect(
          board: board,
          plan: plan,
          benefit: 2,
          trade: trade,
        );
        final down = bentoTileRect(
          board: board,
          plan: plan,
          benefit: 0,
          trade: trade,
        );
        expect(up.height, greaterThanOrEqualTo(grown));
        expect(down.height, lessThanOrEqualTo(shrunk));
        expect(up.height, lessThanOrEqualTo(plan.stage.height + 0.001));
        grown = up.height;
        shrunk = down.height;
      }
    });

    test('lifts the tiles in the middle and sets them down flat', () {
      expect(bentoLiftAt(0), 0);
      expect(bentoLiftAt(0.5), 1);
      expect(bentoLiftAt(1), 0);
    });
  });

  group('what a tile draws', () {
    final plan = _plan();

    test('a small tile is its mark, the stage tile is the stage', () {
      expect(bentoStageShare(plan.small.first, plan), 0);
      expect(bentoStageShare(plan.stage, plan), 1);
      for (final isLeaving in [false, true]) {
        expect(bentoStageOpacity(0, isLeaving: isLeaving), 0);
        expect(bentoStageOpacity(1, isLeaving: isLeaving), 1);
      }
    });

    test('a tile on its way up is its mark, then the stage', () {
      expect(bentoStageOpacity(0.3), 0);
      expect(bentoStageOpacity(0.55), inExclusiveRange(0, 1));
      expect(bentoStageOpacity(0.7), 1);
    });

    test('a tile leaving the stage lets go of it before it has shrunk', () {
      expect(bentoStageOpacity(0.7, isLeaving: true), 0);
      // So the mascot is not on both tiles while they cross.
      for (var share = 0.0; share <= 1; share += 0.05) {
        final both =
            bentoStageOpacity(share) *
            bentoStageOpacity(1 - share, isLeaving: true);
        expect(both, 0);
      }
    });
  });

  group('the plan', () {
    test('fills the column exactly', () {
      for (final height in [455.0, 573.0, 690.0]) {
        for (final small in [1, 3, 4]) {
          final plan = _plan(
            small: small,
            height: height,
            isCompact: height < 500,
          );
          final used = plan.top + plan.height + plan.gap + 32 + plan.under;
          // The stage tile is a whole number of points.
          expect(used, closeTo(height, 1));
        }
      }
    });

    test('gives the small tiles one shape and one gutter', () {
      for (final small in [3, 4]) {
        final plan = _plan(small: small);
        expect(plan.small, hasLength(small));
        expect(plan.small.first.left, 0);
        expect(plan.small.last.right, closeTo(plan.stage.right, 0.001));
        for (var i = 1; i < small; i++) {
          expect(
            plan.small[i].width,
            closeTo(plan.small.first.width, 0.001),
          );
          expect(plan.small[i].height, plan.small.first.height);
          expect(
            plan.small[i].left - plan.small[i - 1].right,
            closeTo(bentoGutter, 0.001),
          );
        }
        expect(plan.small.first.top - plan.stage.bottom, bentoGutter);
      }
    });

    test('stops the stage tile growing and spends the rest on air', () {
      final plan = _plan(height: 760, isCompact: false);
      expect(plan.stage.height, bentoStageMax);
      expect(plan.small.first.height, 62 + bentoSmallGrow);
      expect(plan.top, greaterThan(bentoCrossRow));
    });

    test('keeps the board under the cross', () {
      expect(_plan().top, bentoCrossRow);
    });

    test('leaves the stage nothing before it overflows', () {
      final plan = _plan(height: 120);
      expect(plan.stage.height, 0);
    });
  });

  group('the entrance', () {
    test('lands the small tiles left to right', () {
      const t = 0.2;
      expect(bentoSmallLandAt(t, 0), greaterThan(bentoSmallLandAt(t, 1)));
      expect(bentoSmallLandAt(t, 1), greaterThan(bentoSmallLandAt(t, 3)));
    });

    test('lands the stage tile last', () {
      for (var i = 0; i < 4; i++) {
        expect(bentoSmallLandAt(bentoStageLands, i), greaterThan(0));
      }
      expect(bentoStageLandAt(bentoStageLands), 0);
    });

    test('is over by the resting second', () {
      const rest = bentoStageLands + heroEntranceSeconds;
      expect(bentoStageLandAt(rest), 1);
      for (var i = 0; i < 4; i++) {
        expect(bentoSmallLandAt(rest, i), 1);
      }
    });

    test('drops each tile from above and leaves it flat in its place', () {
      final start = bentoDropAt(0, from: bentoStageDropFrom);
      expect(start.dy, -bentoStageDropFrom);
      expect(start.opacity, 0);

      final falling = bentoDropAt(0.2, from: bentoStageDropFrom);
      expect(falling.dy, inExclusiveRange(-bentoStageDropFrom, 0));

      final landed = bentoDropAt(1, from: bentoStageDropFrom);
      expect(landed.dy, closeTo(0, 1e-9));
      expect(landed.opacity, 1);
      // A tile never sinks under its place.
      for (var p = 0.0; p <= 1; p += 0.05) {
        expect(
          bentoDropAt(p, from: bentoSmallDropFrom).dy,
          lessThanOrEqualTo(1e-9),
        );
      }
    });

    test('the stage tile touches the board when its cue plays', () {
      final touch = bentoDropAt(
        bentoStageLandAt(bentoStageThudAt),
        from: bentoStageDropFrom,
      );
      expect(touch.dy, closeTo(0, 0.5));
      expect(
        bentoCues(small: 0).single,
        const PaywallCueBeat(
          bentoStageThudAt,
          PaywallCue.drop,
        ),
      );
    });

    test('each small tile touches the board when its check plays', () {
      for (var i = 0; i < 4; i++) {
        final touch = bentoDropAt(
          bentoSmallLandAt(bentoSmallThudAt(i), i),
          from: bentoSmallDropFrom,
        );
        expect(touch.dy, closeTo(0, 0.5), reason: 'tile $i');
      }
    });

    test('the checks come in order and the landing is heard last', () {
      for (final small in [1, 3, 5, 8]) {
        final cues = bentoCues(small: small);
        expect(cues.last.cue, PaywallCue.drop);
        final checks = cues.sublist(0, cues.length - 1);
        expect(checks.length, lessThanOrEqualTo(small));
        expect(checks, isNotEmpty);
        for (final (i, beat) in checks.indexed) {
          expect(beat.cue, PaywallCue.check);
          expect(beat.at, bentoSmallThudAt(i));
          expect(beat.at, lessThan(bentoStageThudAt));
        }
      }
      final lead = bentoLeadFor(followsIntro: true);
      expect(bentoCues(small: 3, lead: lead).last.at, bentoStageThudAt - lead);
    });

    test('after an intro the small tiles are already down', () {
      expect(bentoLeadFor(followsIntro: false), 0);
      final lead = bentoLeadFor(followsIntro: true);
      expect(bentoSmallLandAt(lead, 0), 1);
      expect(bentoStageLandAt(lead), inExclusiveRange(0, 1));
    });

    test('the mascot drops into the tile and hops for each benefit', () {
      expect(bentoMotion.entrance, HeroEntranceStyle.drop);
      expect(bentoMotion.idle, HeroIdleStyle.benefitHop);
      expect(bentoMotion.atmosphere, HeroAtmosphereStyle.drift);
    });
  });

  group('the pace of a trade', () {
    test('is long enough to read as a swap', () {
      expect(bentoTradeSeconds, greaterThanOrEqualTo(0.9));
    });

    test('is half way at the half, and still under way near both ends', () {
      expect(bentoTradePath(0), 0);
      expect(bentoTradePath(0.5), closeTo(0.5, 0.03));
      expect(bentoTradePath(1), 1);
      // A quarter of a second in, the tiles have only begun to move.
      expect(bentoTradePath(0.25), lessThan(0.15));
      expect(bentoTradePath(0.75), lessThan(0.95));
    });
  });

  group('the stage tile', () {
    test('is the approved pair when it has the height', () {
      final a = bentoArrangementFor(const Size(350, 340));
      expect(a.kind, HeroStageKind.pair);
      expect(a.mascot.width, closeTo(a.card.width * heroMascotShare, 0.001));
      expect(a.group.height, lessThanOrEqualTo(340));
    });

    test('keeps the card large in a short tile, inside the tile', () {
      const size = Size(335, 240);
      final a = bentoArrangementFor(size);
      expect(a.kind, HeroStageKind.pair);
      expect(a.card.width, greaterThanOrEqualTo(heroCardMin));
      expect(a.mascot.top, greaterThanOrEqualTo(bentoStageTopRoom));
      expect(a.card.bottom, lessThanOrEqualTo(size.height));
      expect(a.group.left, greaterThanOrEqualTo(bentoStageSideRoom - 0.001));
      expect(
        a.group.right,
        lessThanOrEqualTo(size.width - bentoStageSideRoom + 0.001),
      );
      // The mascot's corner is still over the card's.
      expect(a.mascot.overlaps(a.card), isTrue);
    });

    test('falls back to the approved rule when too short', () {
      const size = Size(335, 150);
      final a = bentoArrangementFor(size);
      final approved = heroArrangementFor(size);
      expect(a.kind, approved.kind);
      expect(a.mascot, approved.mascot);
    });
  });
}
