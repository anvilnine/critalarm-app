import 'package:critalarm/core/paywall/paywall_headline.dart';
import 'package:critalarm/core/paywall/paywall_intro.dart';
import 'package:critalarm/core/paywall/paywall_layout.dart';
import 'package:critalarm/core/paywall/paywall_layout_setting.dart';
import 'package:critalarm/core/paywall/paywall_source.dart';
import 'package:critalarm/core/paywall/paywall_thanks.dart';
import 'package:critalarm/features/paywall/domain/entities/paywall_benefit.dart';
import 'package:critalarm/features/paywall/domain/entities/paywall_product.dart';
import 'package:critalarm/features/paywall/domain/paywall_routing.dart';
import 'package:critalarm/features/pro_pack/domain/pro_pack_analytics.dart';
import 'package:flutter_test/flutter_test.dart';

const PaywallProduct _hosted = PaywallProduct.hosted;
const PaywallProduct _pro = PaywallProduct.pro;

final Set<PaywallBenefitId> _all = PaywallBenefitId.values.toSet();

/// What opens, as the door asks. The remote layout value is read for the
/// layout and for the intro it may still carry. By default every benefit
/// is listed, so a lead is never dropped.
PaywallOpening? _open(
  PaywallProduct product,
  PaywallPlace place, {
  String remote = '',
  String remoteIntro = '',
  PaywallLayoutSetting? developer,
  PaywallIntroId? developerIntro,
  String remoteThanks = '',
  PaywallThanksId? developerThanks,
  bool hasSeenFalseAlarm = false,
  Set<PaywallBenefitId>? listed,
}) => paywallOpeningFor(
  product: product,
  place: place,
  remote: PaywallLayoutSetting.parse(remote),
  developer: developer,
  remoteIntro: PaywallIntroId.parse(remoteIntro),
  developerIntro: developerIntro,
  legacyIntro: developer == null ? paywallIntroInLayoutValue(remote) : null,
  remoteThanks: PaywallThanksId.parse(remoteThanks),
  developerThanks: developerThanks,
  hasSeenFalseAlarm: hasSeenFalseAlarm,
  listedBenefits: listed ?? _all,
);

PaywallLayoutId? paywallLayoutFor({
  required PaywallProduct product,
  required PaywallPlace place,
  required PaywallLayoutSetting remote,
  required bool hasSeenFalseAlarm,
}) => paywallOpeningFor(
  product: product,
  place: place,
  remote: remote,
  hasSeenFalseAlarm: hasSeenFalseAlarm,
  listedBenefits: _all,
)?.layout;

PaywallOpening? _hostedFrom(
  PaywallSource source, {
  String remote = '',
  PaywallLayoutSetting? developer,
  bool hasSeenFalseAlarm = false,
}) => _open(
  _hosted,
  paywallPlaceOf(source),
  remote: remote,
  developer: developer,
  hasSeenFalseAlarm: hasSeenFalseAlarm,
);

PaywallOpening? _proFrom(
  ProPackSheetSource source, {
  String remote = '',
  PaywallLayoutSetting? developer,
  bool hasSeenFalseAlarm = false,
}) => _open(
  _pro,
  paywallPlaceOfPro(source),
  remote: remote,
  developer: developer,
  hasSeenFalseAlarm: hasSeenFalseAlarm,
);

PaywallLayoutId? _hostedLayout(
  PaywallSource source, {
  String remote = '',
  PaywallLayoutSetting? developer,
  bool hasSeenFalseAlarm = false,
}) => _hostedFrom(
  source,
  remote: remote,
  developer: developer,
  hasSeenFalseAlarm: hasSeenFalseAlarm,
)?.layout;

PaywallLayoutId? _proLayout(
  ProPackSheetSource source, {
  String remote = '',
  PaywallLayoutSetting? developer,
  bool hasSeenFalseAlarm = false,
}) => _proFrom(
  source,
  remote: remote,
  developer: developer,
  hasSeenFalseAlarm: hasSeenFalseAlarm,
)?.layout;

