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
import 'package:critalarm/features/paywall/domain/lock_source.dart';
import 'package:critalarm/features/paywall/domain/paywall_lead_facts.dart';
import 'package:critalarm/features/paywall/domain/paywall_routing.dart';
import 'package:critalarm/features/paywall/presentation/paywall_door.dart';
import 'package:critalarm/features/pro_pack/domain/pro_pack_analytics.dart';
import 'package:flutter_test/flutter_test.dart';

/// What a store build puts after the source for each product: the coded
/// thanks and the coded outro.
const _hostedEnd = '&thanks=party&outro=cloud_climb';
const _proEnd = '&thanks=stamp&outro=break_lift_ring';

class _Install {
  _Install();

  /// An install whose paywalls end with no thanks and so no outro, set the
  /// way Developer options sets it. For a test about another part of the
  /// location, so its expected text is only that part.
  _Install.plain()
    : devHostedThanks = PaywallThanksId.none,
      devProThanks = PaywallThanksId.none;

  PaywallIntroId? devHostedIntro;
  PaywallIntroId? devProIntro;
  PaywallThanksId? devHostedThanks;
  PaywallThanksId? devProThanks;
  bool thanksAreBuilt = true;
  PaywallOutroId? devHostedOutro;
  PaywallOutroId? devProOutro;
  bool outrosAreBuilt = true;
  PaywallLayoutSetting? devHosted;
  PaywallLayoutSetting? devPro;
  bool seen = false;
  int marks = 0;
  bool falseAlarmIsBuilt = true;
  bool developerThrows = false;
  bool everythingThrows = false;
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
    developer: (product) {
      if (developerThrows || everythingThrows) throw StateError('no prefs');
      return product == PaywallProduct.hosted ? devHosted : devPro;
    },
    hasSeenFalseAlarm: () => seen,
    markFalseAlarmSeen: () async {
      seen = true;
      marks++;
    },
    developerIntro: (product) =>
        product == PaywallProduct.hosted ? devHostedIntro : devProIntro,
    isIntroBuilt: (intro) =>
        intro != PaywallIntroId.falseAlarm || falseAlarmIsBuilt,
    developerThanks: (product) =>
        product == PaywallProduct.hosted ? devHostedThanks : devProThanks,
    isThanksBuilt: (thanks) {
      if (everythingThrows) throw StateError('no registry');
      return thanks == PaywallThanksId.none || thanksAreBuilt;
    },
    developerOutro: (product) =>
        product == PaywallProduct.hosted ? devHostedOutro : devProOutro,
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

PaywallLayoutSetting _pin(PaywallLayoutId layout) =>
    PaywallLayoutSetting.pinned(layout);

void main() {
  group('with no setting of any kind', () {
    test('every Hosted source opens the layout of its place', () {
      final install = _Install();
      for (final source in PaywallSource.values) {
        final location = install.door.hostedLocation(source);
        final uri = Uri.parse(location);
        expect(
          uri.path,
          '/plans/${paywallRowFor(paywallPlaceOf(source)).layout.key}',
          reason: source.wire,
        );
        expect(uri.queryParameters['product'], 'hosted', reason: source.wire);
        expect(uri.queryParameters['source'], source.wire);
        expect(uri.queryParameters['thanks'], 'party', reason: source.wire);
        expect(uri.queryParameters['outro'], 'cloud_climb');
      }
    });

    test('every Pro source opens the layout of its place', () {
      final install = _Install();
      for (final source in ProPackSheetSource.values) {
        final uri = Uri.parse(install.door.proLayoutLocation(source));
        expect(
          uri.path,
          '/plans/${paywallRowFor(paywallPlaceOfPro(source)).layout.key}',
          reason: source.wire,
        );
        expect(uri.queryParameters['product'], 'pro', reason: source.wire);
        expect(uri.queryParameters['source'], source.wire);
        expect(uri.queryParameters['thanks'], 'stamp', reason: source.wire);
        expect(uri.queryParameters['outro'], 'break_lift_ring');
        expect(uri.queryParameters.containsKey('intro'), isFalse);
      }
    });

    test('no source resolves to /pro, /paywall or an old surface', () {
      final install = _Install();
      final locations = [
        for (final source in PaywallSource.values) ...[
          install.door.hostedLocation(source),
          if (source != PaywallSource.widgetLocked)
            install.door.resolve(paywallLocation(source)),
        ],
        for (final source in ProPackSheetSource.values)
          install.door.proLayoutLocation(source),
        install.door.resolve('/paywall'),
        install.door.resolve('/paywall?source=nonsense'),
      ];
      for (final location in locations) {
        expect(location, startsWith('/plans/'), reason: location);
        expect(Uri.parse(location).path, isNot('/pro'));
        expect(Uri.parse(location).path, isNot(paywallPath));
      }
    });

    test('every lock opens a layout for whichever product it offers', () {
      final install = _Install();
      getIt.registerSingleton<PaywallDoor>(install.door);
      addTearDown(() => getIt.unregister<PaywallDoor>());
      for (final lock in LockSource.values) {
        for (final offer in Holding.values) {
          final location = paywallLocationFor(
            FeatureDecision.locked(offer),
            lock,
          );
          expect(location, isNotNull, reason: '$lock $offer');
          final uri = Uri.parse(location!);
          expect(uri.path, startsWith('/plans/'), reason: '$lock $offer');
          expect(
            uri.queryParameters['product'],
            offer == Holding.hosted ? 'hosted' : 'pro',
            reason: '$lock $offer',
          );
        }
      }
    });

    test('a decision that locks nothing opens nothing', () {
      for (final decision in const [
        FeatureDecision.open(),
        FeatureDecision.confirming(Holding.pro),
        FeatureDecision.unread(Holding.pro),
      ]) {
        expect(paywallLocationFor(decision, LockSource.sounds), isNull);
      }
    });

    test('the raw paths the app builds with no door at hand open layouts', () {
      final install = _Install();
      // A reminder's two routes, the settings search result, and a link
      // with no source or one this build does not know.
      expect(
        install.door.resolve(
          paywallLocation(PaywallSource.reminderMorningAfter),
        ),
        '/plans/reel?product=hosted&source=reminder_morning_after$_hostedEnd',
      );
      expect(
        install.door.resolve(paywallLocation(PaywallSource.reminderProLater)),
        '/plans/reel?product=hosted&source=reminder_pro_later$_hostedEnd',
      );
      expect(
        install.door.resolve(paywallLocation(PaywallSource.settingsSearch)),
        '/plans/hero?product=hosted&source=settings_search$_hostedEnd',
      );
      expect(
        install.door.resolve('/paywall'),
        '/plans/hero?product=hosted&source=direct$_hostedEnd',
      );
      expect(
        install.door.resolve('/paywall?source=heroo'),
        '/plans/hero?product=hosted&source=direct$_hostedEnd',
      );
      // A locked home screen widget.
      expect(
        install.door.resolve(PushDeepLink.paywallLocation),
        '/plans/sheet?product=pro&source=widget_locked$_proEnd&lead=widgets',
      );
      expect(install.marks, 0);
    });

    test('with no door registered the helpers open the plan layout', () {
      expect(getIt.isRegistered<PaywallDoor>(), isFalse);
      expect(
        hostedPaywallLocation(PaywallSource.settingsPlan),
        '/plans/hero?product=hosted&source=settings_plan$_hostedEnd',
      );
      expect(
        hostedPaywallLocation(PaywallSource.history),
        '/plans/hero?product=hosted&source=history$_hostedEnd',
      );
      expect(
        resolvePaywallLocation('/paywall?source=history'),
        '/plans/hero?product=hosted&source=history$_hostedEnd',
      );
      expect(
        resolvePaywallLocation('/paywall'),
        '/plans/hero?product=hosted&source=direct$_hostedEnd',
      );
      expect(resolvePaywallLocation('/ring'), '/ring');
      expect(
        proPaywallLocation(ProPackSheetSource.sounds),
        '/plans/hero?product=pro&source=sounds$_proEnd',
      );
      for (final lock in LockSource.values) {
        expect(
          paywallLocationFor(const FeatureDecision.locked(Holding.pro), lock),
          '/plans/hero?product=pro&source=${lock.pro.wire}$_proEnd',
        );
        expect(
          paywallLocationFor(
            const FeatureDecision.locked(Holding.hosted),
            lock,
          ),
          '/plans/hero?product=hosted&source=${lock.hosted.wire}$_hostedEnd',
        );
      }
    });

    test('with no door registered the async helpers do the same', () async {
      expect(
        await hostedPaywallLocationWithOwn(PaywallSource.history),
        '/plans/hero?product=hosted&source=history$_hostedEnd',
      );
      expect(
        await leavingPaywallLocation(DateTime(2026, 10, 20)),
        '/plans/hero?product=hosted&source=plan_sheet_ending$_hostedEnd',
      );
    });

    test('a read that throws opens the plan layout for that product', () {
      final install = _Install()..developerThrows = true;
      expect(
        install.door.hostedLocation(PaywallSource.history),
        '/plans/hero?product=hosted&source=history$_hostedEnd',
      );
      expect(
        install.door.proLayoutLocation(ProPackSheetSource.reliability),
        '/plans/hero?product=pro&source=reliability$_proEnd',
      );
      expect(
        install.door.resolve('/paywall?source=history'),
        '/plans/hero?product=hosted&source=history$_hostedEnd',
      );
      expect(
        install.door.openingFor(PaywallProduct.pro, PaywallPlace.widgets),
        install.door.planOpeningFor(PaywallProduct.pro),
      );
    });

    test('with every read failing it still opens the bare plan layout', () {
      final install = _Install()..everythingThrows = true;
      expect(
        install.door.hostedLocation(PaywallSource.history),
        '/plans/hero?product=hosted&source=history',
      );
      expect(
        install.door.proLayoutLocation(ProPackSheetSource.sounds),
        '/plans/hero?product=pro&source=sounds',
      );
    });
  });

  group('a tap on a locked widget', () {
    final tap = paywallLocation(PaywallSource.widgetLocked);
    const proWidgets =
        '/plans/sheet?product=pro&source=widget_locked$_proEnd&lead=widgets';

    test('opens the Pro layout, because widgets are Pro', () {
      final install = _Install();
      expect(install.door.resolve(tap), proWidgets);
    });

    test('the whole route from the native tap ends at the Pro layout', () {
      final install = _Install();
      // iOS and the Android notification route say open=paywall. The
      // Android widget tap route is a bare /paywall and gets tagged.
      final fromData = PushDeepLink.fromNotificationData({'open': 'paywall'});
      expect(install.door.resolve(fromData!), proWidgets);
      expect(install.door.resolve(PushDeepLink.tagged('/paywall')), proWidgets);
    });

    test('opens the Hosted layout only if the decision offers Hosted', () {
      final install = _Install()
        ..widgets = const FeatureDecision.locked(Holding.hosted);
      expect(
        install.door.resolve(tap),
        // Hosted does not list widgets, so the location names no lead.
        '/plans/sheet?product=hosted&source=widget_locked$_hostedEnd',
      );
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
        '/plans/proof?product=hosted&source=history$_hostedEnd&lead=history',
      );
    });
  });

