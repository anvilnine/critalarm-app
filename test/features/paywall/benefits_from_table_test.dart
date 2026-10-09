import 'package:critalarm/core/access/app_feature.dart';
import 'package:critalarm/core/access/holding.dart';
import 'package:critalarm/features/paywall/domain/entities/hosted_benefit.dart';
import 'package:critalarm/features/paywall/domain/entities/paywall_benefit.dart';
import 'package:critalarm/features/paywall/domain/entities/paywall_product.dart';
import 'package:flutter_test/flutter_test.dart';

const _pro = FeatureRule(
  unlockedBy: {Holding.pro},
  onOwnServer: OwnServerRule.sameAsCloud,
);
const _hosted = FeatureRule(
  unlockedBy: {Holding.hosted},
  onOwnServer: OwnServerRule.open,
);

/// The app's table with [rows] changed.
Map<AppFeature, FeatureRule> _tableWith(Map<AppFeature, FeatureRule> rows) => {
  ...featureTable,
  ...rows,
};

List<PaywallBenefitId> _ids(
  Map<AppFeature, FeatureRule> table,
  PaywallProduct product,
) => [
  for (final benefit in allPaywallBenefitsIn(table))
    if (benefit.product == product) benefit.id,
];

void main() {
  group('HostedBenefit.all', () {
    test('is what the feature table says, and the same list as before', () {
      expect(
        HostedBenefit.all.map((b) => b.id),
        hostedBenefitsIn(featureTable).map((b) => b.id),
      );
      // Pinned: the items and the order every Hosted surface has shown.
      expect(HostedBenefit.all.map((b) => b.id), [
        HostedBenefitId.topics,
        HostedBenefitId.pushes,
        HostedBenefitId.history,
        HostedBenefitId.appIcons,
      ]);
    });

    test('each benefit names the feature it stands for', () {
      expect(
        {for (final b in HostedBenefit.all) b.id: b.feature},
        {
          HostedBenefitId.topics: AppFeature.unlimitedCriticalTopics,
          // A number the relay enforces. No row in the table.
          HostedBenefitId.pushes: null,
          HostedBenefitId.history: AppFeature.longHistory,
          HostedBenefitId.appIcons: AppFeature.appIcons,
        },
      );
    });

    test('every listed feature is one Hosted unlocks in the table', () {
      for (final benefit in HostedBenefit.all) {
        final feature = benefit.feature;
        if (feature == null) continue;
        expect(
          featureTable[feature]!.unlockedBy,
          contains(Holding.hosted),
          reason: benefit.id.name,
        );
      }
    });

    test('moving a feature to Pro in the table drops it, and nothing else '
        'moves', () {
      final moved = hostedBenefitsIn(_tableWith({AppFeature.appIcons: _pro}));
      expect(moved.map((b) => b.id), [
        HostedBenefitId.topics,
        HostedBenefitId.pushes,
        HostedBenefitId.history,
      ]);
    });

    test('widgets are not a Hosted benefit: Hosted does not unlock them', () {
      expect(featureTable[AppFeature.widgets]!.unlockedBy, {Holding.pro});
      expect(
        HostedBenefit.all.map((b) => b.feature),
        isNot(contains(AppFeature.widgets)),
      );
    });

    test('the push allowance stays whatever the table says', () {
      final none = hostedBenefitsIn({
        for (final feature in AppFeature.values) feature: _pro,
      });
      expect(none.map((b) => b.id), [HostedBenefitId.pushes]);
    });
  });

  group('the layout lists', () {
    test('come out as they did before the widgets row moved', () {
      expect(_ids(featureTable, PaywallProduct.hosted), [
        PaywallBenefitId.topics,
        PaywallBenefitId.pushes,
        PaywallBenefitId.history,
        PaywallBenefitId.appIcons,
      ]);
      expect(_ids(featureTable, PaywallProduct.pro), [
        PaywallBenefitId.wakeUpChallenges,
        PaywallBenefitId.widgets,
        PaywallBenefitId.reliabilityChecks,
        PaywallBenefitId.customSounds,
        PaywallBenefitId.customAlarmScreens,
      ]);
      // What this build really has. The alarm screen looks joined the
      // day the own photo look was built.
      expect(paywallBenefitsFor(PaywallProduct.pro).map((b) => b.id), [
        PaywallBenefitId.widgets,
        PaywallBenefitId.reliabilityChecks,
        PaywallBenefitId.customAlarmScreens,
      ]);
    });

    test('each Pro benefit names the feature it stands for', () {
      expect(
        {
          for (final b in allPaywallBenefits)
            if (b.product == PaywallProduct.pro) b.id: b.feature,
        },
        {
          PaywallBenefitId.wakeUpChallenges: AppFeature.wakeUpChallenges,
          PaywallBenefitId.widgets: AppFeature.widgets,
          PaywallBenefitId.reliabilityChecks: AppFeature.weeklyCheck,
          PaywallBenefitId.customSounds: AppFeature.ownSounds,
          PaywallBenefitId.customAlarmScreens: AppFeature.alarmScreenStyles,
        },
      );
    });

    test('widgets are in the Pro list because the table says Pro', () {
      expect(
        _ids(featureTable, PaywallProduct.pro),
        contains(
          PaywallBenefitId.widgets,
        ),
      );
      expect(
        _ids(featureTable, PaywallProduct.hosted),
        isNot(
          contains(
            PaywallBenefitId.widgets,
          ),
        ),
      );
    });

    test('a widgets row back on Hosted leaves the Pro list', () {
      final moved = _tableWith({AppFeature.widgets: _hosted});
      expect(_ids(moved, PaywallProduct.pro), [
        PaywallBenefitId.wakeUpChallenges,
        PaywallBenefitId.reliabilityChecks,
        PaywallBenefitId.customSounds,
        PaywallBenefitId.customAlarmScreens,
      ]);
    });

    test('a Pro feature moved to Hosted leaves the Pro list', () {
      final moved = _tableWith({AppFeature.weeklyCheck: _hosted});
      expect(_ids(moved, PaywallProduct.pro), [
        PaywallBenefitId.wakeUpChallenges,
        PaywallBenefitId.widgets,
        PaywallBenefitId.customSounds,
        PaywallBenefitId.customAlarmScreens,
      ]);
    });

    test('a Hosted feature moved to Pro leaves the Hosted list', () {
      final moved = _tableWith({AppFeature.appIcons: _pro});
      expect(_ids(moved, PaywallProduct.hosted), [
        PaywallBenefitId.topics,
        PaywallBenefitId.pushes,
        PaywallBenefitId.history,
      ]);
    });
  });
}
