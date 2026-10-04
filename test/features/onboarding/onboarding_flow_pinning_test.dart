import 'package:critalarm/features/onboarding/domain/flow/onboarding_flow.dart';
import 'package:critalarm/features/onboarding/domain/flow/onboarding_flow_source.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/onboarding_flow_fakes.dart';

void main() {
  const custom = OnboardingFlow(
    id: 'custom',
    steps: ['welcome', 'connect', 'permissions'],
  );

  test('the flow is pinned when the user taps Get started', () async {
    final h = EngineHarness();
    expect(h.repository.pinned, isNull);

    await h.engine.finishStep('welcome');

    expect(h.repository.pinned, BundledOnboardingFlows.defaultFlow);
    expect(h.repository.completed, {'welcome'});
  });

  test('pins the highest-priority valid source', () async {
    final h = EngineHarness(
      sources: [
        FakeOnboardingFlowSource(),
        FakeOnboardingFlowSource(custom),
        const BundledOnboardingFlowSource(),
      ],
    );

    final next = await h.engine.finishStep('welcome');

    expect(h.repository.pinned, custom);
    expect(next.stepId, 'connect');
  });

  test('a source that appears after pinning changes nothing', () async {
    final developer = FakeOnboardingFlowSource();
    final h = EngineHarness(
      sources: [developer, const BundledOnboardingFlowSource()],
    );
    await h.engine.finishStep('welcome');

    developer.flow = custom;
    final next = await h.engine.finishStep('how_it_rings');

    expect(h.repository.pinned, BundledOnboardingFlows.defaultFlow);
    expect(h.engine.runningFlow(), BundledOnboardingFlows.defaultFlow);
    expect(next.stepId, 'connect');
    // The next fresh run would get it.
    expect(h.engine.chooseFlow(), custom);
  });

  test('a value that has not arrived yet does not hold anyone up', () async {
    final remote = FakeOnboardingFlowSource();
    final h = EngineHarness(
      sources: [remote, const BundledOnboardingFlowSource()],
    );

    await h.engine.finishStep('welcome');
    remote.flow = custom;

    expect(h.repository.pinned, BundledOnboardingFlows.defaultFlow);
  });

  test('an invalid source falls through to the next one', () async {
    final h = EngineHarness(
      sources: [
        // first_topic before the connect it requires.
        FakeOnboardingFlowSource(
          const OnboardingFlow(
            id: 'broken',
            steps: ['welcome', 'first_topic', 'connect'],
          ),
        ),
        FakeOnboardingFlowSource(custom),
        const BundledOnboardingFlowSource(),
      ],
    );

    await h.engine.finishStep('welcome');

    expect(h.repository.pinned, custom);
  });

  test('every source invalid ends at the bundled default', () async {
    final h = EngineHarness(
      sources: [
        FakeOnboardingFlowSource(
          const OnboardingFlow(id: 'broken', steps: ['connect', 'welcome']),
        ),
        FakeOnboardingFlowSource(
          const OnboardingFlow(id: 'unknown', steps: ['made_up']),
        ),
      ],
    );

    await h.engine.finishStep('welcome');

    expect(h.repository.pinned, BundledOnboardingFlows.defaultFlow);
  });

  test('a pinned list is cleaned by the validator first', () async {
    final h = EngineHarness(
      sources: [
        FakeOnboardingFlowSource(
          const OnboardingFlow(
            id: 'noisy',
            steps: ['welcome', 'made_up', 'connect', 'connect'],
          ),
        ),
      ],
    );

    await h.engine.finishStep('welcome');

    expect(h.repository.pinned?.id, 'noisy');
    expect(h.repository.pinned?.steps, ['welcome', 'connect']);
  });

  test('completing setup drops the pinned flow', () async {
    final h = EngineHarness(
      sources: [
        FakeOnboardingFlowSource(
          const OnboardingFlow(id: 'short', steps: ['welcome']),
        ),
      ],
    );

    final next = await h.engine.finishStep('welcome');

    expect(next.isHome, isTrue);
    expect(h.progress.completed, isTrue);
    expect(h.repository.pinned, isNull);
    expect(h.repository.completed, isEmpty);
  });
}
