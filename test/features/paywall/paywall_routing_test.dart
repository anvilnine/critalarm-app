import 'package:critalarm/core/paywall/paywall_headline.dart';
import 'package:critalarm/core/paywall/paywall_intro.dart';
import 'package:critalarm/core/paywall/paywall_layout.dart';
import 'package:critalarm/core/paywall/paywall_layout_setting.dart';
import 'package:critalarm/core/paywall/paywall_outro.dart';
import 'package:critalarm/core/paywall/paywall_source.dart';
import 'package:critalarm/core/paywall/paywall_thanks.dart';
import 'package:critalarm/features/paywall/domain/entities/paywall_benefit.dart';
import 'package:critalarm/features/paywall/domain/entities/paywall_product.dart';
import 'package:critalarm/features/paywall/domain/lock_source.dart';
import 'package:critalarm/features/paywall/domain/paywall_routing.dart';
import 'package:critalarm/features/pro_pack/domain/pro_pack_analytics.dart';
import 'package:flutter_test/flutter_test.dart';

const PaywallProduct _hosted = PaywallProduct.hosted;
const PaywallProduct _pro = PaywallProduct.pro;

final Set<PaywallBenefitId> _all = PaywallBenefitId.values.toSet();

PaywallLayoutSetting _pin(PaywallLayoutId layout) =>
    PaywallLayoutSetting.pinned(layout);

/// What opens, as the door asks. With nothing passed this is a store
/// build: no Developer options value of any kind. By default every benefit
/// is listed, so a lead is never dropped.
PaywallOpening _open(
  PaywallProduct product,
  PaywallPlace place, {
  PaywallLayoutSetting? developer,
  PaywallIntroId? developerIntro,
  PaywallThanksId? developerThanks,
  PaywallOutroId? developerOutro,
  bool hasSeenFalseAlarm = false,
  Set<PaywallBenefitId>? listed,
  LeavingChoice? leaving,
}) => paywallOpeningFor(
  product: product,
  place: place,
  developer: developer,
  developerIntro: developerIntro,
  developerThanks: developerThanks,
  developerOutro: developerOutro,
  hasSeenFalseAlarm: hasSeenFalseAlarm,
  listedBenefits: listed ?? _all,
  leaving: leaving,
);

/// The places a product has no benefit of its own for the lead of. Such a
/// pair opens the product's plan place: a Hero with no lead.
///
/// Written out here and not worked out from the table, so a lead that goes
/// missing from a product's list fails a test.
const Map<PaywallProduct, Set<PaywallPlace>> _noOwnBenefit = {
  PaywallProduct.pro: {
    PaywallPlace.criticalLimit,
    PaywallPlace.history,
    PaywallPlace.appIcons,
    PaywallPlace.weeklyCheck,
    PaywallPlace.planEnding,
    PaywallPlace.planEnded,
  },
  PaywallProduct.hosted: {
    PaywallPlace.widgets,
    PaywallPlace.ownSounds,
    PaywallPlace.alarmLook,
    PaywallPlace.challenge,
  },
};

/// The place [place] opens for [product]: itself, or the plan place.
PaywallPlace _opens(PaywallProduct product, PaywallPlace place) =>
    _noOwnBenefit[product]!.contains(place) ? PaywallPlace.plan : place;

Set<PaywallBenefitId> _built(PaywallProduct product) => {
  for (final b in paywallBenefitsFor(product)) b.id,
};

