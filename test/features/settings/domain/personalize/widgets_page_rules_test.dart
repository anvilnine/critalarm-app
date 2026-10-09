import 'package:critalarm/core/access/feature_decision.dart';
import 'package:critalarm/core/access/holding.dart';
import 'package:critalarm/features/settings/domain/personalize/widgets_page_rules.dart';
import 'package:critalarm/features/topics/domain/setup_checklist.dart';
import 'package:flutter/foundation.dart' show TargetPlatform;
import 'package:flutter_test/flutter_test.dart';

// What the plan states of the page decide. The decisions are what
// `FeatureAccess.decide(AppFeature.widgets)` answers in each state:
//
//   Free, Hosted held        locked, Pro is the offer (Hosted does not open
//                            widgets)
//   Pro held                 open
//   Own server, Pro held     open
//   Own server, nothing held locked
//   Confirming               a purchase of Pro waits to be confirmed
const _locked = FeatureDecision.locked(Holding.pro);

void main() {
  group('the widget kinds', () {
    test('are three, in the order the page draws them', () {
      expect(homeWidgetKinds, [
        HomeWidgetKind.openIncidents,
        HomeWidgetKind.topic,
        HomeWidgetKind.topics,
      ]);
    });
  });

  group('the page exists', () {
    test('on iOS and Android', () {
      expect(widgetsPageExistsOn(TargetPlatform.iOS), isTrue);
      expect(widgetsPageExistsOn(TargetPlatform.android), isTrue);
    });

    test('nowhere else', () {
      for (final platform in [
        TargetPlatform.macOS,
        TargetPlatform.windows,
        TargetPlatform.linux,
        TargetPlatform.fuchsia,
      ]) {
        expect(widgetsPageExistsOn(platform), isFalse, reason: '$platform');
      }
    });
  });

  group('the buttons', () {
    List<WidgetsPageButton> buttons(
      FeatureDecision decision, {
      bool isPlanRead = true,
    }) => widgetsPageButtonsFor(
      decision: decision,
      isPlanRead: isPlanRead,
    ).all;

    const both = [WidgetsPageButton.seePlan, WidgetsPageButton.howToAdd];
    const howToOnly = [WidgetsPageButton.howToAdd];

    test('Free: See Pro and How to add one, See Pro first', () {
      expect(buttons(_locked), both);
      expect(
        widgetsPageButtonsFor(decision: _locked, isPlanRead: true).primary,
        WidgetsPageButton.seePlan,
      );
    });

    test('Hosted held: the same as Free, Hosted does not open widgets', () {
      expect(buttons(_locked), both);
    });

    test('Pro held: How to add one alone, as the primary', () {
      expect(buttons(const FeatureDecision.open()), howToOnly);
      expect(
        widgetsPageButtonsFor(
          decision: const FeatureDecision.open(),
          isPlanRead: true,
        ).primary,
        WidgetsPageButton.howToAdd,
      );
    });

    test('plan not read: How to add one alone, whatever the guess says', () {
      expect(buttons(_locked, isPlanRead: false), howToOnly);
      expect(
        buttons(const FeatureDecision.open(), isPlanRead: false),
        howToOnly,
      );
    });

    test('own server with Pro: How to add one alone', () {
      expect(buttons(const FeatureDecision.open()), howToOnly);
    });

    test('own server without Pro: the same as Free', () {
      expect(buttons(_locked), both);
    });

    test('confirming: usable, so How to add one alone', () {
      expect(
        buttons(const FeatureDecision.confirming(Holding.pro)),
        howToOnly,
      );
    });

    test('plan unreadable: usable, nothing is sold', () {
      expect(buttons(const FeatureDecision.unread(Holding.pro)), howToOnly);
    });

    test('not offered: nothing is sold', () {
      expect(buttons(const FeatureDecision.notOffered()), howToOnly);
    });
  });

  group('the plan the steps sheet words itself for', () {
    HomeWidgetsPlan plan(
      FeatureDecision decision, {
      bool isPlanRead = true,
      bool isOwnServer = false,
    }) => widgetsSheetPlanFor(
      decision: decision,
      isPlanRead: isPlanRead,
      isOwnServer: isOwnServer,
    );

    test('locked asks for Pro, on Cloud and on an own server', () {
      expect(plan(_locked), HomeWidgetsPlan.needsPro);
      expect(plan(_locked, isOwnServer: true), HomeWidgetsPlan.needsPro);
    });

    test('open follows the server', () {
      expect(plan(const FeatureDecision.open()), HomeWidgetsPlan.pro);
      expect(
        plan(const FeatureDecision.open(), isOwnServer: true),
        HomeWidgetsPlan.selfHosted,
      );
    });

    test('before the plan is read the sheet sells nothing', () {
      expect(plan(_locked, isPlanRead: false), HomeWidgetsPlan.pro);
      expect(
        plan(_locked, isPlanRead: false, isOwnServer: true),
        HomeWidgetsPlan.selfHosted,
      );
    });

    test('confirming and unreadable are usable', () {
      expect(
        plan(const FeatureDecision.confirming(Holding.pro)),
        HomeWidgetsPlan.pro,
      );
      expect(
        plan(const FeatureDecision.unread(Holding.pro)),
        HomeWidgetsPlan.pro,
      );
    });
  });
}
