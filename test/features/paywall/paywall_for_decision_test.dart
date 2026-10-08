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
    });

    test('a place has the same wire name on both paywalls', () {
      for (final source in LockSource.values) {
        if (source == LockSource.reliability) continue;
        expect(source.pro.wire, source.hosted.wire, reason: source.name);
      }
    });

    test('a place opens the same kind of layout on both paywalls', () {
      for (final source in LockSource.values) {
        if (source == LockSource.reliability) continue;
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