void main() {
  group('places', () {
    test('every Hosted source has its place', () {
      const expected = <PaywallSource, PaywallPlace>{
        PaywallSource.createTopicCard: PaywallPlace.criticalLimit,
        PaywallSource.historyOlder: PaywallPlace.history,
        PaywallSource.history: PaywallPlace.history,
        PaywallSource.widgetLocked: PaywallPlace.widgets,
        PaywallSource.homeWidgets: PaywallPlace.widgets,
        PaywallSource.personalizeWidgets: PaywallPlace.widgets,
        PaywallSource.appIcon: PaywallPlace.appIcons,
        PaywallSource.personalizeAppIcon: PaywallPlace.appIcons,
        PaywallSource.personalizeSound: PaywallPlace.ownSounds,
        PaywallSource.reliability: PaywallPlace.weeklyCheck,
        PaywallSource.settingsPlan: PaywallPlace.plan,
        PaywallSource.settingsSearch: PaywallPlace.plan,
        PaywallSource.direct: PaywallPlace.plan,
        PaywallSource.askSheet: PaywallPlace.nudge,
        PaywallSource.homeDay0Card: PaywallPlace.nudge,
        PaywallSource.onboardingOffer: PaywallPlace.nudge,
        PaywallSource.reminderMorningAfter: PaywallPlace.nudge,
        PaywallSource.reminderProLater: PaywallPlace.nudge,
        PaywallSource.planSheetEnding: PaywallPlace.planEnding,
        PaywallSource.planSheetEnded: PaywallPlace.planEnded,
      };
      for (final source in PaywallSource.values) {
        expect(expected[source], isNotNull, reason: '$source has no row');
        expect(paywallPlaceOf(source), expected[source], reason: '$source');
      }
      expect(expected.length, PaywallSource.values.length);
    });

    test('every Pro source has its place', () {
      const expected = <ProPackSheetSource, PaywallPlace>{
        ProPackSheetSource.createTopicCard: PaywallPlace.criticalLimit,
        ProPackSheetSource.history: PaywallPlace.history,
        ProPackSheetSource.historyOlder: PaywallPlace.history,
        ProPackSheetSource.homeWidgets: PaywallPlace.widgets,
        ProPackSheetSource.widgetLocked: PaywallPlace.widgets,
        ProPackSheetSource.personalizeWidgets: PaywallPlace.widgets,
        ProPackSheetSource.appIcon: PaywallPlace.appIcons,
        ProPackSheetSource.personalizeAppIcon: PaywallPlace.appIcons,
        ProPackSheetSource.personalizeSound: PaywallPlace.ownSounds,
        ProPackSheetSource.sounds: PaywallPlace.ownSounds,
        ProPackSheetSource.personalizeLook: PaywallPlace.alarmLook,
        ProPackSheetSource.topicLook: PaywallPlace.alarmLook,
        ProPackSheetSource.personalizeChallenge: PaywallPlace.challenge,
        ProPackSheetSource.topicChallenge: PaywallPlace.challenge,
        ProPackSheetSource.reliability: PaywallPlace.weeklyCheck,
        ProPackSheetSource.settingsPlan: PaywallPlace.plan,
        ProPackSheetSource.direct: PaywallPlace.plan,
      };
      for (final source in ProPackSheetSource.values) {
        expect(expected[source], isNotNull, reason: '$source has no row');
        expect(paywallPlaceOfPro(source), expected[source], reason: '$source');
      }
      expect(expected.length, ProPackSheetSource.values.length);
    });
  });

  group('every locked place opens a layout with no setting of any kind', () {
    // The rows a store build opens. A source that is missing here fails the
    // test, so a new source cannot ship without a layout.
    test('every Hosted source', () {
      for (final source in PaywallSource.values) {
        final opening = _open(_hosted, paywallPlaceOf(source));
        expect(
          opening.layout,
          paywallRowFor(_opens(_hosted, paywallPlaceOf(source))).layout,
          reason: '$source',
        );
        expect(PaywallLayoutId.values, contains(opening.layout));
        expect(opening.layout, isNot(PaywallLayoutId.doors), reason: '$source');
      }
    });

    test('every Pro source', () {
      for (final source in ProPackSheetSource.values) {
        final opening = _open(_pro, paywallPlaceOfPro(source));
        expect(
          opening.layout,
          paywallRowFor(_opens(_pro, paywallPlaceOfPro(source))).layout,
          reason: '$source',
        );
        expect(opening.layout, isNot(PaywallLayoutId.doors), reason: '$source');
      }
    });

    test('every lock, for the product it offers and for the other one', () {
      for (final lock in LockSource.values) {
        final hosted = _open(_hosted, paywallPlaceOf(lock.hosted));
        final pro = _open(_pro, paywallPlaceOfPro(lock.pro));
        expect(
          PaywallLayoutId.values,
          contains(hosted.layout),
          reason: '$lock',
        );
        expect(PaywallLayoutId.values, contains(pro.layout), reason: '$lock');
      }
    });

    test('the answer is never null: the type has no shipped surface', () {
      // Compile-time: `.layout` on a nullable answer would not compile.
      expect(_open(_pro, PaywallPlace.plan).layout, PaywallLayoutId.hero);
    });
  });

  group('the table', () {
    test('each place has its row, with every benefit listed', () {
      const expected =
          <
            PaywallPlace,
            (
              PaywallLayoutId,
              PaywallBenefitId?,
              PaywallIntroId,
              PaywallHeadlineVariant,
            )
          >{
            PaywallPlace.criticalLimit: (
              PaywallLayoutId.sheet,
              PaywallBenefitId.topics,
              PaywallIntroId.falseAlarm,
              PaywallHeadlineVariant.none,
            ),
            PaywallPlace.history: (
              PaywallLayoutId.proof,
              PaywallBenefitId.history,
              PaywallIntroId.none,
              PaywallHeadlineVariant.none,
            ),
            PaywallPlace.widgets: (
              PaywallLayoutId.sheet,
              PaywallBenefitId.widgets,
              PaywallIntroId.none,
              PaywallHeadlineVariant.none,
            ),
            PaywallPlace.appIcons: (
              PaywallLayoutId.sheet,
              PaywallBenefitId.appIcons,
              PaywallIntroId.none,
              PaywallHeadlineVariant.none,
            ),
            PaywallPlace.ownSounds: (
              PaywallLayoutId.sheet,
              PaywallBenefitId.customSounds,
              PaywallIntroId.none,
              PaywallHeadlineVariant.none,
            ),
            PaywallPlace.alarmLook: (
              PaywallLayoutId.sheet,
              PaywallBenefitId.customAlarmScreens,
              PaywallIntroId.none,
              PaywallHeadlineVariant.none,
            ),
            PaywallPlace.challenge: (
              PaywallLayoutId.sheet,
              PaywallBenefitId.wakeUpChallenges,
              PaywallIntroId.none,
              PaywallHeadlineVariant.none,
            ),
            PaywallPlace.weeklyCheck: (
              PaywallLayoutId.proof,
              PaywallBenefitId.reliabilityChecks,
              PaywallIntroId.none,
              PaywallHeadlineVariant.none,
            ),
            PaywallPlace.plan: (
              PaywallLayoutId.hero,
              null,
              PaywallIntroId.none,
              PaywallHeadlineVariant.none,
            ),
            PaywallPlace.nudge: (
              PaywallLayoutId.reel,
              null,
              PaywallIntroId.none,
              PaywallHeadlineVariant.none,
            ),
            // Until the leaving paywall is built this opens Wipe, as the
            // ended plan does. Part 2 swaps it for Receipt or Wipe by the
            // person's numbers.
            PaywallPlace.planEnding: (
              PaywallLayoutId.wipe,
              PaywallBenefitId.history,
              PaywallIntroId.none,
              PaywallHeadlineVariant.leaving,
            ),
            PaywallPlace.planEnded: (
              PaywallLayoutId.wipe,
              PaywallBenefitId.history,
              PaywallIntroId.none,
              PaywallHeadlineVariant.ended,
            ),
          };
      for (final place in PaywallPlace.values) {
        final row = expected[place];
        expect(row, isNotNull, reason: '$place has no expected row');
        expect(paywallRowFor(place).layout, row!.$1, reason: '$place row');
        expect(paywallRowFor(place).lead, row.$2, reason: '$place row lead');
        // Hosted opens the row itself wherever it has the row's lead.
        if (_noOwnBenefit[_hosted]!.contains(place)) continue;
        final opening = _open(_hosted, place);
        expect(opening.layout, row.$1, reason: '$place layout');
        expect(opening.lead, row.$2, reason: '$place lead');
        expect(opening.intro, row.$3, reason: '$place intro');
        expect(opening.headline, row.$4, reason: '$place headline');
      }
      expect(expected.length, PaywallPlace.values.length);
    });

    test('Pro reads the same table, where it has the lead', () {
      for (final place in PaywallPlace.values) {
        final row = paywallRowFor(_opens(_pro, place));
        final pro = _open(_pro, place);
        expect(pro.layout, row.layout, reason: '$place');
        expect(pro.lead, row.lead, reason: '$place');
        expect(pro.headline, row.headline, reason: '$place');
        // Where both have the lead the two products open the same thing.
        if (_noOwnBenefit[_pro]!.contains(place) ||
            _noOwnBenefit[_hosted]!.contains(place)) {
          continue;
        }
        final hosted = _open(_hosted, place);
        expect(pro.layout, hosted.layout, reason: '$place');
        expect(pro.lead, hosted.lead, reason: '$place');
        expect(pro.headline, hosted.headline, reason: '$place');
      }
    });

    test('a pair with no benefit of its own opens the plan place, and '
        'no other', () {
      for (final product in PaywallProduct.values) {
        final plan = paywallRowFor(PaywallPlace.plan);
        for (final place in _noOwnBenefit[product]!) {
          final opening = _open(product, place, listed: _built(product));
          expect(opening.layout, plan.layout, reason: '$product $place');
          expect(opening.lead, isNull, reason: '$product $place');
          expect(opening.intro, plan.intro, reason: '$product $place');
          expect(opening.headline, plan.headline, reason: '$product $place');
        }
      }
    });
  });

  group('every place a source reaches', () {
    // What this build lists is what the door passes in. Where the table
    // names a lead the product lists, it is kept. Where it names one the
    // product has no benefit for, the pair is in `_noOwnBenefit` and opens
    // the plan place. Nothing else is dropped.
    void check(PaywallProduct product, Iterable<PaywallPlace> places) {
      final built = _built(product);
      for (final place in places) {
        final row = paywallRowFor(place);
        final opening = _open(product, place, listed: built);
        final reason = '${product.key} $place';
        final lead = row.lead;
        if (lead == null) {
          expect(opening.lead, isNull, reason: reason);
        } else if (_noOwnBenefit[product]!.contains(place)) {
          expect(built, isNot(contains(lead)), reason: reason);
          expect(opening.layout, PaywallLayoutId.hero, reason: reason);
          expect(opening.lead, isNull, reason: reason);
        } else {
          expect(built, contains(lead), reason: '$reason names $lead');
          expect(opening.layout, row.layout, reason: reason);
          expect(opening.lead, lead, reason: reason);
        }
      }
    }

    test('every Pro source: the lead is in the Pro list or the plan opens', () {
      check(_pro, {
        for (final s in ProPackSheetSource.values) paywallPlaceOfPro(s),
      });
    });

    test('every Hosted source: the lead is in the Hosted list or the plan '
        'opens', () {
      check(_hosted, {for (final s in PaywallSource.values) paywallPlaceOf(s)});
    });

    test('every place, for both products', () {
      for (final product in PaywallProduct.values) {
        check(product, PaywallPlace.values);
      }
    });

    test('a Sheet or a Proof always has a lead the product lists', () {
      for (final product in PaywallProduct.values) {
        final built = _built(product);
        for (final place in PaywallPlace.values) {
          final opening = _open(product, place, listed: built);
          if (opening.layout != PaywallLayoutId.sheet &&
              opening.layout != PaywallLayoutId.proof) {
            continue;
          }
          expect(opening.lead, isNotNull, reason: '${product.key} $place');
          expect(
            built,
            contains(opening.lead),
            reason: '${product.key} $place',
          );
        }
      }
    });

    test('the pairs with no benefit of their own are the ones the table '
        'says', () {
      for (final product in PaywallProduct.values) {
        final expected = {
          for (final place in PaywallPlace.values)
            if (paywallRowFor(place).lead case final lead?)
              if (!paywallBenefitsFor(
                product,
              ).any((b) => b.id == lead))
                place,
        };
        expect(_noOwnBenefit[product], expected, reason: product.key);
      }
    });
  });

  group('lead falls back', () {
    test('a lead the product does not list is dropped, the layout stays', () {
      final listed = _all.difference({PaywallBenefitId.history});
      final opening = _open(_hosted, PaywallPlace.history, listed: listed);
      expect(opening.layout, PaywallLayoutId.proof);
      expect(opening.lead, isNull);
    });

    test('widgets lead on Pro is kept when Pro lists it', () {
      final listed = {for (final b in paywallBenefitsFor(_pro)) b.id};
      final opening = _open(_pro, PaywallPlace.widgets, listed: listed);
      expect(opening.lead, PaywallBenefitId.widgets);
    });

    test('a weekly check on Pro opens the plan place: Hosted unlocks it', () {
      final listed = {for (final b in paywallBenefitsFor(_pro)) b.id};
      expect(listed, isNot(contains(PaywallBenefitId.reliabilityChecks)));
      final opening = _open(_pro, PaywallPlace.weeklyCheck, listed: listed);
      expect(opening.layout, PaywallLayoutId.hero);
      expect(opening.lead, isNull);
    });

    test('wake-up challenges are Pro: the Sheet leads with them there, and '
        'Hosted opens its plan place', () {
      final pro = _open(
        _pro,
        PaywallPlace.challenge,
        listed: _built(_pro),
      );
      expect(pro.layout, PaywallLayoutId.sheet);
      expect(pro.lead, PaywallBenefitId.wakeUpChallenges);
      final hosted = _open(
        _hosted,
        PaywallPlace.challenge,
        listed: _built(_hosted),
      );
      expect(hosted.layout, PaywallLayoutId.hero);
      expect(hosted.lead, isNull);
    });

    test('a pinned layout keeps the place lead', () {
      final opening = _open(
        _pro,
        PaywallPlace.widgets,
        developer: _pin(PaywallLayoutId.proof),
      );
      expect(opening.layout, PaywallLayoutId.proof);
      expect(opening.lead, PaywallBenefitId.widgets);
    });
  });

  group('the developer layout', () {
    test('a pinned layout opens from every source, for both products', () {
      for (final layout in PaywallLayoutId.values) {
        final wanted = layout == PaywallLayoutId.doors
            ? PaywallLayoutId.hero
            : layout;
        for (final source in PaywallSource.values) {
          expect(
            _open(
              _hosted,
              paywallPlaceOf(source),
              developer: _pin(layout),
            ).layout,
            wanted,
            reason: '${layout.key} $source',
          );
        }
        for (final source in ProPackSheetSource.values) {
          expect(
            _open(
              _pro,
              paywallPlaceOfPro(source),
              developer: _pin(layout),
            ).layout,
            wanted,
            reason: '${layout.key} $source',
          );
        }
      }
    });

    test('auto is the table, the same as nothing set', () {
      for (final product in PaywallProduct.values) {
        for (final place in PaywallPlace.values) {
          expect(
            _open(product, place, developer: PaywallLayoutSetting.auto),
            _open(product, place),
            reason: '${product.key} $place',
          );
        }
      }
    });

    test('doors, pinned, opens hero', () {
      for (final place in PaywallPlace.values) {
        expect(
          _open(_hosted, place, developer: _pin(PaywallLayoutId.doors)).layout,
          PaywallLayoutId.hero,
        );
      }
    });

    test('receipt pinned keeps working', () {
      expect(
        _open(
          _hosted,
          PaywallPlace.history,
          developer: _pin(PaywallLayoutId.receipt),
        ).layout,
        PaywallLayoutId.receipt,
      );
    });

    test('nothing in the table opens doors', () {
      for (final place in PaywallPlace.values) {
        expect(paywallRowFor(place).layout, isNot(PaywallLayoutId.doors));
      }
    });
  });

  group('the intro', () {
    test('the false alarm plays at the critical limit and nowhere else', () {
      for (final place in PaywallPlace.values) {
        expect(
          _open(_hosted, place).intro,
          place == PaywallPlace.criticalLimit
              ? PaywallIntroId.falseAlarm
              : PaywallIntroId.none,
          reason: '$place',
        );
      }
    });

    test('it plays once on an install', () {
      expect(
        _open(
          _hosted,
          PaywallPlace.criticalLimit,
          hasSeenFalseAlarm: true,
        ).intro,
        PaywallIntroId.none,
      );
      // Not from Developer options either.
      expect(
        _open(
          _hosted,
          PaywallPlace.plan,
          developerIntro: PaywallIntroId.falseAlarm,
          hasSeenFalseAlarm: true,
        ).intro,
        PaywallIntroId.none,
      );
    });

    test('Hosted only: Pro plays no intro from the table', () {
      for (final place in PaywallPlace.values) {
        expect(_open(_pro, place).intro, PaywallIntroId.none, reason: '$place');
      }
    });

    test('the Settings plan row plays none', () {
      expect(
        _open(_hosted, paywallPlaceOf(PaywallSource.settingsPlan)).intro,
        PaywallIntroId.none,
      );
    });

    test('a developer intro, none included, outranks the table', () {
      for (final product in PaywallProduct.values) {
        for (final intro in PaywallIntroId.values) {
          for (final place in PaywallPlace.values) {
            expect(
              _open(product, place, developerIntro: intro).intro,
              intro,
              reason: '${product.key} ${intro.key} $place',
            );
          }
        }
      }
    });

    test('a pinned layout keeps the intro of the place', () {
      expect(
        _open(
          _hosted,
          PaywallPlace.criticalLimit,
          developer: _pin(PaywallLayoutId.bento),
        ).intro,
        PaywallIntroId.falseAlarm,
      );
    });
  });

  group('the thanks and the outro with no Developer options value', () {
    test('Hosted takes Receipt party and Cloud climb', () {
      expect(paywallDefaultThanksFor(_hosted), PaywallThanksId.receiptParty);
      expect(paywallDefaultOutroFor(_hosted), PaywallOutroId.cloudClimb);
      for (final place in PaywallPlace.values) {
        final opening = _open(_hosted, place);
        expect(opening.thanks, PaywallThanksId.receiptParty, reason: '$place');
        expect(opening.outro, PaywallOutroId.cloudClimb, reason: '$place');
      }
    });

    test('Pro takes Stamp and Break, lift, ring', () {
      expect(paywallDefaultThanksFor(_pro), PaywallThanksId.stamp);
      expect(paywallDefaultOutroFor(_pro), PaywallOutroId.breakLiftRing);
      for (final place in PaywallPlace.values) {
        final opening = _open(_pro, place);
        expect(opening.thanks, PaywallThanksId.stamp, reason: '$place');
        expect(opening.outro, PaywallOutroId.breakLiftRing, reason: '$place');
      }
    });

    test('a pinned layout takes them too', () {
      final hosted = _open(
        _hosted,
        PaywallPlace.plan,
        developer: _pin(PaywallLayoutId.bento),
      );
      expect(hosted.thanks, PaywallThanksId.receiptParty);
      expect(hosted.outro, PaywallOutroId.cloudClimb);
    });

    test('the leaving place takes the Hosted ones, whatever it opens', () {
      for (final choice in const [
        null,
        LeavingChoice(showsReceipt: true, historyDaysHeld: 60),
        LeavingChoice(showsReceipt: false, historyDaysHeld: 3),
      ]) {
        final opening = _open(
          _hosted,
          PaywallPlace.planEnding,
          leaving: choice,
        );
        expect(opening.thanks, PaywallThanksId.receiptParty);
        expect(opening.outro, PaywallOutroId.cloudClimb);
      }
    });
  });

  group('a Developer options value outranks each default', () {
    test('a thanks, none included', () {
      for (final product in PaywallProduct.values) {
        for (final thanks in PaywallThanksId.values) {
          final opening = _open(
            product,
            PaywallPlace.plan,
            developerThanks: thanks,
          );
          expect(opening.thanks, thanks, reason: '${product.key} $thanks');
          // The outro stays the product's own, unless there is no thanks
          // to hand over to.
          expect(
            opening.outro,
            thanks == PaywallThanksId.none
                ? PaywallOutroId.none
                : paywallDefaultOutroFor(product),
            reason: '${product.key} $thanks',
          );
        }
      }
    });

    test('an outro, none included', () {
      for (final product in PaywallProduct.values) {
        for (final outro in PaywallOutroId.values) {
          final opening = _open(
            product,
            PaywallPlace.plan,
            developerOutro: outro,
          );
          expect(opening.outro, outro, reason: '${product.key} $outro');
          expect(opening.thanks, paywallDefaultThanksFor(product));
        }
      }
    });

    test('the outro is none when the thanks is none, whatever is set', () {
      for (final product in PaywallProduct.values) {
        for (final outro in PaywallOutroId.values) {
          expect(
            _open(
              product,
              PaywallPlace.plan,
              developerThanks: PaywallThanksId.none,
              developerOutro: outro,
            ).outro,
            PaywallOutroId.none,
            reason: '${product.key} $outro',
          );
        }
      }
    });

    test('the four steps are set apart from one another', () {
      final opening = _open(
        _pro,
        PaywallPlace.widgets,
        developer: _pin(PaywallLayoutId.reel),
        developerIntro: PaywallIntroId.snooze,
        developerThanks: PaywallThanksId.confetti,
        developerOutro: PaywallOutroId.breakLift,
      );
      expect(
        opening,
        const PaywallOpening(
          PaywallLayoutId.reel,
          intro: PaywallIntroId.snooze,
          thanks: PaywallThanksId.confetti,
          outro: PaywallOutroId.breakLift,
          lead: PaywallBenefitId.widgets,
        ),
      );
    });

    test('two openings are the same only with the same thanks and outro', () {
      const a = PaywallOpening(
        PaywallLayoutId.hero,
        thanks: PaywallThanksId.stamp,
        outro: PaywallOutroId.cloudClimb,
      );
      expect(
        a,
        const PaywallOpening(
          PaywallLayoutId.hero,
          thanks: PaywallThanksId.stamp,
          outro: PaywallOutroId.cloudClimb,
        ),
      );
      expect(
        a,
        isNot(
          const PaywallOpening(
            PaywallLayoutId.hero,
            thanks: PaywallThanksId.confetti,
            outro: PaywallOutroId.cloudClimb,
          ),
        ),
      );
      expect(
        a,
        isNot(
          const PaywallOpening(
            PaywallLayoutId.hero,
            thanks: PaywallThanksId.stamp,
          ),
        ),
      );
    });
  });

  group('the plan ending', () {
    PaywallOpening open(
      LeavingChoice? leaving, {
      PaywallLayoutSetting? developer,
    }) => _open(
      _hosted,
      PaywallPlace.planEnding,
      developer: developer,
      hasSeenFalseAlarm: true,
      leaving: leaving,
    );

    test('good numbers open the receipt, with no lead', () {
      final opening = open(
        const LeavingChoice(showsReceipt: true, historyDaysHeld: 60),
      );
      expect(opening.layout, PaywallLayoutId.receipt);
      expect(opening.lead, isNull);
      expect(opening.headline, PaywallHeadlineVariant.leaving);
    });

    test('thin numbers open Wipe on history when 7 days or more are held', () {
      for (final days in [7, 8, 90, null]) {
        final opening = open(
          LeavingChoice(showsReceipt: false, historyDaysHeld: days),
        );
        expect(opening.layout, PaywallLayoutId.wipe, reason: '$days');
        expect(opening.lead, PaywallBenefitId.history, reason: '$days');
        expect(opening.headline, PaywallHeadlineVariant.leaving);
      }
    });

    test('thin numbers and under 7 days held open Wipe on critical topics', () {
      for (final days in [0, 3, 6]) {
        final opening = open(
          LeavingChoice(showsReceipt: false, historyDaysHeld: days),
        );
        expect(opening.layout, PaywallLayoutId.wipe, reason: '$days');
        expect(opening.lead, PaywallBenefitId.topics, reason: '$days');
      }
    });

    test('no choice is the table row: Wipe on history', () {
      final opening = open(null);
      expect(opening.layout, PaywallLayoutId.wipe);
      expect(opening.lead, PaywallBenefitId.history);
    });

    test('a pinned layout outranks the choice and keeps the headline', () {
      for (final layout in [
        PaywallLayoutId.hero,
        PaywallLayoutId.wipe,
        PaywallLayoutId.receipt,
        PaywallLayoutId.bento,
      ]) {
        for (final showsReceipt in [true, false]) {
          final opening = open(
            LeavingChoice(showsReceipt: showsReceipt, historyDaysHeld: 60),
            developer: _pin(layout),
          );
          expect(opening.layout, layout);
          expect(opening.headline, PaywallHeadlineVariant.leaving);
        }
      }
    });

    test('the choice means nothing at any other place', () {
      final opening = _open(
        _hosted,
        PaywallPlace.planEnded,
        hasSeenFalseAlarm: true,
        leaving: const LeavingChoice(showsReceipt: true),
      );
      expect(opening.layout, PaywallLayoutId.wipe);
      expect(opening.headline, PaywallHeadlineVariant.ended);
    });

    test('the receipt opens from the plan ending and from no other place', () {
      const choices = [
        null,
        LeavingChoice(showsReceipt: true),
        LeavingChoice(showsReceipt: true, historyDaysHeld: 0),
        LeavingChoice(showsReceipt: false, historyDaysHeld: 3),
        LeavingChoice(showsReceipt: false, historyDaysHeld: 60),
      ];
      for (final product in PaywallProduct.values) {
        for (final place in PaywallPlace.values) {
          for (final choice in choices) {
            final layout = _open(
              product,
              place,
              hasSeenFalseAlarm: true,
              leaving: choice,
            ).layout;
            final opensReceipt = layout == PaywallLayoutId.receipt;
            final isEndingWithGoodNumbers =
                product == PaywallProduct.hosted &&
                place == PaywallPlace.planEnding &&
                (choice?.showsReceipt ?? false);
            expect(
              opensReceipt,
              isEndingWithGoodNumbers,
              reason: '${product.key} $place ${choice?.showsReceipt}',
            );
          }
        }
      }
    });
  });
}
