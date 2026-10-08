import 'package:critalarm/features/settings/presentation/developer_options_rules.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('developerSectionsFor', () {
    test('a build with everything lists all four, tools last', () {
      expect(
        developerSectionsFor(hasPlanSwitches: true, hasSetupTools: true),
        [
          DeveloperSection.plans,
          DeveloperSection.paywalls,
          DeveloperSection.setup,
          DeveloperSection.tools,
        ],
      );
    });

    test('a build that keeps the store has no plan switches', () {
      expect(
        developerSectionsFor(hasPlanSwitches: false, hasSetupTools: true),
        [
          DeveloperSection.paywalls,
          DeveloperSection.setup,
          DeveloperSection.tools,
        ],
      );
    });

    test('a phone with no setup still has paywalls and tools', () {
      expect(
        developerSectionsFor(hasPlanSwitches: false, hasSetupTools: false),
        [DeveloperSection.paywalls, DeveloperSection.tools],
      );
    });

    test('tools close the list in every build', () {
      for (final plans in [true, false]) {
        for (final setup in [true, false]) {
          expect(
            developerSectionsFor(
              hasPlanSwitches: plans,
              hasSetupTools: setup,
            ).last,
            DeveloperSection.tools,
          );
        }
      }
    });
  });

  group('paywallPairText', () {
    test('both left to the remote value read as it once', () {
      expect(
        paywallPairText(intro: null, layout: null, remote: 'remote'),
        'remote',
      );
    });

    test('an intro and a layout read intro first', () {
      expect(
        paywallPairText(intro: 'Snooze', layout: 'Hero', remote: 'remote'),
        'Snooze, Hero',
      );
    });

    test('one side left to the remote value says so in its place', () {
      expect(
        paywallPairText(intro: null, layout: 'Hero', remote: 'remote'),
        'remote, Hero',
      );
      expect(
        paywallPairText(intro: 'Snooze', layout: null, remote: 'remote'),
        'Snooze, remote',
      );
    });
  });

  group('developerFlowValueText', () {
    String text({String? bundledId, bool isCustom = false}) =>
        developerFlowValueText(
          bundledId: bundledId,
          isCustom: isCustom,
          none: 'No override',
          custom: 'Custom',
        );

    test('no choice reads as no override', () {
      expect(text(), 'No override');
    });

    test('a bundled flow reads as its id', () {
      expect(text(bundledId: '2026-10-b'), '2026-10-b');
    });

    test('a typed list reads as Custom', () {
      expect(text(isCustom: true), 'Custom');
    });
  });
}
