import 'dart:math' as math;
import 'dart:ui';

import 'package:critalarm/core/access/feature_decision.dart';
import 'package:critalarm/core/access/holding.dart';
import 'package:critalarm/core/access/lock_tap_rule.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/incidents/domain/alarm_style/alarm_style_id.dart';
import 'package:critalarm/features/incidents/presentation/alarm_style/alarm_styles.dart';
import 'package:critalarm/features/settings/domain/personalize/look_deck_rules.dart';
import 'package:critalarm/features/settings/presentation/personalize/look/look_phone.dart';
import 'package:critalarm/features/settings/presentation/personalize/passes/look_pass_tone.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _themes = <Brightness, AppColors>{
  Brightness.light: AppColors.light,
  Brightness.dark: AppColors.dark,
};

const _locked = FeatureDecision.locked(Holding.pro);
const _open = FeatureDecision.open();

LookFade _fadeIn(Brightness brightness) {
  final base = _themes[brightness]!;
  final tones = [
    for (final id in lookDeckFor(alarmStyles.map((s) => s.id)))
      lookPassToneFor(lookStyleFor(id), brightness, base),
  ];
  return LookFade(
    grounds: [for (final t in tones) t.ground],
    texts: [for (final t in tones) t.onGround],
    ink: base.inkFixed,
    cream: base.onPanel,
  );
}

