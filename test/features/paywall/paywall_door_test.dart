import 'dart:async';

import 'package:critalarm/app/di.dart';
import 'package:critalarm/core/access/feature_decision.dart';
import 'package:critalarm/core/access/holding.dart';
import 'package:critalarm/core/paywall/paywall_intro.dart';
import 'package:critalarm/core/paywall/paywall_layout.dart';
import 'package:critalarm/core/paywall/paywall_layout_setting.dart';
import 'package:critalarm/core/paywall/paywall_outro.dart';
import 'package:critalarm/core/paywall/paywall_source.dart';
import 'package:critalarm/core/paywall/paywall_thanks.dart';
import 'package:critalarm/core/push/push_deep_link.dart';
import 'package:critalarm/features/paywall/domain/entities/paywall_product.dart';
import 'package:critalarm/features/paywall/domain/history_own.dart';
import 'package:critalarm/features/paywall/domain/leaving_numbers.dart';
import 'package:critalarm/features/paywall/domain/paywall_lead_facts.dart';
import 'package:critalarm/features/paywall/presentation/paywall_door.dart';
import 'package:critalarm/features/pro_pack/domain/pro_pack_analytics.dart';
import 'package:flutter_test/flutter_test.dart';

class _Install {
  String hosted = '';
  String pro = '';
  String hostedIntro = '';
  String proIntro = '';
  PaywallIntroId? devHostedIntro;
  String hostedThanks = '';
  String proThanks = '';
  PaywallThanksId? devHostedThanks;
  PaywallThanksId? devProThanks;
  bool thanksAreBuilt = true;
  String hostedOutro = '';
  String proOutro = '';
  PaywallOutroId? devHostedOutro;
  bool outrosAreBuilt = true;
  PaywallLayoutSetting? devHosted;
  PaywallLayoutSetting? devPro;
  bool seen = false;
  int marks = 0;
  bool falseAlarmIsBuilt = true;
  bool remoteThrows = false;
  FeatureDecision widgets = const FeatureDecision.locked(Holding.pro);
  bool widgetsThrow = false;
  HistoryOwn? historyOwn;
  bool historyOwnThrows = false;
  bool historyOwnHangs = false;
  LeavingFacts? leavingFacts;
  bool leavingThrows = false;
  bool leavingHangs = false;
  bool leavingMarkThrows = false;
  String? leavingShown;
  int leavingMarks = 0;

  late final door = PaywallDoor(
    widgetsDecision: () {
      if (widgetsThrow) throw StateError('no access layer');
      return widgets;
    },
    remoteValue: (product) {
      if (remoteThrows) throw StateError('no remote config');
      return product == PaywallProduct.hosted ? hosted : pro;
    },
    developer: (product) =>
        product == PaywallProduct.hosted ? devHosted : devPro,
    hasSeenFalseAlarm: () => seen,
    markFalseAlarmSeen: () async {
      seen = true;
      marks++;
    },
    remoteIntroValue: (product) =>
        product == PaywallProduct.hosted ? hostedIntro : proIntro,
    developerIntro: (product) =>
        product == PaywallProduct.hosted ? devHostedIntro : null,
    isIntroBuilt: (intro) =>
        intro != PaywallIntroId.falseAlarm || falseAlarmIsBuilt,
    remoteThanksValue: (product) =>
        product == PaywallProduct.hosted ? hostedThanks : proThanks,
    developerThanks: (product) =>
        product == PaywallProduct.hosted ? devHostedThanks : devProThanks,
    isThanksBuilt: (thanks) => thanks == PaywallThanksId.none || thanksAreBuilt,
    remoteOutroValue: (product) =>
        product == PaywallProduct.hosted ? hostedOutro : proOutro,
    developerOutro: (product) =>
        product == PaywallProduct.hosted ? devHostedOutro : null,
    isOutroBuilt: (outro) => outro == PaywallOutroId.none || outrosAreBuilt,
    readHistoryOwn: () async {
      if (historyOwnThrows) throw StateError('no store');
      if (historyOwnHangs) return Completer<HistoryOwn?>().future;
      return historyOwn;
    },
    readLeavingFacts: () async {
      if (leavingThrows) throw StateError('no store');
      if (leavingHangs) return Completer<LeavingFacts?>().future;
      return leavingFacts;
    },
    leavingShownFor: () => leavingShown,
    markLeavingShown: (value) async {
      leavingMarks++;
      if (leavingMarkThrows) throw StateError('no prefs');
      leavingShown = value;
    },
    leavingReadTimeout: const Duration(milliseconds: 50),
  );
}

