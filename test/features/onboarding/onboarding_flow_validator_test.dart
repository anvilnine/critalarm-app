import 'package:critalarm/features/onboarding/domain/flow/onboarding_flow.dart';
import 'package:critalarm/features/onboarding/domain/flow/onboarding_flow_source.dart';
import 'package:critalarm/features/onboarding/domain/flow/onboarding_flow_validator.dart';
import 'package:critalarm/features/onboarding/presentation/flow/onboarding_step_registry.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/onboarding_flow_fakes.dart';

void main() {
  final requires = OnboardingStepRegistry.requiresById;

  OnboardingFlow? validate(List<String> steps) => validateOnboardingFlow(
    OnboardingFlow(id: 'test', steps: steps),
    requires: requires,
  );

  group('validateOnboardingFlow', () {
    test('drops a step id the app does not know', () {
      final flow = validate(['welcome', 'made_up', 'connect']);
      expect(flow?.steps, ['welcome', 'connect']);
      expect(flow?.id, 'test');
    });

    test('rejects a flow where welcome is not first', () {
      expect(validate(['how_it_rings', 'welcome', 'connect']), isNull);
      expect(validate(['connect']), isNull);
    });

    test('an unknown id ahead of welcome is dropped before the check', () {
      expect(validate(['made_up', 'welcome'])?.steps, ['welcome']);
    });

    test('rejects a step listed before one it requires', () {
      expect(validate(['welcome', 'first_topic', 'connect']), isNull);
      expect(
        validate(['welcome', 'connect', 'real_ring', 'first_topic']),
        isNull,
      );
      expect(validate(['welcome', 'legacy_test', 'connect']), isNull);
    });

    test('rejects a step whose required step is missing', () {
      expect(validate(['welcome', 'first_topic']), isNull);
      expect(validate(['welcome', 'connect', 'real_ring']), isNull);
      expect(validate(['welcome', 'hook_up']), isNull);
    });

    test('a duplicate id keeps its first position', () {
      final flow = validate([
        'welcome',
        'connect',
        'permissions',
        'connect',
        'welcome',
      ]);
      expect(flow?.steps, ['welcome', 'connect', 'permissions']);
    });

    test('rejects a list with nothing left in it', () {
      expect(validate([]), isNull);
      expect(validate(['made_up', 'also_made_up']), isNull);
    });

    test('every bundled flow passes unchanged', () {
      for (final flow in BundledOnboardingFlows.all) {
        expect(
          validateOnboardingFlow(flow, requires: requires),
          flow,
          reason: flow.id,
        );
      }
    });

    test('the bundled lists are the ones that ship', () {
      expect(BundledOnboardingFlows.defaultFlow.id, '2026-10-b');
      expect(BundledOnboardingFlows.defaultFlow.steps, [
        'welcome',
        'how_it_rings',
        'connect',
        'permissions',
        'first_topic',
        'real_ring',
        'hook_up',
      ]);
      expect(BundledOnboardingFlows.october2026A.id, '2026-10-a');
      expect(BundledOnboardingFlows.october2026A.steps, [
        'welcome',
        'how_it_rings',
        'connect',
        'permissions',
        'first_topic',
        'real_ring',
        'hook_up',
      ]);
      expect(BundledOnboardingFlows.legacy.id, 'legacy-1');
      expect(BundledOnboardingFlows.legacy.steps, [
        'welcome',
        'how_it_rings',
        'permissions',
        'widgets',
        'connect',
        'legacy_test',
      ]);
    });
  });

  group('chooseOnboardingFlow', () {
    test('an empty result falls back to the bundled default', () {
      final chosen = chooseOnboardingFlow([
        FakeOnboardingFlowSource(
          const OnboardingFlow(id: 'empty', steps: ['made_up']),
        ),
        FakeOnboardingFlowSource(const OnboardingFlow(id: 'none', steps: [])),
      ], requires: requires);
      expect(chosen, BundledOnboardingFlows.defaultFlow);
    });

    test('a source with no flow is passed over', () {
      final chosen = chooseOnboardingFlow([
        const EmptyOnboardingFlowSource(),
        FakeOnboardingFlowSource(BundledOnboardingFlows.legacy),
      ], requires: requires);
      expect(chosen, BundledOnboardingFlows.legacy);
    });
  });

  group('OnboardingFlow.tryParse', () {
    test('reads the JSON a remote value carries', () {
      final flow = OnboardingFlow.tryParse(
        '{"id": "2026-10-a", "steps": ["welcome", "how_it_rings", "connect"]}',
      );
      expect(flow?.id, '2026-10-a');
      expect(flow?.steps, ['welcome', 'how_it_rings', 'connect']);
    });

    test('round trips through toJson', () {
      const flow = BundledOnboardingFlows.legacy;
      expect(OnboardingFlow.tryParse(flow.toJson()), flow);
    });

    test('answers null for anything that is not a flow', () {
      for (final value in <Object?>[
        null,
        '',
        'not json',
        '[]',
        '{"steps": ["welcome"]}',
        '{"id": "", "steps": ["welcome"]}',
        '{"id": "x", "steps": "welcome"}',
        42,
      ]) {
        expect(OnboardingFlow.tryParse(value), isNull, reason: '$value');
      }
    });

    test('leaves out a step that is not a string', () {
      expect(
        OnboardingFlow.tryParse('{"id": "x", "steps": ["welcome", 3]}')?.steps,
        ['welcome'],
      );
    });
  });
}
