import 'dart:ui';

import 'package:critalarm/core/ui_sound/paywall_cues.dart';
import 'package:critalarm/features/paywall/domain/entities/paywall_benefit.dart';
import 'package:critalarm/features/paywall/domain/entities/paywall_preview_id.dart';
import 'package:critalarm/features/paywall/domain/entities/paywall_product.dart';
import 'package:critalarm/features/paywall/domain/paywall_lead.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_hero.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_tone.dart';
import 'package:critalarm/features/paywall/presentation/layouts/reel/reel_rules.dart';
import 'package:critalarm/features/paywall/presentation/layouts/reel/reel_scene.dart';
import 'package:flutter_test/flutter_test.dart';

HeroLoop _loop() => HeroLoop(const [
  PaywallPreviewId.topics,
  PaywallPreviewId.pushes,
  PaywallPreviewId.history,
  PaywallPreviewId.appIcons,
], holdSeconds: reelHoldSeconds);

void main() {
  group('the tone of a scene', () {
    test('no two neighbours share one, round the loop included', () {
      for (var count = 2; count <= 9; count++) {
        for (var i = 0; i < count - 1; i++) {
          expect(reelToneFor(i), isNot(reelToneFor(i + 1)));
        }
      }
      // Hosted has four scenes and Pro five: the last and the first differ.
      expect(reelToneFor(3), isNot(reelToneFor(0)));
      expect(reelToneFor(4), isNot(reelToneFor(0)));
    });

    test('the first scene is not the canvas the buy block sits on', () {
      expect(reelToneFor(0), isNot(ReelTone.canvas));
    });

    test('only the canvas keeps its own atmosphere colours', () {
      expect(reelAirFor(ReelTone.canvas), PaywallTone.canvas);
      expect(reelAirFor(ReelTone.panel), PaywallTone.panel);
      for (final tone in [ReelTone.cream, ReelTone.high, ReelTone.surface]) {
        expect(reelAirFor(tone), PaywallTone.surface);
      }
    });
  });

  group('the story bars', () {
    test('seen scenes are full, the playing one fills, the rest wait', () {
      expect(reelBarFill(0, active: 2, progress: 0.4), 1);
      expect(reelBarFill(1, active: 2, progress: 0.4), 1);
      expect(reelBarFill(2, active: 2, progress: 0.4), 0.4);
      expect(reelBarFill(3, active: 2, progress: 0.4), 0);
    });

    test('a bar never fills past its ends', () {
      expect(reelBarFill(0, active: 0, progress: 1.4), 1);
      expect(reelBarFill(0, active: 0, progress: -0.2), 0);
    });

    test('they follow the loop: the second bar fills in the second turn', () {
      final loop = _loop();
      final second = loop.scenes[1];
      final frame = loop.frameAt(
        loop.entranceEnd + second.start + second.script.seconds / 2,
      );
      expect(frame.activeIndex, 1);
      expect(
        reelBarFill(1, active: frame.activeIndex, progress: frame.progress),
        closeTo(0.5, 0.01),
      );
    });

    test('the resting frame is the first scene with its bar full', () {
      final rest = _loop().rest;
      expect(rest.activeIndex, 0);
      expect(
        reelBarFill(0, active: rest.activeIndex, progress: rest.progress),
        1,
      );
      expect(
        reelBarFill(1, active: rest.activeIndex, progress: rest.progress),
        0,
      );
    });
  });

  group('the hand', () {
    test('the right half is next and the left half is previous', () {
      expect(reelTapStep(300, 390), 1);
      expect(reelTapStep(195, 390), 1);
      expect(reelTapStep(194, 390), -1);
      expect(reelTapStep(10, 390), -1);
    });

    test('a short touch is a tap and a long one is a hold', () {
      expect(reelIsHold(const Duration(milliseconds: 120)), isFalse);
      expect(reelIsHold(reelHoldAfter), isTrue);
      expect(reelIsHold(const Duration(seconds: 3)), isTrue);
    });

    test('a tap on the left of the first scene wraps to the last', () {
      final loop = _loop();
      final hand = loop.touch(loop.entranceEnd + 0.5, step: -1);
      expect(hand!.index, 3);
      expect(hand.direction, -1);
    });

    test('a chosen scene holds for less time than the kit holds', () {
      final loop = _loop();
      expect(loop.holdSeconds, reelHoldSeconds);
      expect(reelHoldSeconds, lessThan(heroHandHoldSeconds));
    });
  });

  group('the push', () {
    test('the next scene comes from the right and the old one leaves left', () {
      final start = reelPushAt(0, 1);
      expect(start.into, 1);
      expect(start.out, 0);
      final end = reelPushAt(1, 1);
      expect(end.into, 0);
      expect(end.out, -1);
    });

    test('the previous scene comes from the left', () {
      final half = reelPushAt(0.5, -1);
      expect(half.into, -0.5);
      expect(half.out, 0.5);
    });

    test('a scene the loop brought comes from the right', () {
      expect(reelPushAt(0.25, 0).into, 0.75);
      expect(reelPushAt(0.25, 0).out, -0.25);
    });

    test('the two scenes always touch: one scene width apart', () {
      for (final eased in [0.0, 0.3, 0.8, 1.0]) {
        for (final direction in [-1, 0, 1]) {
          final push = reelPushAt(eased, direction);
          expect((push.into - push.out).abs(), closeTo(1, 1e-9));
        }
      }
    });
  });

  group('the frames of the two scenes', () {
    test('no scene is leaving at rest, in the entrance or mid turn', () {
      final loop = _loop();
      expect(reelLeaving(loop.rest), isNull);
      expect(reelLeaving(loop.frameAt(0.4)), isNull);
      expect(reelLeaving(loop.frameAt(loop.entranceEnd + 1)), isNull);
    });

    test('as the second turn starts the first scene is the one leaving', () {
      final loop = _loop();
      final t = loop.entranceEnd + loop.scenes[1].start + 0.1;
      final frame = loop.frameAt(t);
      final leaving = reelLeaving(frame)!;
      expect(leaving.activeIndex, 0);
      expect(leaving.previous, isNull);
      expect(leaving.cardEnter, 1);
      expect(leaving.entrance, 1);
      expect(leaving.face, frame.fromFace);
      expect(leaving.playFrom, frame.previousPlayFrom);

      final now = reelSettled(frame);
      expect(now.activeIndex, 1);
      expect(now.previous, isNull);
      expect(now.cardEnter, 1);
      expect(now.face, frame.face);
      expect(now.playFrom, frame.playFrom);
      expect(now.progress, frame.progress);
    });

    test('once the push is over only one scene is drawn', () {
      final loop = _loop();
      final t = loop.entranceEnd + loop.scenes[1].start + heroCardBlend + 0.01;
      expect(reelLeaving(loop.frameAt(t)), isNull);
    });
  });

  group('the room of the stage', () {
    test('it takes what the bars, the words and the gaps leave', () {
      final sizes = ReelSizes.of(isCompact: false);
      expect(
        reelStageHeight(height: 600, words: 100, sizes: sizes),
        600 - reelBarsHeight - 100 - sizes.stageGap - sizes.foot - reelSceneGap,
      );
    });

    test('it is never under zero', () {
      expect(
        reelStageHeight(
          height: 120,
          words: 300,
          sizes: ReelSizes.of(isCompact: true),
        ),
        0,
      );
    });

    test('the smallest stage is the room the smallest mascot needs', () {
      expect(reelStageMinHeight, heroTopRoom + heroMascotMin);
      // The stage's own arrangement agrees: at the minimum it draws the
      // mascot, a point under it draws nothing.
      expect(
        heroArrangementFor(const Size(320, reelStageMinHeight)).kind,
        HeroStageKind.mascot,
      );
      expect(
        heroArrangementFor(const Size(320, reelStageMinHeight - 1)).kind,
        HeroStageKind.none,
      );
    });

    test('a room under the smallest stage is no stage at all', () {
      final sizes = ReelSizes.of(isCompact: false);
      final fixed =
          reelBarsHeight + 100 + sizes.stageGap + sizes.foot + reelSceneGap;
      double room(double leftOver) =>
          reelStageHeight(height: fixed + leftOver, words: 100, sizes: sizes);
      expect(room(reelStageMinHeight - 1), 0);
      expect(room(1), 0);
      expect(room(0), 0);
      expect(room(reelStageMinHeight), reelStageMinHeight);
      expect(room(reelStageMinHeight + 1), reelStageMinHeight + 1);
    });

    test('a room that held a readable picture is unchanged', () {
      final sizes = ReelSizes.of(isCompact: false);
      // Every height from the smallest stage up is the plain sum, as it was
      // before the rule: the phone sizes the reel is checked on included.
      for (final height in [480.0, 560.0, 640.0, 700.0, 780.0]) {
        for (final words in [100.0, 160.0, 220.0]) {
          final plain =
              height -
              reelBarsHeight -
              words -
              sizes.stageGap -
              sizes.foot -
              reelSceneGap;
          final expected = plain < reelStageMinHeight
              ? 0
              : plain.floorToDouble();
          expect(
            reelStageHeight(height: height, words: words, sizes: sizes),
            expected,
            reason: '$height, $words',
          );
        }
      }
    });

    test('the line takes room from the stage and can take all of it', () {
      final sizes = ReelSizes.of(isCompact: false);
      final withLine = reelStageHeight(
        height: 400,
        words: 150,
        sizes: sizes,
        line: 130,
      );
      expect(withLine, 0);
      expect(
        reelStageHeight(height: 400, words: 150, sizes: sizes, line: 20),
        greaterThanOrEqualTo(reelStageMinHeight),
      );
    });
  });

  group('the motion of the reel', () {
    test('the stage picks its own variants', () {
      expect(reelMotion.atmosphere, HeroAtmosphereStyle.rings);
      expect(reelMotion.entrance, HeroEntranceStyle.slide);
      expect(reelMotion.idle, HeroIdleStyle.benefitHop);
      expect(reelMotion.arrival, HeroCardArrival.slideThrough);
    });

    test('after an intro the mascot is in its place on the first frame', () {
      expect(reelPreludeFor(followsIntro: false), 0);
      final loop = HeroLoop(const [
        PaywallPreviewId.topics,
        PaywallPreviewId.pushes,
      ], prelude: reelPreludeFor(followsIntro: true));
      final first = loop.frameAt(0);
      final pose = heroEntrancePose(
        reelMotion.entrance,
        first.entrance,
        size: 160,
      );
      expect(pose.dx, closeTo(0, 1e-9));
      expect(pose.opacity, 1);
      expect(loop.entranceEnd, lessThan(heroEntranceSeconds));
    });

    test('the entrance is heard as the mascot lands, alone only', () {
      final alone = reelCues(prelude: reelPreludeFor(followsIntro: false));
      expect(alone.single.cue, PaywallCue.pop);
      expect(alone.single.at, inExclusiveRange(0, heroEntranceSeconds));
      // After an intro the mascot is there before the clock starts.
      final after = reelCues(prelude: reelPreludeFor(followsIntro: true));
      expect(after.single.at, lessThan(0));
    });
  });

  group('the first scene under a lead', () {
    const servers = PaywallLead(
      benefit: PaywallBenefitId.topics,
      headlineKey: 'paywall_lead.servers_headline',
      lineKey: 'paywall_lead.servers_line',
      topicName: 'payments-db',
    );
    const reaches = PaywallLead(
      benefit: PaywallBenefitId.reliabilityChecks,
      headlineKey: 'paywall_lead.reaches_headline',
      lineKey: 'weekly_check.what_line',
    );
    final hosted = paywallBenefitsFor(PaywallProduct.hosted);
    final pro = paywallBenefitsFor(PaywallProduct.pro);

    PaywallBenefit benefit(List<PaywallBenefit> of, PaywallBenefitId id) =>
        of.firstWhere((b) => b.id == id);

    test('only the first scene reads the lead', () {
      expect(reelLeadAt(0, servers), servers);
      for (var i = 1; i < 6; i++) {
        expect(reelLeadAt(i, servers), isNull);
      }
      expect(reelLeadAt(0, null), isNull);
    });

    test('the first scene takes its headline, line and eyebrow from the '
        'lead', () {
      expect(
        reelHeadlineFor(
          benefit(hosted, PaywallBenefitId.topics),
          lead: reelLeadAt(0, servers),
        ),
        'Every server can wake you',
      );
      expect(
        reelHeadlineFor(
          benefit(hosted, PaywallBenefitId.reliabilityChecks),
          lead: reelLeadAt(0, reaches),
        ),
        'Know it still reaches you',
      );
      // The number comes from the one place Hosted numbers are kept.
      expect(
        reelLineFor(servers),
        'Free rings 2 critical topics. Cloud rings all of them.',
      );
      expect(
        reelLineFor(reaches),
        'Checks each week whether a push reaches this phone.',
      );
      expect(
        reelEyebrowFor(isHosted: true, lead: reelLeadAt(0, servers)),
        'With Cloud',
      );
      expect(
        reelEyebrowFor(isHosted: false, lead: reelLeadAt(0, reaches)),
        'With Pro',
      );
    });

    test('a lead with its own eyebrow replaces it', () {
      const own = PaywallLead(
        benefit: PaywallBenefitId.topics,
        eyebrowKey: 'paywall_lead.skip_hint',
      );
      expect(reelEyebrowFor(isHosted: true, lead: own), 'tap anywhere to skip');
      expect(
        reelEyebrowFor(isHosted: true, lead: reelLeadAt(1, own)),
        'With Cloud',
      );
    });

    test('later scenes read their own benefit, lead or not', () {
      for (final lead in [servers, reaches, null]) {
        expect(
          reelHeadlineFor(
            benefit(hosted, PaywallBenefitId.pushes),
            lead: reelLeadAt(1, lead),
          ),
          reelHeadlineFor(benefit(hosted, PaywallBenefitId.pushes)),
        );
        expect(
          reelEyebrowFor(isHosted: true, lead: reelLeadAt(2, lead)),
          'With Cloud',
        );
      }
      expect(
        reelHeadlineFor(benefit(hosted, PaywallBenefitId.pushes)),
        '1,000 high priority pushes a day',
      );
    });

    test("with no lead the words are the benefit's, as before", () {
      expect(
        reelHeadlineFor(benefit(hosted, PaywallBenefitId.topics)),
        'Unlimited critical topics',
      );
      expect(
        reelHeadlineFor(benefit(hosted, PaywallBenefitId.reliabilityChecks)),
        'Weekly delivery check',
      );
      expect(reelLineFor(null), isNull);
      expect(
        reelHeadlineFor(benefit(pro, PaywallBenefitId.widgets)),
        'Widgets on your home screen',
      );
    });

    test('a lead with no line leaves no room under the picture', () {
      expect(
        reelLineFor(const PaywallLead(benefit: PaywallBenefitId.widgets)),
        isNull,
      );
      final sizes = ReelSizes.of(isCompact: false);
      final bare = reelStageHeight(height: 700, words: 120, sizes: sizes);
      expect(
        reelStageHeight(height: 700, words: 120, sizes: sizes),
        bare,
      );
      // A line takes its height and its gap out of the stage, no more.
      expect(
        reelStageHeight(height: 700, words: 120, sizes: sizes, line: 40),
        bare - 40,
      );
    });
  });
}