PaywallIntroId? _hostedIntroFrom(
  PaywallSource source, {
  String remote = '',
  String remoteIntro = '',
  PaywallLayoutSetting? developer,
  PaywallIntroId? developerIntro,
  bool hasSeenFalseAlarm = false,
}) => _open(
  _hosted,
  paywallPlaceOf(source),
  remote: remote,
  remoteIntro: remoteIntro,
  developer: developer,
  developerIntro: developerIntro,
  hasSeenFalseAlarm: hasSeenFalseAlarm,
)?.intro;

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
        ProPackSheetSource.direct: PaywallPlace.plan,
      };
      for (final source in ProPackSheetSource.values) {
        expect(expected[source], isNotNull, reason: '$source has no row');
        expect(paywallPlaceOfPro(source), expected[source], reason: '$source');
      }
      expect(expected.length, ProPackSheetSource.values.length);
    });
  });

  group('the table', () {
    test('auto gives each place its row, with every benefit listed', () {
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
        final opening = _open(_hosted, place, remote: 'auto')!;
        expect(opening.layout, row!.$1, reason: '$place layout');
        expect(opening.lead, row.$2, reason: '$place lead');
        expect(opening.intro, row.$3, reason: '$place intro');
        expect(opening.headline, row.$4, reason: '$place headline');
        expect(paywallRowFor(place).layout, row.$1, reason: '$place row');
      }
      expect(expected.length, PaywallPlace.values.length);
    });

    test('Pro reads the same table', () {
      for (final place in PaywallPlace.values) {
        final hosted = _open(_hosted, place, remote: 'auto')!;
        final pro = _open(_pro, place, remote: 'auto')!;
        expect(pro.layout, hosted.layout, reason: '$place');
        expect(pro.lead, hosted.lead, reason: '$place');
      }
    });

    test('one product on auto leaves the other alone', () {
      expect(_open(_hosted, PaywallPlace.history, remote: 'auto'), isNotNull);
      expect(_open(_pro, PaywallPlace.history), isNull);
    });
  });

  group('lead falls back', () {
    test('a lead the product does not list is dropped, the layout stays', () {
      final listed = _all.difference({PaywallBenefitId.history});
      final opening = _open(
        _hosted,
        PaywallPlace.history,
        remote: 'auto',
        listed: listed,
      )!;
      expect(opening.layout, PaywallLayoutId.proof);
      expect(opening.lead, isNull);
    });

    test('widgets lead on Pro is kept when Pro lists it', () {
      final listed = {for (final b in paywallBenefitsFor(_pro)) b.id};
      final opening = _open(
        _pro,
        PaywallPlace.widgets,
        remote: 'auto',
        listed: listed,
      )!;
      expect(opening.lead, PaywallBenefitId.widgets);
    });

    test('a weekly check lead on Pro is dropped: Hosted unlocks it', () {
      final listed = {for (final b in paywallBenefitsFor(_pro)) b.id};
      expect(listed, isNot(contains(PaywallBenefitId.reliabilityChecks)));
      final opening = _open(
        _pro,
        PaywallPlace.weeklyCheck,
        remote: 'auto',
        listed: listed,
      )!;
      expect(opening.layout, PaywallLayoutId.proof);
      expect(opening.lead, isNull);
    });

    test(
      'wake-up challenges lead nothing while they are not in this build',
      () {
        // Flips when the challenge line and preview are fixed and
        // `inThisBuild` goes to true. Then change the expectation.
        for (final product in PaywallProduct.values) {
          final listed = {for (final b in paywallBenefitsFor(product)) b.id};
          final opening = _open(
            product,
            PaywallPlace.challenge,
            remote: 'auto',
            listed: listed,
          )!;
          expect(opening.layout, PaywallLayoutId.sheet, reason: '$product');
          expect(opening.lead, isNull, reason: '$product');
        }
      },
    );

    test('a pinned layout keeps the place lead', () {
      final opening = _open(
        _hosted,
        PaywallPlace.widgets,
        remote: 'proof',
      )!;
      expect(opening.layout, PaywallLayoutId.proof);
      expect(opening.lead, PaywallBenefitId.widgets);
    });
  });

  group('stale layout values', () {
    test('doors, pinned remote or developer, opens hero', () {
      for (final place in PaywallPlace.values) {
        expect(
          _open(_hosted, place, remote: 'doors')!.layout,
          PaywallLayoutId.hero,
        );
        expect(
          _open(
            _hosted,
            place,
            developer: const PaywallLayoutSetting.pinned(PaywallLayoutId.doors),
          )!.layout,
          PaywallLayoutId.hero,
        );
      }
    });

    test('receipt pinned keeps working', () {
      expect(
        _open(_hosted, PaywallPlace.history, remote: 'receipt')!.layout,
        PaywallLayoutId.receipt,
      );
    });

    test('nothing in the table opens doors', () {
      for (final place in PaywallPlace.values) {
        expect(paywallRowFor(place).layout, isNot(PaywallLayoutId.doors));
      }
    });
  });

  group('the false alarm intro', () {
    test('plays at the critical limit and nowhere else', () {
      for (final place in PaywallPlace.values) {
        final intro = _open(_hosted, place, remote: 'auto')!.intro;
        expect(
          intro,
          place == PaywallPlace.criticalLimit
              ? PaywallIntroId.falseAlarm
              : PaywallIntroId.none,
          reason: '$place',
        );
      }
    });

    test('plays once on an install', () {
      expect(
        _open(
          _hosted,
          PaywallPlace.criticalLimit,
          remote: 'auto',
          hasSeenFalseAlarm: true,
        )!.intro,
        PaywallIntroId.none,
      );
    });

    test('the Settings plan row no longer plays it', () {
      expect(
        _hostedFrom(PaywallSource.settingsPlan, remote: 'auto')!.intro,
        PaywallIntroId.none,
      );
    });

    test('a remote intro value outranks the table', () {
      expect(
        _open(
          _hosted,
          PaywallPlace.criticalLimit,
          remote: 'auto',
          remoteIntro: 'curtain',
        )!.intro,
        PaywallIntroId.curtain,
      );
      expect(
        _open(
          _hosted,
          PaywallPlace.history,
          remote: 'auto',
          remoteIntro: 'curtain',
        )!.intro,
        PaywallIntroId.curtain,
      );
    });

    test('a developer intro, none included, outranks everything', () {
      expect(
        _open(
          _hosted,
          PaywallPlace.criticalLimit,
          remote: 'auto',
          developerIntro: PaywallIntroId.none,
        )!.intro,
        PaywallIntroId.none,
      );
    });

    test('the old layout key reads as hero with the intro, once', () {
      final first = _open(
        _hosted,
        PaywallPlace.history,
        remote: 'false_alarm',
      )!;
      expect(first.layout, PaywallLayoutId.hero);
      expect(first.intro, PaywallIntroId.falseAlarm);
      final again = _open(
        _hosted,
        PaywallPlace.history,
        remote: 'false_alarm',
        hasSeenFalseAlarm: true,
      )!;
      expect(again.intro, PaywallIntroId.none);
    });

    test('never plays at the defaults', () {
      for (final place in PaywallPlace.values) {
        expect(_open(_hosted, place), isNull, reason: '$place');
      }
    });

    test('with no intro set it never plays for Pro', () {
      for (final remote in ['auto', 'false_alarm']) {
        for (final place in PaywallPlace.values) {
          expect(
            _open(_pro, place, remote: remote)?.intro,
            PaywallIntroId.none,
          );
        }
      }
    });
  });

  group('at the defaults nothing changes', () {
    test('an empty value opens the shipped surface from every place', () {
      for (final seen in [false, true]) {
        for (final source in PaywallSource.values) {
          expect(
            _hostedLayout(source, hasSeenFalseAlarm: seen),
            isNull,
            reason: '$source',
          );
        }
        for (final source in ProPackSheetSource.values) {
          expect(
            _proLayout(source, hasSeenFalseAlarm: seen),
            isNull,
            reason: '$source',
          );
        }
        for (final product in PaywallProduct.values) {
          for (final place in PaywallPlace.values) {
            expect(
              paywallLayoutFor(
                product: product,
                place: place,
                remote: PaywallLayoutSetting.shipped,
                hasSeenFalseAlarm: seen,
              ),
              isNull,
              reason: '$product $place',
            );
          }
        }
      }
    });

    test('a value this build does not know opens the shipped surface', () {
      for (final typo in ['heroo', 'AUTO', 'yes', 'true', 'shipped']) {
        for (final source in PaywallSource.values) {
          expect(_hostedLayout(source, remote: typo), isNull, reason: typo);
        }
        for (final source in ProPackSheetSource.values) {
          expect(_proLayout(source, remote: typo), isNull, reason: typo);
        }
      }
    });
  });

  group('a named layout', () {
    test('opens from every source, for both products', () {
      for (final layout in PaywallLayoutId.values) {
        // Doors left the table: a value that names it opens hero.
        final expected = layout == PaywallLayoutId.doors
            ? PaywallLayoutId.hero
            : layout;
        for (final source in PaywallSource.values) {
          expect(_hostedLayout(source, remote: layout.key), expected);
        }
        for (final source in ProPackSheetSource.values) {
          expect(_proLayout(source, remote: layout.key), expected);
        }
      }
    });

    test('hero by name stays hero on the Settings plan row', () {
      expect(
        _hostedLayout(PaywallSource.settingsPlan, remote: 'hero'),
        PaywallLayoutId.hero,
      );
    });
  });

  group('the developer control', () {
    test('outranks the remote value', () {
      expect(
        _hostedLayout(
          PaywallSource.history,
          remote: 'hero',
          developer: PaywallLayoutSetting.auto,
        ),
        PaywallLayoutId.proof,
      );
      expect(
        _proLayout(
          ProPackSheetSource.reliability,
          developer: const PaywallLayoutSetting.pinned(PaywallLayoutId.proof),
        ),
        PaywallLayoutId.proof,
      );
    });

    test('shipped opens the shipped surface whatever remote says', () {
      for (final remote in ['auto', 'hero', 'sheet']) {
        expect(
          _hostedLayout(
            PaywallSource.settingsPlan,
            remote: remote,
            developer: PaywallLayoutSetting.shipped,
          ),
          isNull,
        );
        expect(
          _proLayout(
            ProPackSheetSource.reliability,
            remote: remote,
            developer: PaywallLayoutSetting.shipped,
          ),
          isNull,
        );
      }
    });

    test('following remote is the remote value', () {
      expect(_hostedLayout(PaywallSource.askSheet), isNull);
      expect(
        _hostedLayout(PaywallSource.askSheet, remote: 'auto'),
        PaywallLayoutId.reel,
      );
    });
  });

  group('the intro value', () {
    test('plays before any layout, from any entry, for both products', () {
      for (final product in PaywallProduct.values) {
        for (final place in PaywallPlace.values) {
          for (final layout in ['hero', 'sheet', 'doors', 'auto']) {
            expect(
              _open(
                product,
                place,
                remote: layout,
                remoteIntro: 'false_alarm',
              )?.intro,
              PaywallIntroId.falseAlarm,
              reason: '$product $place $layout',
            );
          }
        }
      }
    });

    test('empty, and a value this build does not know, is no intro', () {
      for (final value in ['', '  ', 'falseAlarm', 'drumroll', 'none']) {
        expect(
          _hostedIntroFrom(
            PaywallSource.history,
            remote: 'hero',
            remoteIntro: value,
          ),
          PaywallIntroId.none,
          reason: value,
        );
      }
    });

    test('the false alarm still plays once on an install', () {
      expect(
        _hostedIntroFrom(
          PaywallSource.history,
          remote: 'sheet',
          remoteIntro: 'false_alarm',
          hasSeenFalseAlarm: true,
        ),
        PaywallIntroId.none,
      );
    });

    test('what Developer options set outranks the remote value', () {
      expect(
        _hostedIntroFrom(
          PaywallSource.history,
          remote: 'hero',
          developerIntro: PaywallIntroId.falseAlarm,
        ),
        PaywallIntroId.falseAlarm,
      );
      // No intro, set by hand, also beats the rule for the Settings row.
      expect(
        _hostedIntroFrom(
          PaywallSource.settingsPlan,
          remote: 'auto',
          remoteIntro: 'false_alarm',
          developerIntro: PaywallIntroId.none,
        ),
        PaywallIntroId.none,
      );
    });

    test('a developer layout drops the intro a remote layout carried', () {
      expect(
        _hostedIntroFrom(
          PaywallSource.settingsPlan,
          remote: 'false_alarm',
          developer: const PaywallLayoutSetting.pinned(PaywallLayoutId.sheet),
        ),
        PaywallIntroId.none,
      );
    });
  });

  group('the thanks value', () {
    test('goes with any layout, from any entry, for both products', () {
      for (final product in PaywallProduct.values) {
        for (final place in PaywallPlace.values) {
          for (final layout in ['hero', 'sheet', 'doors', 'auto']) {
            expect(
              _open(
                product,
                place,
                remote: layout,
                remoteThanks: 'confetti',
              )?.thanks,
              PaywallThanksId.confetti,
              reason: '$product $place $layout',
            );
          }
        }
      }
    });

    test('empty, and a value this build does not know, is no thanks', () {
      for (final value in ['', '  ', 'Confetti', 'fireworks', 'none']) {
        expect(
          _open(
            _hosted,
            PaywallPlace.criticalLimit,
            remote: 'hero',
            remoteThanks: value,
          )?.thanks,
          PaywallThanksId.none,
          reason: value,
        );
      }
    });

    test('what Developer options set outranks the remote value', () {
      expect(
        _open(
          _hosted,
          PaywallPlace.criticalLimit,
          remote: 'hero',
          remoteThanks: 'confetti',
          developerThanks: PaywallThanksId.unlock,
        )?.thanks,
        PaywallThanksId.unlock,
      );
      // No thanks, set by hand, is a choice too.
      expect(
        _open(
          _pro,
          PaywallPlace.widgets,
          remote: 'sheet',
          remoteThanks: 'confetti',
          developerThanks: PaywallThanksId.none,
        )?.thanks,
        PaywallThanksId.none,
      );
      expect(
        _open(
          _hosted,
          PaywallPlace.criticalLimit,
          remote: 'hero',
          developerThanks: PaywallThanksId.unlock,
        )?.thanks,
        PaywallThanksId.unlock,
      );
    });

    test('alone it opens nothing: the shipped surface is still null', () {
      for (final product in PaywallProduct.values) {
        for (final place in PaywallPlace.values) {
          expect(
            _open(
              product,
              place,
              remoteThanks: 'confetti',
              developerThanks: PaywallThanksId.unlock,
            ),
            isNull,
            reason: '$product $place',
          );
          expect(
            _open(
              product,
              place,
              remote: 'hero',
              developer: PaywallLayoutSetting.shipped,
              remoteThanks: 'confetti',
            ),
            isNull,
            reason: '$product $place',
          );
        }
      }
    });

    test('it leaves the intro alone, and the intro leaves it alone', () {
      expect(
        _open(
          _hosted,
          PaywallPlace.criticalLimit,
          remote: 'auto',
          remoteThanks: 'unlock',
        ),
        const PaywallOpening(
          PaywallLayoutId.sheet,
          intro: PaywallIntroId.falseAlarm,
          thanks: PaywallThanksId.unlock,
          lead: PaywallBenefitId.topics,
        ),
      );
      expect(
        _open(
          _hosted,
          PaywallPlace.criticalLimit,
          remote: 'auto',
          remoteThanks: 'unlock',
          hasSeenFalseAlarm: true,
        ),
        const PaywallOpening(
          PaywallLayoutId.sheet,
          thanks: PaywallThanksId.unlock,
          lead: PaywallBenefitId.topics,
        ),
      );
    });

    test('two openings are the same only with the same thanks', () {
      const plain = PaywallOpening(PaywallLayoutId.hero);
      const confetti = PaywallOpening(
        PaywallLayoutId.hero,
        thanks: PaywallThanksId.confetti,
      );
      expect(plain, isNot(confetti));
      expect(
        confetti,
        const PaywallOpening(
          PaywallLayoutId.hero,
          thanks: PaywallThanksId.confetti,
        ),
      );
      expect(
        confetti.hashCode,
        const PaywallOpening(
          PaywallLayoutId.hero,
          thanks: PaywallThanksId.confetti,
        ).hashCode,
      );
      expect(plain.thanks, PaywallThanksId.none);
      expect(
        confetti.toString(),
        'PaywallOpening(hero, intro: none, thanks: confetti, '
        'lead: null, headline: none)',
      );
    });
  });
}