void main() {
  final deck = lookDeckFor(alarmStyles.map((s) => s.id));

  group('the deck', () {
    test('holds the fixed looks in registry order, Yours last', () {
      expect(deck, [
        AlarmStyleId.standard,
        AlarmStyleId.minimal,
        AlarmStyleId.terminal,
        AlarmStyleId.redAlert,
        AlarmStyleId.critPanic,
        AlarmStyleId.own,
      ]);
    });

    test('has Yours once, whatever it is handed', () {
      final again = lookDeckFor([...deck, AlarmStyleId.own]);
      expect(again.where((id) => id == AlarmStyleId.own), hasLength(1));
      expect(again.last, AlarmStyleId.own);
    });

    test('opens on the look that rings', () {
      for (final (index, id) in deck.indexed) {
        expect(initialDeckPage(deck, id), index);
      }
    });

    test('a lapsed own look rings Standard, so the deck opens on page 0', () {
      // The gate answers Standard while the own look cannot be drawn.
      expect(initialDeckPage(deck, AlarmStyleId.standard), 0);
    });

    test('a look the deck does not hold opens on page 0', () {
      expect(initialDeckPage([AlarmStyleId.minimal], AlarmStyleId.own), 0);
    });

    test('the page nearest the middle', () {
      expect(centredPage(0.4, 6), 0);
      expect(centredPage(0.6, 6), 1);
      expect(centredPage(-1, 6), 0);
      expect(centredPage(9, 6), 5);
    });
  });

  group('lookActionFor', () {
    LookAction action({
      AlarmStyleId centred = AlarmStyleId.minimal,
      AlarmStyleId inUse = AlarmStyleId.standard,
      FeatureDecision decision = _locked,
      bool isPlanRead = true,
      OwnLookPhase own = OwnLookPhase.none,
    }) => lookActionFor(
      centred: centred,
      inUse: inUse,
      decision: decision,
      isPlanRead: isPlanRead,
      own: own,
    );

    group('the look in use', () {
      test('is a status on every plan', () {
        for (final decision in [
          _locked,
          _open,
          const FeatureDecision.confirming(Holding.pro),
        ]) {
          final a = action(
            centred: AlarmStyleId.standard,
            decision: decision,
          );
          expect(a.control, LookControl.inUse);
          expect(a.keep, const Nothing());
          expect(a.badge, isNull);
          expect(a.showsTryBar, isFalse);
        }
      });

      test('Yours held and in use is a status too', () {
        final a = action(
          centred: AlarmStyleId.own,
          inUse: AlarmStyleId.own,
          decision: _open,
          own: OwnLookPhase.held,
        );
        expect(a.control, LookControl.inUse);
      });
    });

    group('an open look that is not in use', () {
      test('is "Use this look" and keeping saves it', () {
        final a = action(decision: _open);
        expect(a.control, LookControl.use);
        expect(a.keep, const DoIt());
        expect(a.badge, isNull);
        expect(a.showsTryBar, isFalse);
      });

      test('Standard is open on a locked phone', () {
        final a = action(
          centred: AlarmStyleId.standard,
          inUse: AlarmStyleId.minimal,
        );
        expect(a.control, LookControl.use);
        expect(a.keep, const DoIt());
        expect(a.badge, isNull);
        expect(a.showsTryBar, isFalse);
      });

      test('a purchase being confirmed opens the looks and says so', () {
        final a = action(
          decision: const FeatureDecision.confirming(Holding.pro),
        );
        expect(a.control, LookControl.use);
        expect(a.keep, const DoIt());
        expect(a.showsTryBar, isFalse);
        expect(a.showsConfirming, isTrue);
      });

      test('an unread plan that was open before keeps the look usable', () {
        final a = action(decision: const FeatureDecision.unread(Holding.pro));
        expect(a.keep, const DoIt());
        expect(a.badge, isNull);
      });
    });

    group('a locked look', () {
      test('with the plan read shows the try bar, and keeping sells', () {
        final a = action();
        expect(a.control, LookControl.use);
        expect(a.showsTryBar, isTrue);
        expect(a.badge, Holding.pro);
        expect(a.keep, const OpenPaywall(Holding.pro));
      });

      test('names the plan that unlocks it', () {
        final a = action(
          decision: const FeatureDecision.locked(Holding.hosted),
        );
        expect(a.badge, Holding.hosted);
        expect(a.keep, const OpenPaywall(Holding.hosted));
      });

      test('with the plan not read has no badge and no try bar, and waits', () {
        final a = action(isPlanRead: false);
        expect(a.control, LookControl.use);
        expect(a.badge, isNull);
        expect(a.showsTryBar, isFalse);
        expect(a.keep, const WaitForPlan());
      });

      test(
        "on a server of the user's own is a locked look like any other",
        () {
          // The access layer answers locked for looks there, so the rule sees
          // the same input as on the free plan.
          final a = action();
          expect(a.keep, const OpenPaywall(Holding.pro));
          expect(a.showsTryBar, isTrue);
        },
      );

      test('a look that is not offered does nothing', () {
        final a = action(decision: const FeatureDecision.notOffered());
        expect(a.keep, const Nothing());
        expect(a.badge, isNull);
      });

      test('every locked look but Standard sells, none opens a page', () {
        for (final id in deck.where((id) => !id.isFree)) {
          final a = action(
            centred: id,
            own: id == AlarmStyleId.own
                ? OwnLookPhase.saved
                : OwnLookPhase.none,
          );
          expect(a.keep, isA<OpenPaywall>(), reason: id.id);
        }
      });
    });

    group('Yours', () {
      test('with no photo, open, asks for one and keeping goes ahead', () {
        final a = action(centred: AlarmStyleId.own, decision: _open);
        expect(a.control, LookControl.addPhoto);
        expect(a.keep, const DoIt());
        expect(a.badge, isNull);
        expect(a.showsTryBar, isFalse);
      });

      test('with no photo, locked, has the badge and no try bar', () {
        final a = action(centred: AlarmStyleId.own);
        expect(a.control, LookControl.addPhoto);
        expect(a.badge, Holding.pro);
        expect(a.keep, const OpenPaywall(Holding.pro));
        expect(a.showsTryBar, isFalse);
      });

      test('with no photo and the plan not read has no badge and waits', () {
        final a = action(centred: AlarmStyleId.own, isPlanRead: false);
        expect(a.control, LookControl.addPhoto);
        expect(a.badge, isNull);
        expect(a.keep, const WaitForPlan());
      });

      test('with a photo held is a look like the others', () {
        final a = action(
          centred: AlarmStyleId.own,
          decision: _open,
          own: OwnLookPhase.held,
        );
        expect(a.control, LookControl.use);
        expect(a.keep, const DoIt());
      });

      test('with a photo kept and the plan lapsed is a locked look', () {
        final a = action(centred: AlarmStyleId.own, own: OwnLookPhase.saved);
        expect(a.control, LookControl.use);
        expect(a.showsTryBar, isTrue);
        expect(a.badge, Holding.pro);
        expect(a.keep, const OpenPaywall(Holding.pro));
      });

      test('with a photo that cannot be read and the plan open asks again', () {
        final a = action(
          centred: AlarmStyleId.own,
          decision: _open,
          own: OwnLookPhase.saved,
        );
        expect(a.control, LookControl.addPhoto);
        expect(a.keep, const DoIt());
      });
    });

    test("the keep answer is the lock rule's own", () {
      for (final decision in [
        _locked,
        _open,
        const FeatureDecision.confirming(Holding.pro),
        const FeatureDecision.unread(Holding.pro),
        const FeatureDecision.notOffered(),
      ]) {
        for (final isPlanRead in [true, false]) {
          final a = action(decision: decision, isPlanRead: isPlanRead);
          expect(
            a.keep,
            lockTapFor(
              decision: decision,
              isPlanRead: isPlanRead,
              hasTry: false,
              tap: LockTapKind.keep,
            ),
          );
        }
      }
    });
  });

  group('lookHintFor', () {
    LookHint hint({
      FeatureDecision decision = _locked,
      bool isPlanRead = true,
      AlarmStyleId centred = AlarmStyleId.minimal,
      AlarmStyleId inUse = AlarmStyleId.standard,
    }) {
      final a = lookActionFor(
        centred: centred,
        inUse: inUse,
        decision: decision,
        isPlanRead: isPlanRead,
        own: OwnLookPhase.none,
      );
      return lookHintFor(
        action: a,
        decision: decision,
        isPlanRead: isPlanRead,
        deck: deck,
      );
    }

    test('says only swipe while a locked look is tried, the bar says it', () {
      expect(
        hint(),
        const LookHint(LocaleKeys.personalize_passes_look_hint_swipe),
      );
    });

    test('counts the locked positions on the look in use', () {
      expect(
        hint(centred: AlarmStyleId.standard),
        const LookHint(
          LocaleKeys.personalize_passes_look_hint_swipe_locked,
          lockedCount: 5,
        ),
      );
    });

    test('on Yours with no photo, locked, it is not a try', () {
      expect(
        hint(centred: AlarmStyleId.own).key,
        LocaleKeys.personalize_passes_look_hint_swipe_locked,
      );
    });

    test('with nothing to buy it is just swipe', () {
      expect(
        hint(decision: _open),
        const LookHint(LocaleKeys.personalize_passes_look_hint_swipe),
      );
    });

    test('a plan not read sells nothing and tries nothing', () {
      expect(
        hint(isPlanRead: false),
        const LookHint(LocaleKeys.personalize_passes_look_hint_swipe),
      );
    });

    test('a purchase being confirmed is just swipe', () {
      expect(
        hint(decision: const FeatureDecision.confirming(Holding.pro)).key,
        LocaleKeys.personalize_passes_look_hint_swipe,
      );
    });
  });

  group('LookFade', () {
    for (final MapEntry(key: brightness) in _themes.entries) {
      final fade = _fadeIn(brightness);

      test("${brightness.name}: the ground at a whole page is the look's", () {
        for (var i = 0; i < fade.count; i++) {
          expect(fade.groundAt(i.toDouble()), fade.grounds[i]);
          expect(fade.textAt(i.toDouble()), fade.texts[i]);
        }
      });

      test(
        '${brightness.name}: the ground blends Standard to Minimal by the '
        'page fraction',
        () {
          for (final fraction in [0.0, 0.25, 0.5, 0.75, 1.0]) {
            final expected = Color.lerp(
              fade.grounds[0],
              fade.grounds[1],
              fraction,
            );
            expect(fade.groundAt(fraction), expected, reason: '$fraction');
          }
        },
      );

      test(
        '${brightness.name}: from Terminal to Crit panic the ground runs '
        'through Red alert',
        () {
          expect(fade.groundAt(2), fade.grounds[2]);
          for (final fraction in [0.25, 0.5, 0.75]) {
            expect(
              fade.groundAt(2 + fraction),
              Color.lerp(fade.grounds[2], fade.grounds[3], fraction),
            );
            expect(
              fade.groundAt(3 + fraction),
              Color.lerp(fade.grounds[3], fade.grounds[4], fraction),
            );
          }
          expect(fade.groundAt(3), fade.grounds[3]);
          expect(fade.groundAt(4), fade.grounds[4]);
        },
      );

      test('${brightness.name}: between two looks the text is a neutral', () {
        for (final page in [0.25, 0.5, 0.75, 1.5, 2.5, 3.5, 4.5]) {
          final text = fade.textAt(page);
          expect(
            text == fade.ink || text == fade.cream,
            isTrue,
            reason: 'page $page',
          );
          final other = text == fade.ink ? fade.cream : fade.ink;
          final ground = fade.groundAt(page);
          expect(
            ColorContrast.contrastRatio(text, ground),
            greaterThanOrEqualTo(ColorContrast.contrastRatio(other, ground)),
          );
        }
      });

      test('${brightness.name}: the text reads at rest at 4.5 to 1', () {
        for (var i = 0; i < fade.count; i++) {
          expect(
            ColorContrast.contrastRatio(
              fade.textAt(i.toDouble()),
              fade.groundAt(i.toDouble()),
            ),
            greaterThanOrEqualTo(4.5),
            reason: deck[i].id,
          );
        }
      });

      test(
        '${brightness.name}: the text reads at 4.0 to 1 or more on the way '
        'between any two looks',
        () {
          var worst = double.infinity;
          for (var a = 0; a < fade.count; a++) {
            for (var b = 0; b < fade.count; b++) {
              for (var step = 0; step <= 20; step++) {
                final fraction = step / 20;
                final ground = Color.lerp(
                  fade.grounds[a],
                  fade.grounds[b],
                  fraction,
                )!;
                final ink = ColorContrast.contrastRatio(fade.ink, ground);
                final cream = ColorContrast.contrastRatio(fade.cream, ground);
                worst = math.min(worst, math.max(ink, cream));
              }
            }
          }
          expect(worst, greaterThanOrEqualTo(4.0));
        },
      );

      test('${brightness.name}: the text reads on every step of every fade '
          'the deck makes', () {
        for (var page = 0.0; page <= fade.count - 1; page += 0.05) {
          if (LookFade.isAtRest(page)) continue;
          expect(
            ColorContrast.contrastRatio(fade.textAt(page), fade.groundAt(page)),
            greaterThanOrEqualTo(4.0),
            reason: 'page $page',
          );
        }
      });
    }

    test('a page outside the deck holds the first or the last look', () {
      final fade = _fadeIn(Brightness.light);
      expect(fade.groundAt(-2), fade.grounds.first);
      expect(fade.groundAt(40), fade.grounds.last);
      expect(fade.textAt(-2), fade.texts.first);
    });

    test('Standard is alarm red in the light theme and Yours near black', () {
      final fade = _fadeIn(Brightness.light);
      expect(fade.grounds[0], AppColors.light.critCanvas);
      expect(fade.grounds[5].computeLuminance(), lessThan(0.01));
    });
  });

  group('lookPoseAt', () {
    test('nothing rests at an angle', () {
      for (var page = 0; page < 6; page++) {
        for (var index = 0; index < 6; index++) {
          expect(lookPoseAt(index, page.toDouble()).tilt, 0);
        }
      }
    });

    test(
      'the centred phone is whole and its neighbours smaller and dimmer',
      () {
        final centred = lookPoseAt(2, 2);
        expect(centred.scale, 1);
        expect(centred.opacity, 1);
        for (final index in [1, 3]) {
          final pose = lookPoseAt(index, 2);
          expect(pose.scale, neighbourScale);
          expect(pose.opacity, neighbourOpacity);
        }
        expect(neighbourScale, 0.77);
        expect(neighbourOpacity, 0.85);
      },
    );

    test('a phone further out is dimmer than a neighbour, and not by much '
        'less than half', () {
      final near = lookPoseAt(3, 2).opacity;
      final far = lookPoseAt(4, 2).opacity;
      final farther = lookPoseAt(5, 2).opacity;
      expect(far, lessThan(near));
      expect(farther, lessThan(far));
      expect(farther, greaterThanOrEqualTo(0.45));
    });

    test('the pose follows the drag between two pages', () {
      final half = lookPoseAt(2, 1.5);
      final incoming = lookPoseAt(1, 1.5);
      // Half way between 1 and 2 both are at the same distance.
      expect(half.scale, closeTo(incoming.scale, 1e-9));
      expect(half.scale, closeTo(1 - 0.23 * 0.5, 1e-9));
    });

    test('a phone tilts away from the middle in proportion to the drag, '
        'at most 5 degrees', () {
      var last = 0.0;
      for (final page in [2.0, 2.1, 2.2, 2.3, 2.4, 2.5]) {
        final tilt = lookPoseAt(4, page).tilt.abs();
        expect(tilt, greaterThanOrEqualTo(last));
        expect(tilt, lessThanOrEqualTo(deckTiltMax));
        last = tilt;
      }
      // Right of the middle tilts clockwise, left of it counter-clockwise.
      expect(lookPoseAt(4, 2.5).tilt, greaterThan(0));
      expect(lookPoseAt(0, 2.5).tilt, lessThan(0));
      for (var index = 0; index < 6; index++) {
        for (var step = 0; step <= 100; step++) {
          expect(
            lookPoseAt(index, step / 20).tilt.abs(),
            lessThanOrEqualTo(deckTiltMax),
          );
        }
      }
    });

    test('the tilt ends at zero when the deck comes to rest', () {
      expect(lookPoseAt(3, 3).tilt, 0);
      expect(lookPoseAt(4, 3).tilt, 0);
      expect(lookPoseAt(2, 3).tilt, 0);
    });
  });

  group('lookRock', () {
    test('is upright at t = 0 and swings 1.5 degrees either side', () {
      expect(lookRock(0), 0);
      expect(lookRock(lookRockPeriod / 4), closeTo(1.5, 1e-9));
      expect(lookRock(3 * lookRockPeriod / 4), closeTo(-1.5, 1e-9));
    });

    test('repeats every period and ends where it started', () {
      expect(lookRock(lookRockPeriod), closeTo(0, 1e-9));
      expect(lookRock(1.7), closeTo(lookRock(1.7 + lookRockPeriod), 1e-9));
    });

    test('the resting frame is upright', () {
      expect(lookRock(0.3, isStill: true), 0);
    });
  });

  group('lookPhoneSize', () {
    test('is 204 points wide on a 390 wide phone with room to spare', () {
      final size = lookPhoneSize(
        columnWidth: 390,
        availableHeight: 600,
        aspect: 390 / 844,
      );
      expect(size.width, closeTo(204, 1e-9));
      expect(size.height, closeTo(204 * 844 / 390, 1e-9));
    });

    test('keeps the shape of the screen when the room is short', () {
      final size = lookPhoneSize(
        columnWidth: 390,
        availableHeight: 360,
        aspect: 390 / 844,
      );
      expect(size.height, 360);
      expect(size.width / size.height, closeTo(390 / 844, 1e-9));
    });

    test('is narrower on a narrower phone', () {
      final size = lookPhoneSize(
        columnWidth: 320,
        availableHeight: 600,
        aspect: 320 / 640,
      );
      expect(size.width, closeTo(204 * 320 / 390, 1e-9));
    });

    test('a column wider than a phone does not make the phone wider', () {
      final size = lookPhoneSize(
        columnWidth: 560,
        availableHeight: 900,
        aspect: 390 / 844,
      );
      expect(size.width, closeTo(204, 1e-9));
    });

    test('a display wider than tall is held to a share of the column', () {
      final size = lookPhoneSize(
        columnWidth: 560,
        availableHeight: 900,
        aspect: 1024 / 768,
      );
      expect(size.width, closeTo(560 * 0.56, 1e-9));
    });

    test('is never smaller than a thumbnail', () {
      final size = lookPhoneSize(
        columnWidth: 390,
        availableHeight: 10,
        aspect: 0.5,
      );
      expect(size.height, 120);
    });

    test('a neighbour clears the middle phone by the same gap at any size', () {
      for (final width in [140.0, 204.0, 280.0]) {
        final step = lookPhoneStep(width);
        final gap = step - width / 2 - width * neighbourScale / 2;
        expect(gap, closeTo(24, 1e-9));
      }
    });
  });

  group('lookScreenSize', () {
    test('a phone held upright keeps its size', () {
      expect(lookScreenSize(const Size(390, 844)), const Size(390, 844));
    });

    test('a phone on its side is laid out upright', () {
      expect(lookScreenSize(const Size(844, 390)), const Size(390, 844));
    });

    test('a short and wide display is laid out upright', () {
      expect(lookScreenSize(const Size(640, 320)), const Size(320, 640));
    });

    test('a tablet gets a phone shape, in either direction', () {
      expect(lookScreenSize(const Size(1024, 768)), const Size(390, 844));
      expect(lookScreenSize(const Size(768, 1024)), const Size(390, 844));
    });
  });

  group('lookDotColor', () {
    test('the dot in the middle is the text colour', () {
      for (final brightness in Brightness.values) {
        final fade = _fadeIn(brightness);
        for (var i = 0; i < fade.count; i++) {
          expect(
            lookDotColor(text: fade.texts[i], ground: fade.grounds[i], near: 1),
            fade.texts[i],
          );
        }
      }
    });

    test('the others keep 3 to 1 with the ground of every look', () {
      for (final brightness in Brightness.values) {
        final fade = _fadeIn(brightness);
        for (var i = 0; i < fade.count; i++) {
          final dot = lookDotColor(
            text: fade.texts[i],
            ground: fade.grounds[i],
            near: 0,
          );
          expect(
            ColorContrast.contrastRatio(dot, fade.grounds[i]),
            greaterThanOrEqualTo(lookDotMinContrast),
            reason: 'look $i, $brightness',
          );
        }
      }
    });
  });
}