  group('the location', () {
    test('Hosted carries the product and the source', () {
      final install = _Install.plain();
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
    });

    test('Pro keeps its own source word', () {
      final install = _Install.plain();
      expect(
        install.door.proLayoutLocation(ProPackSheetSource.reliability),
        '/plans/proof?product=pro&source=reliability',
      );
    });

    test('a path that is not the paywall is left alone', () {
      final install = _Install();
      for (final path in ['/', '/ring', '/paywall/success', '/topics/a?x=1']) {
        expect(install.door.resolve(path), path);
      }
    });

    test('a layout never asks for the list of every benefit', () {
      final install = _Install()..devPro = _pin(PaywallLayoutId.hero);
      expect(
        install.door.hostedLocation(PaywallSource.direct),
        isNot(contains('benefits')),
      );
      expect(
        install.door.proLayoutLocation(ProPackSheetSource.direct),
        isNot(contains('benefits')),
      );
    });

    test('a layout pinned in Developer options outranks the table', () {
      final install = _Install.plain()
        ..devHosted = _pin(PaywallLayoutId.bento)
        ..devPro = _pin(PaywallLayoutId.proof);
      expect(
        install.door.hostedLocation(PaywallSource.history),
        '/plans/bento?product=hosted&source=history&lead=history',
      );
      expect(
        install.door.proLayoutLocation(ProPackSheetSource.direct),
        '/plans/proof?product=pro&source=direct',
      );
    });
  });

