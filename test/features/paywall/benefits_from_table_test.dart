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
    test('is what the feature table says, with the weekly check last', () {
      expect(
        HostedBenefit.all.map((b) => b.id),
        hostedBenefitsIn(featureTable).map((b) => b.id),
      );
      // Pinned: the items and the order every Hosted surface shows. The
      // weekly delivery check joined at the end when it moved from Pro.
      expect(HostedBenefit.all.map((b) => b.id), [
        HostedBenefitId.topics,
        HostedBenefitId.pushes,
        HostedBenefitId.history,
        HostedBenefitId.appIcons,
        HostedBenefitId.weeklyCheck,
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
          HostedBenefitId.weeklyCheck: AppFeature.weeklyCheck,
        },
      );
    });

    test('the weekly check is a Hosted benefit because the table says '
        'Hosted, and is not one when the table says Pro', () {
      expect(featureTable[AppFeature.weeklyCheck]!.unlockedBy, {
        Holding.hosted,
      });
      expect(
        HostedBenefit.all.map((b) => b.feature),
        contains(AppFeature.weeklyCheck),
      );
      final asPro = hostedBenefitsIn(
        _tableWith({AppFeature.weeklyCheck: _pro}),
      );
      expect(
        asPro.map((b) => b.id),
        isNot(contains(HostedBenefitId.weeklyCheck)),
      );
    });

    test('the app icons stay a Hosted benefit though Pro unlocks them too', () {
      expect(featureTable[AppFeature.appIcons]!.unlockedBy, {
        Holding.hosted,
        Holding.pro,
      });
      expect(
        HostedBenefit.all.map((b) => b.id),
        contains(HostedBenefitId.appIcons),
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
        HostedBenefitId.weeklyCheck,
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
    test('follow the table: the weekly check is off the Pro list', () {
      // The Hosted layout list is the four it was. The weekly check is in
      // `HostedBenefit.all` and has no line and preview for a layout yet,
      // so a layout does not list it.
      expect(_ids(featureTable, PaywallProduct.hosted), [
        PaywallBenefitId.topics,
        PaywallBenefitId.pushes,
        PaywallBenefitId.history,
        PaywallBenefitId.appIcons,
      ]);
      expect(_ids(featureTable, PaywallProduct.pro), [
        PaywallBenefitId.wakeUpChallenges,
        PaywallBenefitId.widgets,
        PaywallBenefitId.customSounds,
        PaywallBenefitId.customAlarmScreens,
      ]);
      // What this build really has. The alarm screen looks joined the
      // day the own photo look was built, and the own sounds once Pro
      // gated them.
      expect(paywallBenefitsFor(PaywallProduct.pro).map((b) => b.id), [
        PaywallBenefitId.widgets,
        PaywallBenefitId.customSounds,
        PaywallBenefitId.customAlarmScreens,
      ]);
    });

    test('no layout lists the weekly check under Pro', () {
      for (final benefit in allPaywallBenefits) {
        if (benefit.product != PaywallProduct.pro) continue;
        expect(benefit.feature, isNot(AppFeature.weeklyCheck));
        expect(benefit.id, isNot(PaywallBenefitId.reliabilityChecks));
      }
    });

    test('the weekly check comes back to the Pro list if the table says '
        'Pro again', () {
      final moved = _tableWith({AppFeature.weeklyCheck: _pro});
      expect(
        _ids(moved, PaywallProduct.pro),
        contains(PaywallBenefitId.reliabilityChecks),
      );
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
        PaywallBenefitId.customSounds,
        PaywallBenefitId.customAlarmScreens,
      ]);
    });

    test('a Pro feature moved to Hosted leaves the Pro list', () {
      final moved = _tableWith({AppFeature.alarmScreenStyles: _hosted});
      expect(_ids(moved, PaywallProduct.pro), [
        PaywallBenefitId.wakeUpChallenges,
        PaywallBenefitId.widgets,
        PaywallBenefitId.customSounds,
      ]);
    });

    test('the app icons stay on the Hosted list, and are not on the Pro '
        'list yet though Pro unlocks them', () {
      expect(
        _ids(featureTable, PaywallProduct.hosted),
        contains(PaywallBenefitId.appIcons),
      );
      expect(
        _ids(featureTable, PaywallProduct.pro),
        isNot(contains(PaywallBenefitId.appIcons)),
      );
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
