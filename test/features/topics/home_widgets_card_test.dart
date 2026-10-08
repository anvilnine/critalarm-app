import 'package:critalarm/core/access/holding.dart';
import 'package:critalarm/features/topics/domain/setup_checklist.dart';
import 'package:critalarm/features/topics/presentation/cubits/home_setup_state.dart';
import 'package:critalarm/features/topics/presentation/cubits/home_state.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/home_setup_fakes.dart';

bool _shows({
  bool isChecklistRetired = true,
  bool isSeen = false,
  bool widgetsExist = true,
  bool isGuideOfferAnswered = true,
  bool isGuideActive = false,
  bool celebratedThisVisit = false,
}) => showsHomeWidgetsCard(
  isChecklistRetired: isChecklistRetired,
  isSeen: isSeen,
  widgetsExist: widgetsExist,
  isGuideOfferAnswered: isGuideOfferAnswered,
  isGuideActive: isGuideActive,
  celebratedThisVisit: celebratedThisVisit,
);

void main() {
  group('showsHomeWidgetsCard', () {
    test('shows once the checklist is retired', () {
      expect(_shows(), isTrue);
      expect(_shows(isChecklistRetired: false), isFalse);
    });

    test('never after it was seen', () {
      expect(_shows(isSeen: true), isFalse);
    });

    test('hidden where there are no widgets', () {
      expect(_shows(widgetsExist: false), isFalse);
    });

    test('waits for the Feature Guides offer to be answered', () {
      expect(_shows(isGuideOfferAnswered: false), isFalse);
    });

    test('hidden while a guide is up', () {
      expect(_shows(isGuideActive: true), isFalse);
    });

    test('waits a visit after the celebration', () {
      expect(_shows(celebratedThisVisit: true), isFalse);
    });
  });

  group('homeScreenWidgetsExist', () {
    test('iOS and Android only, never web', () {
      for (final platform in TargetPlatform.values) {
        final expected =
            platform == TargetPlatform.iOS ||
            platform == TargetPlatform.android;
        expect(
          homeScreenWidgetsExist(platform: platform, isWeb: false),
          expected,
          reason: '$platform',
        );
        expect(
          homeScreenWidgetsExist(platform: platform, isWeb: true),
          isFalse,
        );
      }
    });
  });

  group('HomeSetupCubit, the widgets card', () {
    late HomeSetupHarness h;

    /// A phone whose checklist is already finished.
    HomeSetupHarness finished({
      TargetPlatform platform = TargetPlatform.iOS,
      bool isWeb = false,
    }) {
      final harness = HomeSetupHarness(platform: platform, isWeb: isWeb);
      harness.store
        ..isSeeded = true
        ..isDone = true;
      harness.firstMessage.isReceived = true;
      return harness;
    }

    final home = loadedHome([topicItem('prod', isCritical: true)]);

    tearDown(() => h.dispose());

    test('does not show while the checklist is live', () async {
      h = HomeSetupHarness();
      await h.open(home);
      expect(h.cubit.state.phase, HomeSetupPhase.checklist);
    });

    test('shows after the checklist is done, with the plan', () async {
      h = finished()..plan = HomeWidgetsPlan.needsPro;
      await h.open(home);
      expect(h.cubit.state.phase, HomeSetupPhase.widgetsCard);
      expect(h.cubit.state.widgetsPlan, HomeWidgetsPlan.needsPro);
    });

    test('follows the plan when it changes under the open card', () async {
      h = finished()..plan = HomeWidgetsPlan.needsPro;
      await h.open(home);
      expect(h.cubit.state.widgetsPlan, HomeWidgetsPlan.needsPro);

      // The purchase landed. The card must not stay a locked card whose
      // button opens nothing.
      h
        ..plan = HomeWidgetsPlan.pro
        ..planChanges.add(null);
      await h.settle();
      expect(h.cubit.state.phase, HomeSetupPhase.widgetsCard);
      expect(h.cubit.state.widgetsPlan, HomeWidgetsPlan.pro);
    });

    test('keeps what it shows when the plan cannot be read', () async {
      h = finished()..plan = HomeWidgetsPlan.pro;
      await h.open(home);

      h
        ..planFailure = const HoldingUnreadable(Holding.hosted)
        ..planChanges.add(null);
      await h.settle();
      expect(h.cubit.state.phase, HomeSetupPhase.widgetsCard);
      expect(h.cubit.state.widgetsPlan, HomeWidgetsPlan.pro);
    });

    test('does not appear while the plan cannot be read', () async {
      h = finished()..planFailure = const HoldingUnreadable(Holding.hosted);
      await h.open(home);
      expect(h.cubit.state.phase, isNot(HomeSetupPhase.widgetsCard));
    });

    test('a user who finished setup gets it on first sight, with no '
        'checklist and no celebration before it', () async {
      h = HomeSetupHarness()..firstMessage.isReceived = true;
      await h.open(home);
      expect(h.states.map((s) => s.phase), [HomeSetupPhase.widgetsCard]);
    });

    test('Not now sets the flag and the card never returns', () async {
      h = finished();
      await h.open(home);
      await h.cubit.widgetsCardDismissed();
      expect(h.store.isWidgetsCardSeen, isTrue);
      expect(h.cubit.state.phase, HomeSetupPhase.none);

      await h.cubit.homeChanged(loadedHome());
      await h.settle();
      expect(h.cubit.state.phase, HomeSetupPhase.none);
    });

    test('opening the how-to sets the flag', () async {
      h = finished();
      await h.open(home);
      await h.cubit.widgetsHowToOpened();
      expect(h.store.isWidgetsCardSeen, isTrue);
      expect(h.cubit.state.phase, HomeSetupPhase.none);
    });

    test('going to the plans sets the flag', () async {
      h = finished()..plan = HomeWidgetsPlan.needsPro;
      await h.open(home);
      await h.cubit.widgetsPlansOpened();
      expect(h.store.isWidgetsCardSeen, isTrue);
      expect(h.cubit.state.phase, HomeSetupPhase.none);
    });

    test('a seen card does not show on a new Home', () async {
      h = finished()..store.isWidgetsCardSeen = true;
      await h.open(home);
      expect(h.states, isEmpty);
    });

    test('hidden while a guide is up, back when it ends', () async {
      h = finished();
      await h.open(home, isGuideActive: true);
      expect(h.cubit.state.phase, HomeSetupPhase.none);

      await h.cubit.screenChanged(isInFront: true, isGuideActive: false);
      await h.settle();
      expect(h.cubit.state.phase, HomeSetupPhase.widgetsCard);

      await h.cubit.screenChanged(isInFront: true, isGuideActive: true);
      await h.settle();
      expect(h.cubit.state.phase, HomeSetupPhase.none);
      expect(h.store.isWidgetsCardSeen, isFalse);
    });

    test('waits until the Feature Guides offer is answered', () async {
      h = finished()..isGuideOfferAnswered = false;
      await h.open(home);
      expect(h.cubit.state.phase, HomeSetupPhase.none);

      h.isGuideOfferAnswered = true;
      await h.cubit.screenChanged(isInFront: true, isGuideActive: false);
      await h.settle();
      expect(h.cubit.state.phase, HomeSetupPhase.widgetsCard);
    });

    test('hidden where the platform has no widgets', () async {
      h = finished(platform: TargetPlatform.macOS);
      await h.open(home);
      expect(h.cubit.state.phase, HomeSetupPhase.none);
      await h.dispose();

      h = finished(isWeb: true);
      await h.open(home);
      expect(h.cubit.state.phase, HomeSetupPhase.none);
    });

    test('does not follow the celebration on the same visit', () async {
      h = HomeSetupHarness();
      await h.open(home);
      h.firstMessage.isReceived = true;
      await h.cubit.homeChanged(home);
      await h.settle();
      await h.fire(h.cubit.tickHold);
      await h.fire(h.cubit.celebrationHold);
      expect(h.cubit.state.phase, HomeSetupPhase.none);

      await h.cubit.homeChanged(loadedHome());
      await h.settle();
      expect(h.cubit.state.phase, HomeSetupPhase.none);
      expect(h.store.isWidgetsCardSeen, isFalse);
    });

    test(
      'a plan that cannot be read shows no card and saves nothing',
      () async {
        h = finished()..planFailure = Exception('offline');
        await h.open(home);
        expect(h.cubit.state.phase, HomeSetupPhase.none);
        expect(h.store.isWidgetsCardSeen, isFalse);
      },
    );

    test('with no server it does not show', () async {
      h = finished();
      await h.open(
        const HomeState(status: HomeStatus.failure, hasServer: false),
      );
      expect(h.cubit.state.phase, HomeSetupPhase.none);
    });
  });
}
