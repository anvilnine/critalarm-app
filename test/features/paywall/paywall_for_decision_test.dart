import 'package:critalarm/core/access/app_feature.dart';
import 'package:critalarm/core/access/feature_decision.dart';
import 'package:critalarm/core/access/holding.dart';
import 'package:critalarm/core/api/api_session.dart';
import 'package:critalarm/core/paywall/paywall_source.dart';
import 'package:critalarm/features/paywall/domain/lock_source.dart';
import 'package:critalarm/features/paywall/domain/paywall_routing.dart';
import 'package:critalarm/features/paywall/presentation/paywall_door.dart';
import 'package:critalarm/features/pro_pack/domain/pro_pack_analytics.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../core/access/access_fakes.dart';

/// Places that sell Pro only. `PaywallSource` has no value for them, so
/// their Hosted side reads as `direct`.
const Set<LockSource> _noHostedSource = {
  LockSource.reliability,
  LockSource.sounds,
  // Wake-up challenges, on Personalize and on a topic's page.
  LockSource.personalizeChallenge,
  LockSource.topicChallenge,
};

void main() {
  group('paywallLocationFor', () {
    test('a decision that offers Hosted opens the Hosted paywall', () {
      for (final source in LockSource.values) {
        expect(
          paywallLocationFor(
            const FeatureDecision.locked(Holding.hosted),
            source,
          ),
          paywallLocation(source.hosted),
          reason: source.name,
        );
      }
    });

    test('a decision that offers Pro opens the Pro sheet', () {
      for (final source in LockSource.values) {
        expect(
          paywallLocationFor(const FeatureDecision.locked(Holding.pro), source),
          '/pro?source=${source.pro.wire}',
          reason: source.name,
        );
      }
    });

    test('the Pro sheet is told about a server of the user own', () {
      expect(
        paywallLocationFor(
          const FeatureDecision.locked(Holding.pro),
          LockSource.reliability,
          isSelfHosted: true,
        ),
        '/pro?source=reliability&self_hosted=1',
      );
    });

    test('nothing opens for a feature that is open or being confirmed', () {
      for (final decision in const [
        FeatureDecision.open(),
        FeatureDecision.confirming(Holding.hosted),
        FeatureDecision.confirming(Holding.pro),
      ]) {
        expect(
          paywallLocationFor(decision, LockSource.appIcon),
          isNull,
          reason: '$decision',
        );
      }
    });

    test('the caller names no product: the table picks it', () {
      // The same place, the same tag. Only the holdings and the feature's
      // row decide which paywall opens.
      final free = TestAccess();
      addTearDown(free.dispose);
      expect(
        paywallLocationFor(
          free.features.decide(AppFeature.appIcons),
          LockSource.appIcon,
        ),
        '/paywall?source=app_icon',
      );
      expect(
        paywallLocationFor(
          free.features.decide(AppFeature.weeklyCheck),
          LockSource.reliability,
        ),
        '/pro?source=reliability',
      );

      final ownServer = TestAccess(serverMode: ServerMode.selfhosted);
      addTearDown(ownServer.dispose);
      expect(
        paywallLocationFor(
          ownServer.features.decide(AppFeature.appIcons),
          LockSource.appIcon,
        ),
        isNull,
      );
    });
  });

  group('LockSource', () {
    test('keeps the source every Hosted entry already sends', () {
      expect(LockSource.createTopicCard.hosted, PaywallSource.createTopicCard);
      expect(LockSource.history.hosted, PaywallSource.history);
      expect(LockSource.historyOlder.hosted, PaywallSource.historyOlder);
      expect(LockSource.homeWidgets.hosted, PaywallSource.homeWidgets);
      expect(LockSource.appIcon.hosted, PaywallSource.appIcon);
      expect(LockSource.reliability.pro, ProPackSheetSource.reliability);
      expect(LockSource.sounds.pro, ProPackSheetSource.sounds);
      expect(
        LockSource.personalizeChallenge.pro,
        ProPackSheetSource.personalizeChallenge,
      );
      expect(LockSource.topicChallenge.pro, ProPackSheetSource.topicChallenge);
      // Neither has a `PaywallSource` of its own.
      for (final source in _noHostedSource) {
        expect(source.hosted, PaywallSource.direct, reason: source.name);
      }
    });

    // `PaywallSource` has no value of its own for these yet: the paywall
    // layouts switch over every value, so a new one is added there first.
    const personalize = {
      LockSource.personalizeSound,
      LockSource.personalizeWidgets,
      LockSource.personalizeAppIcon,
    };

    test('a place has the same wire name on both paywalls', () {
      for (final source in LockSource.values) {
        if (_noHostedSource.contains(source)) continue;
        if (personalize.contains(source)) continue;
        expect(source.pro.wire, source.hosted.wire, reason: source.name);
      }
    });

    test('the Personalize places have a Pro source of their own, and on '
        'the Hosted side read as the older place that sells the same', () {
      expect(
        LockSource.personalizeSound.pro,
        ProPackSheetSource.personalizeSound,
      );
      expect(LockSource.personalizeSound.hosted, PaywallSource.direct);
      expect(
        LockSource.personalizeWidgets.pro,
        ProPackSheetSource.personalizeWidgets,
      );
      expect(LockSource.personalizeWidgets.hosted, PaywallSource.homeWidgets);
      expect(
        LockSource.personalizeAppIcon.pro,
        ProPackSheetSource.personalizeAppIcon,
      );
      expect(LockSource.personalizeAppIcon.hosted, PaywallSource.appIcon);
      for (final source in personalize) {
        expect(
          paywallEntryOfProSheet(source.pro),
          PaywallEntry.lockedRow,
          reason: source.name,
        );
      }
    });

    test('a place opens the same kind of layout on both paywalls', () {
      for (final source in LockSource.values) {
        if (_noHostedSource.contains(source)) continue;
        // Nothing sells own sounds on Hosted, so it has no Hosted place.
        if (source == LockSource.personalizeSound) continue;
        expect(
          paywallEntryOfProSheet(source.pro),
          paywallEntryOf(source.hosted),
          reason: source.name,
        );
      }
    });

    test('every Pro source has a wire name of its own and parses back', () {
      final wires = {for (final s in ProPackSheetSource.values) s.wire};
      expect(wires.length, ProPackSheetSource.values.length);
      for (final source in ProPackSheetSource.values) {
        expect(ProPackSheetSource.parse(source.wire), source);
      }
    });
  });
}