  group('the false alarm intro', () {
    test('plays once at the critical topic limit, then the sheet alone', () {
      final install = _Install.plain();
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

    test('a person who saw it before does not see it again', () {
      final install = _Install.plain()..seen = true;
      expect(
        install.door.hostedLocation(PaywallSource.createTopicCard),
        '/plans/sheet?product=hosted&source=create_topic_card&lead=topics',
      );
      expect(install.marks, 0);
    });

    test('the Settings plan row plays nothing', () {
      final install = _Install.plain();
      expect(
        install.door.hostedLocation(PaywallSource.settingsPlan),
        '/plans/hero?product=hosted&source=settings_plan',
      );
      expect(install.marks, 0);
    });

    test('other places neither play it nor use up its showing', () {
      final install = _Install();
      for (final source in PaywallSource.values) {
        if (source == PaywallSource.createTopicCard) continue;
        expect(
          install.door.hostedLocation(source),
          isNot(contains('false_alarm')),
        );
      }
      expect(install.marks, 0);
    });

    test('Pro never plays it from the critical limit', () {
      final install = _Install.plain();
      expect(
        install.door.proLayoutLocation(ProPackSheetSource.createTopicCard),
        '/plans/sheet?product=pro&source=create_topic_card',
      );
      expect(install.marks, 0);
    });

    test(
      'a build that cannot play it opens the sheet and keeps the showing',
      () {
        final install = _Install.plain()..falseAlarmIsBuilt = false;
        expect(
          install.door.hostedLocation(PaywallSource.createTopicCard),
          '/plans/sheet?product=hosted&source=create_topic_card&lead=topics',
        );
        expect(install.marks, 0);
      },
    );
  });

  group('the developer intro', () {
    test('goes in the location beside any layout, for both products', () {
      final install = _Install.plain()
        ..devHosted = _pin(PaywallLayoutId.sheet)
        ..devHostedIntro = PaywallIntroId.falseAlarm
        ..devPro = _pin(PaywallLayoutId.proof)
        ..devProIntro = PaywallIntroId.falseAlarm;
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

    test('none outranks the table', () {
      final install = _Install.plain()..devHostedIntro = PaywallIntroId.none;
      expect(
        install.door.hostedLocation(PaywallSource.createTopicCard),
        '/plans/sheet?product=hosted&source=create_topic_card&lead=topics',
      );
      expect(install.marks, 0);
    });
  });

  group('the thanks', () {
    test('with nothing set Hosted takes Receipt party and Pro Stamp', () {
      final install = _Install();
      expect(
        install.door.hostedLocation(PaywallSource.history),
        '/plans/proof?product=hosted&source=history'
        '&thanks=party&outro=cloud_climb&lead=history',
      );
      expect(
        install.door.resolve('/paywall?source=history'),
        '/plans/proof?product=hosted&source=history'
        '&thanks=party&outro=cloud_climb&lead=history',
      );
      expect(
        install.door.proLayoutLocation(ProPackSheetSource.direct),
        '/plans/hero?product=pro&source=direct'
        '&thanks=stamp&outro=break_lift_ring',
      );
    });

    test('with nothing injected a door takes the same defaults', () {
      final door = PaywallDoor(
        developer: (_) => null,
        hasSeenFalseAlarm: () => false,
        markFalseAlarmSeen: () async {},
      );
      expect(
        door.hostedLocation(PaywallSource.history),
        '/plans/proof?product=hosted&source=history$_hostedEnd&lead=history',
      );
      expect(
        door.proLayoutLocation(ProPackSheetSource.sounds),
        '/plans/sheet?product=pro&source=sounds$_proEnd&lead=custom_sounds',
      );
    });

    test('goes after the intro, and neither drops the other', () {
      final install = _Install()..devHostedThanks = PaywallThanksId.unlock;
      expect(
        install.door.hostedLocation(PaywallSource.createTopicCard),
        '/plans/sheet?product=hosted&source=create_topic_card'
        '&intro=false_alarm&thanks=unlock&outro=cloud_climb&lead=topics',
      );
      // The intro has had its one showing. The thanks has no such rule.
      expect(
        install.door.hostedLocation(PaywallSource.createTopicCard),
        '/plans/sheet?product=hosted&source=create_topic_card'
        '&thanks=unlock&outro=cloud_climb&lead=topics',
      );
    });

    test('an intro this build cannot play keeps the thanks', () {
      final install = _Install()
        ..devHostedIntro = PaywallIntroId.falseAlarm
        ..falseAlarmIsBuilt = false;
      expect(
        install.door.hostedLocation(PaywallSource.settingsPlan),
        '/plans/hero?product=hosted&source=settings_plan$_hostedEnd',
      );
      expect(install.marks, 0);
    });

    test('a thanks this build cannot play is no thanks, and no outro', () {
      final install = _Install()
        ..devHostedIntro = PaywallIntroId.falseAlarm
        ..thanksAreBuilt = false;
      // The intro still plays.
      expect(
        install.door.hostedLocation(PaywallSource.history),
        '/plans/proof?product=hosted&source=history&intro=false_alarm&lead=history',
      );
      expect(
        install.door.proLayoutLocation(ProPackSheetSource.reliability),
        '/plans/proof?product=pro&source=reliability',
      );
    });

    test('Developer options outrank the default, none included', () {
      final install = _Install()
        ..devHostedThanks = PaywallThanksId.none
        ..devProThanks = PaywallThanksId.unlock;
      expect(
        install.door.hostedLocation(PaywallSource.history),
        '/plans/proof?product=hosted&source=history&lead=history',
      );
      expect(
        install.door.proLayoutLocation(ProPackSheetSource.direct),
        '/plans/hero?product=pro&source=direct'
        '&thanks=unlock&outro=break_lift_ring',
      );
      for (final thanks in PaywallThanksId.values) {
        if (thanks == PaywallThanksId.none) continue;
        install.devHostedThanks = thanks;
        expect(
          Uri.parse(
            install.door.hostedLocation(PaywallSource.settingsPlan),
          ).queryParameters['thanks'],
          thanks.key,
        );
      }
    });
  });

  group('the lead and the headline', () {
    test('a place with a lead puts it in the location', () {
      final install = _Install.plain();
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
      final install = _Install.plain();
      expect(
        install.door.hostedLocation(PaywallSource.planSheetEnded),
        '/plans/wipe?product=hosted&source=plan_sheet_ended'
        '&lead=history&headline=ended',
      );
    });

    test('a lead this build does not list is left out', () {
      final install = _Install.plain();
      final door = PaywallDoor(
        developer: (_) => null,
        developerThanks: (_) => PaywallThanksId.none,
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
      final install = _Install.plain();
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
      final install = _Install.plain();
      expect(
        install.door.hostedLocation(PaywallSource.history, own: own),
        '/plans/proof?product=hosted&source=history&lead=history'
        '&hin=prod-db%3A1&hbe=nas%3A12%2Cprod-db%3A81',
      );
    });

    test('a place with another lead leaves them out', () {
      final install = _Install.plain();
      expect(
        install.door.hostedLocation(PaywallSource.appIcon, own: own),
        '/plans/sheet?product=hosted&source=app_icon&lead=app_icons',
      );
    });

    test('with no rows older than the window nothing is added', () {
      final install = _Install.plain();
      expect(
        install.door.hostedLocation(PaywallSource.history),
        '/plans/proof?product=hosted&source=history&lead=history',
      );
    });

    test('the ended plan carries the rows the phone still holds', () async {
      final install = _Install.plain()
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
      final install = _Install.plain();
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
        final install = _Install.plain()
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
      final install = _Install.plain()..historyOwn = own;
      expect(await install.door.readHistoryOwn(), isNotNull);
      install.historyOwnThrows = true;
      expect(await install.door.readHistoryOwn(), isNull);
    });
  });

  group('the facts of the critical limit', () {
    test('a topics lead carries the count and the name', () {
      final install = _Install.plain()..seen = true;
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
      final install = _Install.plain();
      expect(
        install.door.hostedLocation(
          PaywallSource.history,
          facts: const PaywallLeadFacts(used: 2, limit: 2),
        ),
        '/plans/proof?product=hosted&source=history&lead=history',
      );
    });

    test('empty facts add nothing', () {
      final install = _Install.plain()..seen = true;
      expect(
        install.door.hostedLocation(
          PaywallSource.createTopicCard,
          facts: const PaywallLeadFacts(),
        ),
        '/plans/sheet?product=hosted&source=create_topic_card&lead=topics',
      );
    });

    test('a name the location cannot hold is left out, the paywall opens', () {
      final install = _Install.plain()..seen = true;
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
      final install = _Install.plain();
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
        final install = _Install.plain()..leavingFacts = good;
        expect(
          await install.door.leavingLocation(ends),
          '/plans/receipt?product=hosted&source=plan_sheet_ending'
          '&headline=leaving&ends=2026-10-20'
          '&rang=142&ans=139&nights=9&crit=4&days=61',
        );
      },
    );

    test('thin numbers open Wipe on history', () async {
      final install = _Install.plain()..leavingFacts = thin;
      expect(
        await install.door.leavingLocation(ends),
        '/plans/wipe?product=hosted&source=plan_sheet_ending&lead=history'
        '&headline=leaving&ends=2026-10-20'
        '&rang=4&ans=4&nights=0&crit=1&days=20',
      );
    });

    test('two numbers over their floor are enough, one is not', () async {
      // Alarms that rang and critical topics clear. Answered, nights do not.
      final two = _Install.plain()
        ..leavingFacts = const LeavingFacts(
          rang: 12,
          answered: 2,
          nights: 1,
          criticalTopics: 3,
          historyDaysHeld: 30,
        );
      expect(await two.door.leavingLocation(ends), contains('/plans/receipt?'));
      final one = _Install.plain()
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
      final install = _Install.plain()..leavingFacts = young;
      expect(
        await install.door.leavingLocation(ends),
        contains(
          '/plans/wipe?product=hosted&source=plan_sheet_ending&lead=topics',
        ),
      );
    });

    test('the rows the phone holds ride along for a Wipe on history', () async {
      final install = _Install.plain()
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
        final install = _Install.plain()
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
      final install = _Install.plain()
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
        final install = _Install.plain();
        expect(await install.door.leavingLocation(ends), wipeWithoutNumbers);
      });

      test('a read that throws opens Wipe and never throws', () async {
        final install = _Install.plain()
          ..leavingFacts = good
          ..leavingThrows = true;
        expect(await install.door.leavingLocation(ends), wipeWithoutNumbers);
      });

      test(
        'a read that never answers opens Wipe once the wait is up',
        () async {
          final install = _Install.plain()
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
          final install = _Install.plain()..leavingFacts = thin;
          fail(install);
          final location = await install.door.leavingLocation(ends);
          expect(location, contains('/plans/wipe?'));
          expect(location, contains('&rang=4&'));
          expect(location, isNot(contains('hbe=')));
        }
      });
    });

    test('a layout pinned in Developer options outranks the table', () async {
      final pinned = _Install.plain()
        ..devHosted = _pin(PaywallLayoutId.hero)
        ..leavingFacts = good;
      final location = await pinned.door.leavingLocation(ends);
      expect(location, startsWith('/plans/hero?'));
      expect(location, contains('&headline=leaving'));
      // The numbers go only to the two layouts that draw them.
      expect(location, isNot(contains('rang=')));
      expect(location, contains('&ends=2026-10-20'));

      final wipe = _Install.plain()
        ..devHosted = _pin(PaywallLayoutId.wipe)
        ..leavingFacts = good;
      expect(await wipe.door.leavingLocation(ends), contains('/plans/wipe?'));
    });

    test(
      'the second open before that date is at rest, a new date is not',
      () async {
        final install = _Install.plain()..leavingFacts = good;
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
      final install = _Install.plain()
        ..leavingFacts = good
        ..leavingMarkThrows = true;
      expect(
        await install.door.leavingLocation(ends),
        contains('/plans/receipt?'),
      );
    });

    test('the door never throws', () async {
      // What Developer options set cannot be read: the plan layout opens,
      // with the end date, and the numbers stay out of a layout that does
      // not draw them.
      final install = _Install()
        ..developerThrows = true
        ..leavingFacts = good;
      expect(
        await install.door.leavingLocation(ends),
        '/plans/hero?product=hosted&source=plan_sheet_ending$_hostedEnd'
        '&ends=2026-10-20',
      );
      final broken = _Install()..everythingThrows = true;
      expect(
        await broken.door.leavingLocation(ends),
        '/plans/hero?product=hosted&source=plan_sheet_ending&ends=2026-10-20',
      );
    });

    test('the receipt opens from this place and no other', () async {
      final install = _Install.plain()..leavingFacts = good;
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

  group('the outro', () {
    test('rides in the location, after the thanks', () {
      final install = _Install()
        ..devHosted = _pin(PaywallLayoutId.hero)
        ..devHostedThanks = PaywallThanksId.stamp
        ..devHostedOutro = PaywallOutroId.breakLift
        ..devPro = _pin(PaywallLayoutId.sheet)
        ..devProThanks = PaywallThanksId.confetti
        ..devProOutro = PaywallOutroId.cloudClimb;
      expect(
        install.door.hostedLocation(PaywallSource.history),
        '/plans/hero?product=hosted&source=history'
        '&thanks=stamp&outro=break_lift&lead=history',
      );
      expect(
        install.door.resolve(paywallLocation(PaywallSource.history)),
        '/plans/hero?product=hosted&source=history'
        '&thanks=stamp&outro=break_lift&lead=history',
      );
      expect(
        install.door.proLayoutLocation(ProPackSheetSource.reliability),
        '/plans/sheet?product=pro&source=reliability'
        '&thanks=confetti&outro=cloud_climb',
      );
    });

    test('with nothing set each product plays its own', () {
      final install = _Install();
      expect(
        install.door.hostedLocation(PaywallSource.settingsPlan),
        '/plans/hero?product=hosted&source=settings_plan'
        '&thanks=party&outro=cloud_climb',
      );
      expect(
        install.door.proLayoutLocation(ProPackSheetSource.direct),
        '/plans/hero?product=pro&source=direct'
        '&thanks=stamp&outro=break_lift_ring',
      );
    });

    test('an outro this build cannot draw is no outro', () {
      final install = _Install()..outrosAreBuilt = false;
      // The thanks still plays.
      expect(
        install.door.hostedLocation(PaywallSource.history),
        '/plans/proof?product=hosted&source=history&thanks=party'
        '&lead=history',
      );
    });

    test('a thanks this build cannot play takes the outro with it', () {
      final install = _Install()
        ..devHostedOutro = PaywallOutroId.cloudClimb
        ..thanksAreBuilt = false;
      expect(
        install.door.hostedLocation(PaywallSource.history),
        '/plans/proof?product=hosted&source=history&lead=history',
      );
    });

    test('the developer value outranks the default, none included', () {
      final install = _Install()..devHostedOutro = PaywallOutroId.breakLiftRing;
      expect(
        install.door.hostedLocation(PaywallSource.history),
        '/plans/proof?product=hosted&source=history'
        '&thanks=party&outro=break_lift_ring&lead=history',
      );
      install.devHostedOutro = PaywallOutroId.none;
      expect(
        install.door.hostedLocation(PaywallSource.history),
        '/plans/proof?product=hosted&source=history&thanks=party'
        '&lead=history',
      );
      install
        ..devProOutro = PaywallOutroId.none
        ..devHostedOutro = null;
      expect(
        install.door.proLayoutLocation(ProPackSheetSource.direct),
        '/plans/hero?product=pro&source=direct&thanks=stamp',
      );
    });

    test('with the thanks set to none it plays nothing', () {
      final install = _Install.plain()
        ..devHostedOutro = PaywallOutroId.cloudClimb
        ..devProOutro = PaywallOutroId.breakLiftRing;
      expect(
        install.door.hostedLocation(PaywallSource.settingsPlan),
        '/plans/hero?product=hosted&source=settings_plan',
      );
      expect(
        install.door.proLayoutLocation(ProPackSheetSource.direct),
        '/plans/hero?product=pro&source=direct',
      );
    });

    test('the leaving paywall takes the Hosted ones', () async {
      final ends = DateTime(2026, 10, 20, 14, 30);
      expect(
        await _Install().door.leavingLocation(ends),
        '/plans/wipe?product=hosted&source=plan_sheet_ending'
        '&thanks=party&outro=cloud_climb&lead=history'
        '&headline=leaving&ends=2026-10-20',
      );
      final withThanks = _Install()..devHostedThanks = PaywallThanksId.stamp;
      expect(
        await withThanks.door.leavingLocation(ends),
        '/plans/wipe?product=hosted&source=plan_sheet_ending'
        '&thanks=stamp&outro=cloud_climb&lead=history'
        '&headline=leaving&ends=2026-10-20',
      );
    });
  });
}
