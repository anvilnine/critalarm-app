import 'package:critalarm/features/paywall/domain/entities/paywall_benefit.dart';
import 'package:critalarm/features/paywall/presentation/layouts/sheet/sheet_page.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('the screen the Sheet is drawn over', () {
    test('wake-up challenges have the Wake-up challenge page of their own', () {
      expect(
        sheetPageKindFor(PaywallBenefitId.wakeUpChallenges),
        SheetPageKind.challenge,
      );
    });

    test('the other leads keep the screens they had', () {
      const expected = <PaywallBenefitId?, SheetPageKind>{
        PaywallBenefitId.topics: SheetPageKind.newTopic,
        PaywallBenefitId.history: SheetPageKind.history,
        PaywallBenefitId.widgets: SheetPageKind.widgets,
        PaywallBenefitId.reliabilityChecks: SheetPageKind.reliability,
        PaywallBenefitId.pushes: SheetPageKind.settings,
        PaywallBenefitId.appIcons: SheetPageKind.settings,
        PaywallBenefitId.customSounds: SheetPageKind.settings,
        PaywallBenefitId.customAlarmScreens: SheetPageKind.settings,
        null: SheetPageKind.settings,
      };
      for (final entry in expected.entries) {
        expect(
          sheetPageKindFor(entry.key),
          entry.value,
          reason: '${entry.key}',
        );
      }
    });
  });
}