void main() {
  group('at the defaults', () {
    test('every Hosted entry opens the shipped paywall, as before', () {
      final install = _Install();
      for (final source in PaywallSource.values) {
        expect(
          install.door.hostedLocation(source),
          '/paywall?source=${source.wire}',
        );
        // A locked widget tap is the one link the door sends elsewhere.
        if (source == PaywallSource.widgetLocked) continue;
        expect(
          install.door.resolve(paywallLocation(source)),
          paywallLocation(source),
        );
      }
      expect(install.door.resolve('/paywall'), '/paywall');
      expect(install.marks, 0);
    });

    test('every Pro entry opens the Pro sheet', () {
      final install = _Install();
      for (final source in ProPackSheetSource.values) {
        expect(install.door.proLayoutLocation(source), isNull);
      }
    });

    test('a layout location goes to the shipped surface in its place', () {
      final door = _Install().door;
      expect(door.opensLayouts(PaywallProduct.hosted), isFalse);
      expect(door.opensLayouts(PaywallProduct.pro), isFalse);
      expect(
        door.shippedInsteadOf(Uri.parse('/plans/hero?source=history')),
        '/paywall?source=history',
      );
      expect(
        door.shippedInsteadOf(Uri.parse('/plans/hero?product=hosted')),
        '/paywall?source=direct',
      );
      expect(
        door.shippedInsteadOf(
          Uri.parse('/plans/sheet?product=pro&source=reliability'),
        ),
        '/pro?source=reliability',
      );
    });

    test('with no door registered the helpers answer the same', () {
      expect(
        hostedPaywallLocation(PaywallSource.settingsPlan),
        '/paywall?source=settings_plan',
      );
      expect(
        resolvePaywallLocation('/paywall?source=history'),
        '/paywall?source=history',
      );
      expect(
        shippedPaywallInsteadOf(Uri.parse('/plans/hero?source=history')),
        '/paywall?source=history',
      );
      expect(
        shippedPaywallInsteadOf(Uri.parse('/plans/hero?product=pro')),
        '/pro',
      );
    });

    test('a remote read that throws opens the shipped surface', () {
      final install = _Install()..remoteThrows = true;
      expect(
        install.door.hostedLocation(PaywallSource.history),
        '/paywall?source=history',
      );
      expect(
        install.door.proLayoutLocation(ProPackSheetSource.reliability),
        isNull,
      );
      expect(
        install.door.shippedInsteadOf(Uri.parse('/plans/hero')),
        '/paywall?source=direct',
      );
    });

    test('an unknown remote value opens the shipped surface', () {
      final install = _Install()
        ..hosted = 'heroo'
        ..pro = 'yes';
      expect(
        install.door.hostedLocation(PaywallSource.history),
        '/paywall?source=history',
      );
      expect(
        install.door.proLayoutLocation(ProPackSheetSource.reliability),
        isNull,
      );
    });
  });

  group('a tap on a locked widget', () {
    final tap = paywallLocation(PaywallSource.widgetLocked);

    test('opens the Pro paywall, because widgets are Pro', () {
      final install = _Install();
      expect(install.door.resolve(tap), '/pro?source=widget_locked');
    });

    test('the whole route from the native tap ends at the Pro paywall', () {
      final install = _Install();
      // iOS and the Android notification route say open=paywall. The
      // Android widget tap route is a bare /paywall and gets tagged.
      final fromData = PushDeepLink.fromNotificationData({'open': 'paywall'});
      expect(install.door.resolve(fromData!), '/pro?source=widget_locked');
      expect(
        install.door.resolve(PushDeepLink.tagged('/paywall')),
        '/pro?source=widget_locked',
      );
    });

    test('opens the Pro layout when Pro is set to open one', () {
      final install = _Install()..pro = 'auto';
      expect(
        install.door.resolve(tap),
        '/plans/sheet?product=pro&source=widget_locked&lead=widgets',
      );
    });

    test('opens the Hosted paywall only if the decision offers Hosted', () {
      final install = _Install()
        ..widgets = const FeatureDecision.locked(Holding.hosted);
      expect(install.door.resolve(tap), tap);
    });

    test('sells nothing once widgets are open, confirming or unread', () {
      for (final decision in const [
        FeatureDecision.open(),
        FeatureDecision.confirming(Holding.pro),
        FeatureDecision.unread(Holding.pro),
      ]) {
        final install = _Install()..widgets = decision;
        expect(install.door.resolve(tap), '/', reason: '$decision');
      }
    });

    test('sells nothing when the decision cannot be asked', () {
      final install = _Install()..widgetsThrow = true;
      expect(install.door.resolve(tap), '/');
    });

    test('every other paywall link is left to the Hosted logic', () {
      final install = _Install();
      expect(
        install.door.resolve('/paywall?source=history'),
        '/paywall?source=history',
      );
    });
  });

  group('with a remote value set', () {
    test('Hosted opens the layout with the product and the source', () {
      final install = _Install()..hosted = 'auto';
      expect(
        install.door.hostedLocation(PaywallSource.history),
        '/plans/proof?product=hosted&source=history&lead=history',
      );
      expect(
        install.door.resolve('/paywall?source=reminder_pro_later'),
        '/plans/reel?product=hosted&source=reminder_pro_later',
      );
      expect(
        install.door.resolve('/paywall'),
        '/plans/hero?product=hosted&source=direct',
      );
      // Pro has its own value and still opens the sheet.
      expect(
        install.door.proLayoutLocation(ProPackSheetSource.reliability),
        isNull,
      );
      expect(
        install.door.shippedInsteadOf(Uri.parse('/plans/sheet?source=history')),
        isNull,
      );
    });

    test('Pro opens the layout and keeps its own source word', () {
      final install = _Install()..pro = 'auto';
      expect(
        install.door.proLayoutLocation(ProPackSheetSource.reliability),
        '/plans/proof?product=pro&source=reliability',
      );
      expect(
        install.door.hostedLocation(PaywallSource.history),
        '/paywall?source=history',
      );
    });

    test('a path that is not the paywall is left alone', () {
      final install = _Install()..hosted = 'auto';
      for (final path in ['/', '/ring', '/paywall/success', '/topics/a?x=1']) {
        expect(install.door.resolve(path), path);
      }
    });

    test('a layout never asks for the list of every benefit', () {
      final install = _Install()
        ..hosted = 'auto'
        ..pro = 'hero';
      expect(
        install.door.hostedLocation(PaywallSource.direct),
        isNot(contains('benefits')),
      );
      expect(
        install.door.proLayoutLocation(ProPackSheetSource.direct),
        isNot(contains('benefits')),
      );
    });

    test('Developer options outrank it', () {
      final install = _Install()
        ..hosted = 'auto'
        ..devHosted = PaywallLayoutSetting.shipped
        ..devPro = const PaywallLayoutSetting.pinned(PaywallLayoutId.proof);
      expect(
        install.door.hostedLocation(PaywallSource.history),
        '/paywall?source=history',
      );
      expect(
        install.door.proLayoutLocation(ProPackSheetSource.direct),
        '/plans/proof?product=pro&source=direct',
      );
    });
  });

  group('the false alarm intro', () {
    test('plays once at the critical topic limit, then the sheet alone', () {
      final install = _Install()..hosted = 'auto';
      expect(
        install.door.hostedLocation(PaywallSource.createTopicCard),
        '/plans/sheet?product=hosted&source=create_topic_card'
        '&intro=false_alarm&lead=topics',
      );
      expect(install.marks, 1);
      expect(
        install.door.hostedLocation(PaywallSource.createTopicCard),
        '/plans/sheet?product=hosted&source=create_topic_card&lead=topics',
      );
      expect(install.marks, 1);
    });

    test('a person who saw it from Settings before does not see it again', () {
      final install = _Install()
        ..hosted = 'auto'
        ..seen = true;
      expect(
        install.door.hostedLocation(PaywallSource.createTopicCard),
        '/plans/sheet?product=hosted&source=create_topic_card&lead=topics',
      );
      expect(install.marks, 0);
    });

    test('the Settings plan row plays nothing', () {
      final install = _Install()..hosted = 'auto';
      expect(
        install.door.hostedLocation(PaywallSource.settingsPlan),
        '/plans/hero?product=hosted&source=settings_plan',
      );
      expect(install.marks, 0);
    });

    test('a stored value that names it as a layout opens hero with it', () {
      final install = _Install()..hosted = 'false_alarm';
      expect(
        install.door.hostedLocation(PaywallSource.history),
        '/plans/hero?product=hosted&source=history&intro=false_alarm&lead=history',
      );
      expect(install.marks, 1);
    });

    test('other places neither play it nor use up its showing', () {
      final install = _Install()..hosted = 'auto';
      for (final source in PaywallSource.values) {
        if (source == PaywallSource.createTopicCard) continue;
        expect(
          install.door.hostedLocation(source),
          isNot(contains('false_alarm')),
        );
      }
      expect(install.marks, 0);
    });

    test(
      'a build that cannot play it opens the sheet and keeps the showing',
      () {
        final install = _Install()
          ..hosted = 'auto'
          ..falseAlarmIsBuilt = false;
        expect(
          install.door.hostedLocation(PaywallSource.createTopicCard),
          '/plans/sheet?product=hosted&source=create_topic_card&lead=topics',
        );
        expect(install.marks, 0);
      },
    );
  });

  group('the intro value', () {
    test('goes in the location beside any layout, for both products', () {
      final install = _Install()
        ..hosted = 'sheet'
        ..hostedIntro = 'false_alarm'
        ..pro = 'proof'
        ..proIntro = 'false_alarm';
      expect(
        install.door.hostedLocation(PaywallSource.history),
        '/plans/sheet?product=hosted&source=history&intro=false_alarm&lead=history',
      );
      expect(install.marks, 1);
      // Its one showing is used up, for either product.
      expect(
        install.door.proLayoutLocation(ProPackSheetSource.direct),
        '/plans/proof?product=pro&source=direct',
      );
    });

    test('alone it changes nothing: empty layout is the shipped surface', () {
      final install = _Install()..hostedIntro = 'false_alarm';
      expect(
        install.door.hostedLocation(PaywallSource.history),
        '/paywall?source=history',
      );
      expect(install.marks, 0);
    });

    test('Developer options outrank it', () {
      final install = _Install()
        ..hosted = 'hero'
        ..hostedIntro = 'false_alarm'
        ..devHostedIntro = PaywallIntroId.none;
      expect(
        install.door.hostedLocation(PaywallSource.history),
        '/plans/hero?product=hosted&source=history&lead=history',
      );
      expect(install.marks, 0);
    });
  });

  group('the thanks value', () {
    test('goes in the location beside any layout, for both products', () {
      final install = _Install()
        ..hosted = 'sheet'
        ..hostedThanks = 'confetti'
        ..pro = 'proof'
        ..proThanks = ' unlock ';
      expect(
        install.door.hostedLocation(PaywallSource.history),
        '/plans/sheet?product=hosted&source=history&thanks=confetti&lead=history',
      );
      expect(
        install.door.resolve('/paywall?source=history'),
        '/plans/sheet?product=hosted&source=history&thanks=confetti&lead=history',
      );
      expect(
        install.door.proLayoutLocation(ProPackSheetSource.direct),
        '/plans/proof?product=pro&source=direct&thanks=unlock',
      );
    });

    test('goes after the intro, and neither drops the other', () {
      final install = _Install()
        ..hosted = 'auto'
        ..hostedThanks = 'unlock';
      expect(
        install.door.hostedLocation(PaywallSource.createTopicCard),
        '/plans/sheet?product=hosted&source=create_topic_card'
        '&intro=false_alarm&thanks=unlock&lead=topics',
      );
      // The intro has had its one showing. The thanks has no such rule.
      expect(
        install.door.hostedLocation(PaywallSource.createTopicCard),
        '/plans/sheet?product=hosted&source=create_topic_card&thanks=unlock&lead=topics',
      );
    });

    test('an intro this build cannot play keeps the thanks', () {
      final install = _Install()
        ..hosted = 'hero'
        ..hostedIntro = 'false_alarm'
        ..hostedThanks = 'confetti'
        ..falseAlarmIsBuilt = false;
      expect(
        install.door.hostedLocation(PaywallSource.history),
        '/plans/hero?product=hosted&source=history&thanks=confetti&lead=history',
      );
      expect(install.marks, 0);
    });

    test('a thanks this build cannot play is no thanks', () {
      final install = _Install()
        ..hosted = 'hero'
        ..hostedIntro = 'false_alarm'
        ..hostedThanks = 'confetti'
        ..pro = 'sheet'
        ..proThanks = 'unlock'
        ..thanksAreBuilt = false;
      // The intro still plays.
      expect(
        install.door.hostedLocation(PaywallSource.history),
        '/plans/hero?product=hosted&source=history&intro=false_alarm&lead=history',
      );
      expect(
        install.door.proLayoutLocation(ProPackSheetSource.reliability),
        '/plans/sheet?product=pro&source=reliability',
      );
    });

    test('a value this build does not know is no thanks', () {
      final install = _Install()
        ..hosted = 'hero'
        ..hostedThanks = 'fireworks';
      expect(
        install.door.hostedLocation(PaywallSource.history),
        '/plans/hero?product=hosted&source=history&lead=history',
      );
    });

    test('alone it changes nothing: empty layout is the shipped surface', () {
      final install = _Install()
        ..hostedThanks = 'confetti'
        ..proThanks = 'unlock'
        ..devHostedThanks = PaywallThanksId.unlock;
      expect(
        install.door.hostedLocation(PaywallSource.history),
        '/paywall?source=history',
      );
      expect(
        install.door.resolve('/paywall?source=history'),
        '/paywall?source=history',
      );
      expect(install.door.proLayoutLocation(ProPackSheetSource.direct), isNull);
      expect(install.door.opensLayouts(PaywallProduct.hosted), isFalse);
    });

    test('Developer options outrank it', () {
      final install = _Install()
        ..hosted = 'hero'
        ..hostedThanks = 'confetti'
        ..devHostedThanks = PaywallThanksId.none
        ..pro = 'hero'
        ..devProThanks = PaywallThanksId.unlock;
      expect(
        install.door.hostedLocation(PaywallSource.history),
        '/plans/hero?product=hosted&source=history&lead=history',
      );
      expect(
        install.door.proLayoutLocation(ProPackSheetSource.direct),
        '/plans/hero?product=pro&source=direct&thanks=unlock',
      );
    });

    test('with nothing injected a door has no thanks', () {
      final door = PaywallDoor(
        remoteValue: (_) => 'hero',
        developer: (_) => null,
        hasSeenFalseAlarm: () => false,
        markFalseAlarmSeen: () async {},
      );
      expect(
        door.hostedLocation(PaywallSource.history),
        '/plans/hero?product=hosted&source=history&lead=history',
      );
    });
  });

  group('the lead and the headline', () {
    test('a place with a lead puts it in the location', () {
      final install = _Install()
        ..hosted = 'auto'
        ..pro = 'auto';
      expect(
        install.door.hostedLocation(PaywallSource.appIcon),
        '/plans/sheet?product=hosted&source=app_icon&lead=app_icons',
      );
      // Own sounds are a Pro benefit: Hosted does not list it, so only the
      // Pro location carries the lead.
      expect(
        install.door.hostedLocation(PaywallSource.personalizeSound),
        '/plans/sheet?product=hosted&source=personalize_sound',
      );
      expect(
        install.door.proLayoutLocation(ProPackSheetSource.personalizeSound),
        '/plans/sheet?product=pro&source=personalize_sound'
        '&lead=custom_sounds',
      );
    });

    test('the plan ended carries its headline', () {
      final install = _Install()..hosted = 'auto';
      expect(
        install.door.hostedLocation(PaywallSource.planSheetEnded),
        '/plans/wipe?product=hosted&source=plan_sheet_ended'
        '&lead=history&headline=ended',
      );
    });

    test('a lead this build does not list is left out', () {
      final install = _Install()..hosted = 'auto';
      final door = PaywallDoor(
        remoteValue: (_) => 'auto',
        developer: (_) => null,
        hasSeenFalseAlarm: () => true,
        markFalseAlarmSeen: () async {},
        listedBenefits: (_) => const {},
      );
      expect(
        door.hostedLocation(PaywallSource.history),
        '/plans/proof?product=hosted&source=history',
      );
      expect(
        install.door.hostedLocation(PaywallSource.history),
        contains('lead=history'),
      );
    });

    test('Pro puts a lead it lists in the location', () {
      final install = _Install()..pro = 'auto';
      expect(
        install.door.proLayoutLocation(ProPackSheetSource.personalizeWidgets),
        '/plans/sheet?product=pro&source=personalize_widgets&lead=widgets',
      );
    });
  });

  group('the history rows', () {
    const own = HistoryOwn(
      inside: [HistoryOwnRow('prod-db', 1)],
      beyond: [HistoryOwnRow('nas', 12), HistoryOwnRow('prod-db', 81)],
    );

    test('a history place carries the rows the phone holds', () {
      final install = _Install()..hosted = 'auto';
      expect(
        install.door.hostedLocation(PaywallSource.history, own: own),
        '/plans/proof?product=hosted&source=history&lead=history'
        '&hin=prod-db%3A1&hbe=nas%3A12%2Cprod-db%3A81',
      );
    });

    test('a place with another lead leaves them out', () {
      final install = _Install()..hosted = 'auto';
      expect(
        install.door.hostedLocation(PaywallSource.appIcon, own: own),
        '/plans/sheet?product=hosted&source=app_icon&lead=app_icons',
      );
    });

    test('with no rows older than the window nothing is added', () {
      final install = _Install()..hosted = 'auto';
      expect(
        install.door.hostedLocation(PaywallSource.history),
        '/plans/proof?product=hosted&source=history&lead=history',
      );
    });

    test('the ended plan carries the rows the phone still holds', () async {
      final install = _Install()
        ..hosted = 'auto'
        ..historyOwn = const HistoryOwn(
          inside: [HistoryOwnRow('prod-db', 1)],
          beyond: [HistoryOwnRow('nas', 12)],
        );
      final own = await install.door.readHistoryOwn();
      final location = install.door.hostedLocation(
        PaywallSource.planSheetEnded,
        own: own,
      );
      expect(
        location,
        startsWith(
          '/plans/wipe?product=hosted&source=plan_sheet_ended'
          '&lead=history&headline=ended&hin=',
        ),
      );
      // The route reads the same rows back out of the location.
      final back = HistoryOwn.fromQuery(Uri.parse(location).queryParameters);
      expect(back, isNotNull);
      expect(back!.inside.single.topic, 'prod-db');
      expect(back.beyond.single.topic, 'nas');
      expect(back.beyond.single.ageDays, 12);
    });

    test('the ended plan with nothing older on the phone carries no rows', () {
      final install = _Install()..hosted = 'auto';
      final location = install.door.hostedLocation(
        PaywallSource.planSheetEnded,
      );
      expect(
        location,
        '/plans/wipe?product=hosted&source=plan_sheet_ended'
        '&lead=history&headline=ended',
      );
      // No rows in the location: the Wipe draws its made-up picture.
      expect(
        HistoryOwn.fromQuery(Uri.parse(location).queryParameters),
        isNull,
      );
    });

    test(
      'the helper the ended sheet calls puts the rows in the location',
      () async {
        final install = _Install()
          ..hosted = 'auto'
          ..historyOwn = const HistoryOwn(
            inside: [HistoryOwnRow('prod-db', 1)],
            beyond: [HistoryOwnRow('nas', 12)],
          );
        getIt.registerSingleton<PaywallDoor>(install.door);
        addTearDown(() => getIt.unregister<PaywallDoor>());
        final location = await hostedPaywallLocationWithOwn(
          PaywallSource.planSheetEnded,
        );
        expect(
          location,
          '/plans/wipe?product=hosted&source=plan_sheet_ended'
          '&lead=history&headline=ended&hin=prod-db%3A1&hbe=nas%3A12',
        );
      },
    );

    test('the async helper reads the rows once and never throws', () async {
      final install = _Install()
        ..hosted = 'auto'
        ..historyOwn = own;
      expect(await install.door.readHistoryOwn(), isNotNull);
      install.historyOwnThrows = true;
      expect(await install.door.readHistoryOwn(), isNull);
    });
  });

  group('the facts of the critical limit', () {
    test('a topics lead carries the count and the name', () {
      final install = _Install()
        ..hosted = 'auto'
        ..seen = true;
      expect(
        install.door.hostedLocation(
          PaywallSource.createTopicCard,
          facts: const PaywallLeadFacts(
            used: 2,
            limit: 2,
            topicName: 'billing-api',
          ),
        ),
        '/plans/sheet?product=hosted&source=create_topic_card&lead=topics'
        '&used=2&limit=2&topic=billing-api',
      );
    });

    test('facts on a place with another lead are left out', () {
      final install = _Install()..hosted = 'auto';
      expect(
        install.door.hostedLocation(
          PaywallSource.history,
          facts: const PaywallLeadFacts(used: 2, limit: 2),
        ),
        '/plans/proof?product=hosted&source=history&lead=history',
      );
    });

    test('with no layout set the shipped paywall opens and ignores them', () {
      final install = _Install();
      expect(
        install.door.hostedLocation(
          PaywallSource.createTopicCard,
          facts: const PaywallLeadFacts(used: 2, limit: 2),
        ),
        '/paywall?source=create_topic_card',
      );
    });

    test('empty facts add nothing', () {
      final install = _Install()
        ..hosted = 'auto'
        ..seen = true;
      expect(
        install.door.hostedLocation(
          PaywallSource.createTopicCard,
          facts: const PaywallLeadFacts(),
        ),
        '/plans/sheet?product=hosted&source=create_topic_card&lead=topics',
      );
    });

    test('a name the location cannot hold is left out, the paywall opens', () {
      final install = _Install()
        ..hosted = 'auto'
        ..seen = true;
      expect(
        install.door.hostedLocation(
          PaywallSource.createTopicCard,
          facts: const PaywallLeadFacts(
            used: 2,
            limit: 2,
            topicName: 'bell \u{1F514}',
          ),
        ),
        '/plans/sheet?product=hosted&source=create_topic_card&lead=topics'
        '&used=2&limit=2',
      );
    });

    test('the false alarm intro still comes first', () {
      final install = _Install()..hosted = 'auto';
      final location = install.door.hostedLocation(
        PaywallSource.createTopicCard,
        facts: const PaywallLeadFacts(used: 2, limit: 2, topicName: 'a'),
      );
      expect(location, contains('intro=false_alarm'));
      expect(location, endsWith('&used=2&limit=2&topic=a'));
    });
  });

  group('the leaving paywall', () {
    const good = LeavingFacts(
      rang: 142,
      answered: 139,
      nights: 9,
      criticalTopics: 4,
      historyDaysHeld: 61,
    );
    const thin = LeavingFacts(
      rang: 4,
      answered: 4,
      nights: 0,
      criticalTopics: 1,
      historyDaysHeld: 20,
    );
    const young = LeavingFacts(
      rang: 2,
      answered: 2,
      nights: 0,
      criticalTopics: 1,
      historyDaysHeld: 3,
    );
    final ends = DateTime(2026, 10, 20, 14, 30);
    const wipeWithoutNumbers =
        '/plans/wipe?product=hosted&source=plan_sheet_ending&lead=history'
        '&headline=leaving&ends=2026-10-20';

    test(
      'good numbers open the receipt with the date and the numbers',
      () async {
        final install = _Install()
          ..hosted = 'auto'
          ..leavingFacts = good;
        expect(
          await install.door.leavingLocation(ends),
          '/plans/receipt?product=hosted&source=plan_sheet_ending'
          '&headline=leaving&ends=2026-10-20'
          '&rang=142&ans=139&nights=9&crit=4&days=61',
        );
      },
    );

    test('thin numbers open Wipe on history', () async {
      final install = _Install()
        ..hosted = 'auto'
        ..leavingFacts = thin;
      expect(
        await install.door.leavingLocation(ends),
        '/plans/wipe?product=hosted&source=plan_sheet_ending&lead=history'
        '&headline=leaving&ends=2026-10-20'
        '&rang=4&ans=4&nights=0&crit=1&days=20',
      );
    });

    test('two numbers over their floor are enough, one is not', () async {
      // Alarms that rang and critical topics clear. Answered, nights do not.
      final two = _Install()
        ..hosted = 'auto'
        ..leavingFacts = const LeavingFacts(
          rang: 12,
          answered: 2,
          nights: 1,
          criticalTopics: 3,
          historyDaysHeld: 30,
        );
      expect(await two.door.leavingLocation(ends), contains('/plans/receipt?'));
      final one = _Install()
        ..hosted = 'auto'
        ..leavingFacts = const LeavingFacts(
          rang: 12,
          answered: 2,
          nights: 1,
          criticalTopics: 2,
          historyDaysHeld: 30,
        );
      expect(await one.door.leavingLocation(ends), contains('/plans/wipe?'));
    });

    test('under 7 days of history open Wipe on critical topics', () async {
      final install = _Install()
        ..hosted = 'auto'
        ..leavingFacts = young;
      expect(
        await install.door.leavingLocation(ends),
        contains(
          '/plans/wipe?product=hosted&source=plan_sheet_ending&lead=topics',
        ),
      );
    });

    test('the rows the phone holds ride along for a Wipe on history', () async {
      final install = _Install()
        ..hosted = 'auto'
        ..leavingFacts = thin
        ..historyOwn = const HistoryOwn(
          inside: [HistoryOwnRow('prod-db', 1)],
          beyond: [HistoryOwnRow('nas', 12)],
        );
      final location = await install.door.leavingLocation(ends);
      expect(location, contains('/plans/wipe?'));
      expect(location, contains('&hbe='));
    });

    test(
      'a receipt carries no history rows: it shows no history picture',
      () async {
        final install = _Install()
          ..hosted = 'auto'
          ..leavingFacts = good
          ..historyOwn = const HistoryOwn(
            inside: [],
            beyond: [HistoryOwnRow('nas', 12)],
          );
        expect(
          await install.door.leavingLocation(ends),
          isNot(contains('hbe=')),
        );
      },
    );

    test('a Wipe on critical topics carries no history rows', () async {
      final install = _Install()
        ..hosted = 'auto'
        ..leavingFacts = young
        ..historyOwn = const HistoryOwn(
          inside: [],
          beyond: [HistoryOwnRow('nas', 12)],
        );
      expect(
        await install.door.leavingLocation(ends),
        isNot(contains('hbe=')),
      );
    });

    group('numbers that cannot be read', () {
      test('none were found: Wipe on history with the date', () async {
        final install = _Install()..hosted = 'auto';
        expect(await install.door.leavingLocation(ends), wipeWithoutNumbers);
      });

      test('a read that throws opens Wipe and never throws', () async {
        final install = _Install()
          ..hosted = 'auto'
          ..leavingFacts = good
          ..leavingThrows = true;
        expect(await install.door.leavingLocation(ends), wipeWithoutNumbers);
      });

      test(
        'a read that never answers opens Wipe once the wait is up',
        () async {
          final install = _Install()
            ..hosted = 'auto'
            ..leavingFacts = good
            ..leavingHangs = true;
          expect(await install.door.leavingLocation(ends), wipeWithoutNumbers);
        },
      );

      test('rows that cannot be read leave the numbers in place', () async {
        for (final fail in [
          (_Install install) => install.historyOwnThrows = true,
          (_Install install) => install.historyOwnHangs = true,
        ]) {
          final install = _Install()
            ..hosted = 'auto'
            ..leavingFacts = thin;
          fail(install);
          final location = await install.door.leavingLocation(ends);
          expect(location, contains('/plans/wipe?'));
          expect(location, contains('&rang=4&'));
          expect(location, isNot(contains('hbe=')));
        }
      });

      test('nothing is read when no layout is set', () async {
        var reads = 0;
        final door = PaywallDoor(
          remoteValue: (_) => '',
          developer: (_) => null,
          hasSeenFalseAlarm: () => true,
          markFalseAlarmSeen: () async {},
          readLeavingFacts: () async {
            reads++;
            return good;
          },
        );
        expect(
          await door.leavingLocation(ends),
          '/paywall?source=plan_sheet_ending',
        );
        expect(reads, 0);
      });
    });

    test(
      'a pinned layout or a Developer options choice outranks the table',
      () async {
        final remote = _Install()
          ..hosted = 'hero'
          ..leavingFacts = good;
        final remoteLocation = await remote.door.leavingLocation(ends);
        expect(remoteLocation, startsWith('/plans/hero?'));
        expect(remoteLocation, contains('&headline=leaving'));
        // The numbers go only to the two layouts that draw them.
        expect(remoteLocation, isNot(contains('rang=')));
        expect(remoteLocation, contains('&ends=2026-10-20'));

        final developer = _Install()
          ..hosted = 'auto'
          ..devHosted = PaywallLayoutSetting.parse('wipe')
          ..leavingFacts = good;
        expect(
          await developer.door.leavingLocation(ends),
          contains('/plans/wipe?'),
        );
      },
    );

    test(
      'the second open before that date is at rest, a new date is not',
      () async {
        final install = _Install()
          ..hosted = 'auto'
          ..leavingFacts = good;
        final first = await install.door.leavingLocation(ends);
        expect(first, isNot(contains('rest=1')));
        expect(install.leavingShown, '2026-10-20');
        final second = await install.door.leavingLocation(ends);
        expect(second, contains('&ends=2026-10-20&rest=1&'));
        expect(install.leavingMarks, 1, reason: 'the rest open writes nothing');
        final later = await install.door.leavingLocation(
          DateTime(2026, 11, 20),
        );
        expect(later, isNot(contains('rest=1')));
        expect(install.leavingShown, '2026-11-20');
      },
    );

    test('a flag that cannot be saved still opens the paywall', () async {
      final install = _Install()
        ..hosted = 'auto'
        ..leavingFacts = good
        ..leavingMarkThrows = true;
      expect(
        await install.door.leavingLocation(ends),
        contains('/plans/receipt?'),
      );
    });

    test(
      'with no layout set the shipped paywall opens and nothing is written',
      () async {
        final install = _Install()..leavingFacts = good;
        expect(
          await install.door.leavingLocation(ends),
          '/paywall?source=plan_sheet_ending',
        );
        expect(install.leavingMarks, 0);
      },
    );

    test('the door never throws', () async {
      final install = _Install()
        ..hosted = 'auto'
        ..remoteThrows = true;
      expect(
        await install.door.leavingLocation(ends),
        '/paywall?source=plan_sheet_ending',
      );
    });

    test('the receipt opens from this place and no other', () async {
      final install = _Install()
        ..hosted = 'auto'
        ..leavingFacts = good;
      for (final source in PaywallSource.values) {
        if (source == PaywallSource.planSheetEnding) continue;
        expect(
          install.door.hostedLocation(source),
          isNot(contains('/plans/receipt')),
          reason: source.wire,
        );
        expect(
          install.door.resolve(paywallLocation(source)),
          isNot(contains('/plans/receipt')),
          reason: source.wire,
        );
      }
      // The same sheet's other way in, with no numbers counted, is Wipe.
      expect(
        install.door.hostedLocation(PaywallSource.planSheetEnding),
        contains('/plans/wipe?'),
      );
    });
  });

  group('the outro value', () {
    test('rides in the location, after the thanks', () {
      final install = _Install()
        ..hosted = 'hero'
        ..hostedThanks = 'stamp'
        ..hostedOutro = ' cloud_climb '
        ..pro = 'sheet'
        ..proThanks = 'confetti'
        ..proOutro = 'break_lift_ring';
      expect(
        install.door.hostedLocation(PaywallSource.history),
        '/plans/hero?product=hosted&source=history'
        '&thanks=stamp&outro=cloud_climb&lead=history',
      );
      expect(
        install.door.resolve(paywallLocation(PaywallSource.history)),
        '/plans/hero?product=hosted&source=history'
        '&thanks=stamp&outro=cloud_climb&lead=history',
      );
      expect(
        install.door.proLayoutLocation(ProPackSheetSource.reliability),
        '/plans/sheet?product=pro&source=reliability'
        '&thanks=confetti&outro=break_lift_ring',
      );
    });

    test('an outro this build cannot draw is no outro', () {
      final install = _Install()
        ..hosted = 'hero'
        ..hostedThanks = 'stamp'
        ..hostedOutro = 'cloud_climb'
        ..outrosAreBuilt = false;
      // The thanks still plays.
      expect(
        install.door.hostedLocation(PaywallSource.history),
        '/plans/hero?product=hosted&source=history&thanks=stamp'
        '&lead=history',
      );
    });

    test('a value this build does not know is no outro', () {
      final install = _Install()
        ..hosted = 'hero'
        ..hostedThanks = 'stamp'
        ..hostedOutro = 'fireworks';
      expect(
        install.door.hostedLocation(PaywallSource.history),
        '/plans/hero?product=hosted&source=history&thanks=stamp'
        '&lead=history',
      );
    });

    test('a thanks this build cannot play takes the outro with it', () {
      final install = _Install()
        ..hosted = 'hero'
        ..hostedThanks = 'stamp'
        ..hostedOutro = 'cloud_climb'
        ..thanksAreBuilt = false;
      expect(
        install.door.hostedLocation(PaywallSource.history),
        '/plans/hero?product=hosted&source=history&lead=history',
      );
    });

    test('the developer value outranks the remote one, none included', () {
      final install = _Install()
        ..hosted = 'hero'
        ..hostedThanks = 'stamp'
        ..hostedOutro = 'cloud_climb'
        ..devHostedOutro = PaywallOutroId.breakLiftRing;
      expect(
        install.door.hostedLocation(PaywallSource.history),
        '/plans/hero?product=hosted&source=history'
        '&thanks=stamp&outro=break_lift_ring&lead=history',
      );
      install.devHostedOutro = PaywallOutroId.none;
      expect(
        install.door.hostedLocation(PaywallSource.history),
        '/plans/hero?product=hosted&source=history&thanks=stamp'
        '&lead=history',
      );
    });

    test('alone it changes nothing: empty layout is the shipped surface', () {
      final install = _Install()
        ..hostedOutro = 'cloud_climb'
        ..devHostedOutro = PaywallOutroId.breakLiftRing;
      expect(
        install.door.hostedLocation(PaywallSource.history),
        '/paywall?source=history',
      );
    });

    test('with nothing injected a door has no outro', () {
      final door = PaywallDoor(
        remoteValue: (_) => 'hero',
        developer: (_) => null,
        hasSeenFalseAlarm: () => false,
        markFalseAlarmSeen: () async {},
      );
      expect(
        door.hostedLocation(PaywallSource.history),
        '/plans/hero?product=hosted&source=history&lead=history',
      );
    });
  });
}
