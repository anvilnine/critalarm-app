import 'package:critalarm/core/access/feature_decision.dart';
import 'package:critalarm/core/access/holding.dart';
import 'package:critalarm/core/access/lock_tap_rule.dart';
import 'package:critalarm/features/challenges/domain/challenge_kind.dart';
import 'package:critalarm/features/settings/domain/personalize/challenge_shelf_rules.dart';
import 'package:flutter_test/flutter_test.dart';

const _open = FeatureDecision.open();
const _locked = FeatureDecision.locked(Holding.pro);
const _confirming = FeatureDecision.confirming(Holding.pro);
const _unread = FeatureDecision.unread(Holding.pro);
const _notOffered = FeatureDecision.notOffered();

void main() {
  group('tiles', () {
    test('No challenge comes first, then the kinds in order', () {
      final tiles = shelfTilesFor(ChallengeKind.values);
      expect(tiles.first, ShelfTile.off);
      expect(tiles.first.isOff, isTrue);
      expect(tiles.skip(1).map((t) => t.kind), ChallengeKind.values);
      expect(tiles, hasLength(ChallengeKind.values.length + 1));
    });

    test('each tile carries the right kind', () {
      final tiles = shelfTilesFor(ChallengeKind.values);
      expect(tiles[1].kind, ChallengeKind.typeTopicName);
      expect(tiles[2].kind, ChallengeKind.typeAlertTitle);
      expect(tiles[3].kind, ChallengeKind.opsMath);
      expect(tiles[4].kind, ChallengeKind.scratchCard);
      expect(tiles[5].kind, ChallengeKind.shake);
      expect(tiles.skip(1).any((t) => t.isOff), isFalse);
    });

    test('an empty list of kinds leaves only No challenge', () {
      expect(shelfTilesFor(const []), [ShelfTile.off]);
    });
  });

  group('columns', () {
    int at(double width, [double scale = 1]) =>
        shelfColumnsFor(columnWidth: width, textScale: scale);

    test('two at 390', () => expect(at(390), 2));
    test('two at 375', () => expect(at(375), 2));
    test('three at 600', () => expect(at(600), 3));
    test('three at the widest column', () => expect(at(560), 3));

    test('one at text scale 2.0, whatever the width', () {
      expect(at(390, 2), 1);
      expect(at(560, 2), 1);
      expect(at(1024, 2), 1);
      expect(at(390, 2.5), 1);
    });

    test('1.3 keeps the columns of the width', () {
      expect(at(390, 1.3), 2);
      expect(at(560, 1.3), 3);
    });

    test('one when a tile would be under 150 wide', () {
      // 320 wide: two tiles of 140.
      expect(shelfTileWidthFor(columnWidth: 320, columns: 2), 140);
      expect(at(320), 1);
      expect(at(300), 1);
    });

    test('two tiles are 150 wide from 340', () {
      expect(shelfTileWidthFor(columnWidth: 340, columns: 2), 150);
      expect(at(340), 2);
      expect(at(339), 1);
    });

    test('three columns give way to two when their tiles are too narrow', () {
      // 480 wide: three tiles of about 142.7.
      expect(shelfTileWidthFor(columnWidth: 480, columns: 3), lessThan(150));
      expect(at(480), 2);
      // Three tiles of 150 need 502.
      expect(shelfTileWidthFor(columnWidth: 502, columns: 3), 150);
      expect(at(502), 3);
      expect(at(501), 2);
    });

    test(
      'no tile is ever narrower than 150 while there is a smaller count',
      () {
        for (var w = 340.0; w <= 1200; w += 1) {
          final columns = at(w);
          if (columns == 1) continue;
          expect(
            shelfTileWidthFor(columnWidth: w, columns: columns),
            greaterThanOrEqualTo(kShelfMinTileWidth),
            reason: 'width $w with $columns columns',
          );
        }
      },
    );
  });

  group('the tick', () {
    test('a saved kind is ticked while the feature is usable', () {
      for (final decision in [_open, _confirming, _unread]) {
        expect(
          shelfChosenFor(saved: ChallengeKind.shake, decision: decision),
          ChallengeKind.shake,
        );
      }
    });

    test('a saved kind shows Off while locked: the lapsed case', () {
      expect(
        shelfChosenFor(saved: ChallengeKind.shake, decision: _locked),
        isNull,
      );
    });

    test('nothing saved is Off', () {
      expect(shelfChosenFor(saved: null, decision: _open), isNull);
      expect(shelfChosenFor(saved: null, decision: _locked), isNull);
    });
  });

  group('what a tap does', () {
    LockTapAnswer tap(
      ShelfTap tap,
      FeatureDecision decision, {
      bool isPlanRead = true,
    }) => shelfTapFor(tap: tap, decision: decision, isPlanRead: isPlanRead);

    test('the tile opens the try for everyone', () {
      for (final decision in [_open, _locked, _confirming, _unread]) {
        expect(tap(ShelfTap.tile, decision), isA<OpenPage>());
        expect(
          tap(ShelfTap.tile, decision, isPlanRead: false),
          isA<OpenPage>(),
        );
      }
    });

    test('the pick control saves when nothing is locked', () {
      expect(tap(ShelfTap.pick, _open), isA<DoIt>());
      expect(tap(ShelfTap.pick, _confirming), isA<DoIt>());
      expect(tap(ShelfTap.pick, _unread), isA<DoIt>());
    });

    test('the pick control opens the Pro paywall when locked', () {
      expect(tap(ShelfTap.pick, _locked), const OpenPaywall(Holding.pro));
    });

    test('the pick control waits while the plan is not read', () {
      expect(
        tap(ShelfTap.pick, _locked, isPlanRead: false),
        isA<WaitForPlan>(),
      );
      expect(tap(ShelfTap.pick, _open, isPlanRead: false), isA<WaitForPlan>());
    });

    test('the pick control does nothing where challenges are not offered', () {
      expect(tap(ShelfTap.pick, _notOffered), isA<Nothing>());
    });

    test('the wide button sells only while locked', () {
      expect(tap(ShelfTap.plan, _locked), const OpenPaywall(Holding.pro));
      expect(tap(ShelfTap.plan, _open), isA<Nothing>());
      expect(tap(ShelfTap.plan, _confirming), isA<Nothing>());
      expect(
        tap(ShelfTap.plan, _locked, isPlanRead: false),
        isA<WaitForPlan>(),
      );
    });

    test('No challenge saves with no plan', () {
      expect(shelfOffTapAnswer(), isA<DoIt>());
    });
  });

  group('the pick control', () {
    ShelfPick of(
      ShelfTile tile, {
      ChallengeKind? chosen,
      FeatureDecision decision = _open,
      bool isPlanRead = true,
    }) => shelfPickFor(
      tile: tile,
      chosen: chosen,
      decision: decision,
      isPlanRead: isPlanRead,
    );

    const shake = ShelfTile(ChallengeKind.shake);
    const math = ShelfTile(ChallengeKind.opsMath);

    test('free: every challenge is locked and Off holds the tick', () {
      expect(of(shake, decision: _locked), ShelfPick.locked);
      expect(of(math, decision: _locked), ShelfPick.locked);
      expect(of(ShelfTile.off, decision: _locked), ShelfPick.chosen);
    });

    test('Pro held: the chosen one is ticked and the rest are open', () {
      expect(of(shake, chosen: ChallengeKind.shake), ShelfPick.chosen);
      expect(of(math, chosen: ChallengeKind.shake), ShelfPick.open);
      expect(
        of(ShelfTile.off, chosen: ChallengeKind.shake),
        ShelfPick.open,
      );
    });

    test('Pro held with nothing saved: Off is ticked', () {
      expect(of(ShelfTile.off), ShelfPick.chosen);
      expect(of(shake), ShelfPick.open);
    });

    test('plan not read: plain rings, and Off keeps its tick', () {
      expect(of(shake, decision: _locked, isPlanRead: false), ShelfPick.unread);
      expect(of(shake, isPlanRead: false), ShelfPick.unread);
      expect(
        of(ShelfTile.off, decision: _locked, isPlanRead: false),
        ShelfPick.chosen,
      );
    });

    test('confirming: usable, so open', () {
      expect(of(shake, decision: _confirming), ShelfPick.open);
      expect(
        of(shake, chosen: ChallengeKind.shake, decision: _confirming),
        ShelfPick.chosen,
      );
    });

    test('plan unreadable: usable, nothing sold, so open', () {
      expect(of(shake, decision: _unread), ShelfPick.open);
    });

    test('own server without Pro is the free case', () {
      // The access layer answers locked, as in the cloud.
      expect(of(shake, decision: _locked), ShelfPick.locked);
    });

    test('not offered: a plain ring that does nothing', () {
      expect(of(shake, decision: _notOffered), ShelfPick.unread);
    });

    test('the lapsed case: a saved kind shows Off, and its tile is locked', () {
      final chosen = shelfChosenFor(
        saved: ChallengeKind.shake,
        decision: _locked,
      );
      expect(of(shake, chosen: chosen, decision: _locked), ShelfPick.locked);
      expect(
        of(ShelfTile.off, chosen: chosen, decision: _locked),
        ShelfPick.chosen,
      );
    });

    test('No challenge is never locked', () {
      for (final decision in [_open, _locked, _confirming, _unread]) {
        for (final isPlanRead in [true, false]) {
          expect(
            of(ShelfTile.off, decision: decision, isPlanRead: isPlanRead),
            isNot(ShelfPick.locked),
          );
        }
      }
    });

    test('the ring agrees with the tap', () {
      for (final decision in [
        _open,
        _locked,
        _confirming,
        _unread,
        _notOffered,
      ]) {
        for (final isPlanRead in [true, false]) {
          final ring = of(shake, decision: decision, isPlanRead: isPlanRead);
          final answer = shelfTapFor(
            tap: ShelfTap.pick,
            decision: decision,
            isPlanRead: isPlanRead,
          );
          expect(ring == ShelfPick.locked, answer is OpenPaywall);
          expect(ring == ShelfPick.open, answer is DoIt);
        }
      }
    });
  });

  group('the footer', () {
    ShelfFooter of(FeatureDecision decision, {bool isPlanRead = true}) =>
        shelfFooterFor(decision: decision, isPlanRead: isPlanRead);

    test('the wide button is drawn while locked and the plan is read', () {
      expect(of(_locked), ShelfFooter.planButton);
    });

    test('no button while the plan is not read', () {
      expect(of(_locked, isPlanRead: false), ShelfFooter.none);
    });

    test('no button when Pro is held', () {
      expect(of(_open), ShelfFooter.none);
    });

    test('a purchase being confirmed says so and sells nothing', () {
      expect(of(_confirming), ShelfFooter.confirming);
    });

    test('an unreadable plan draws nothing', () {
      expect(of(_unread), ShelfFooter.none);
      expect(of(_notOffered), ShelfFooter.none);
    });
  });
}
