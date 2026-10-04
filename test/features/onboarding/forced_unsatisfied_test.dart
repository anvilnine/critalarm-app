import 'package:critalarm/features/onboarding/data/repositories/shared_prefs_developer_onboarding_overrides.dart';
import 'package:critalarm/features/onboarding/domain/flow/developer_onboarding.dart';
import 'package:critalarm/features/onboarding/domain/flow/onboarding_flow.dart';
import 'package:critalarm/features/onboarding/domain/flow/onboarding_flow_engine.dart';
import 'package:critalarm/features/onboarding/domain/flow/onboarding_flow_resume.dart';
import 'package:critalarm/features/onboarding/domain/flow/onboarding_flow_source.dart';
import 'package:critalarm/features/onboarding/domain/flow/onboarding_step_catalog.dart';
import 'package:critalarm/features/onboarding/domain/usecases/complete_onboarding_usecase.dart';
import 'package:critalarm/features/onboarding/domain/usecases/get_onboarding_completed_usecase.dart';
import 'package:critalarm/features/onboarding/presentation/flow/onboarding_step_registry.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/onboarding_flow_fakes.dart';

void main() {
  const key = SharedPrefsDeveloperOnboardingOverrides.forcedKey;

  late FakeOnboardingStepFacts facts;

  setUp(() {
    // A user who has already done everything that can be looked up.
    facts = FakeOnboardingStepFacts(
      connected: true,
      permissions: true,
      ownsTopic: true,
    );
  });

  Future<DeveloperOnboardingOverrides> overridesWith(
    Map<String, Object> values, {
    required bool enabled,
  }) async {
    SharedPreferences.setMockInitialValues(values);
    return developerOnboardingOverridesFor(
      await SharedPreferences.getInstance(),
      enabled: enabled,
    );
  }

  OnboardingStepCatalog catalogFor(DeveloperOnboardingOverrides overrides) =>
      ForcedUnsatisfiedStepCatalog(
        OnboardingStepRegistry(on: iPhone, facts: facts),
        overrides,
      );

  Future<String?> resumePoint(
    OnboardingFlow flow,
    OnboardingStepCatalog catalog, {
    Set<String> completed = const {'welcome', 'how_it_rings'},
  }) => firstOpenOnboardingStep(
    flow.steps,
    completed: completed,
    isAvailable: catalog.isAvailable,
    isSatisfied: catalog.isSatisfied,
  );

  test(
    'a forced step is the resume point though its check says satisfied',
    () async {
      final overrides = await overridesWith({
        key: ['permissions'],
      }, enabled: true);
      final catalog = catalogFor(overrides);

      expect(await catalog.isSatisfied('permissions'), isFalse);
      expect(await catalog.isSatisfied('connect'), isTrue);
      expect(
        await resumePoint(BundledOnboardingFlows.defaultFlow, catalog),
        'permissions',
      );
    },
  );

  test('without a forced step the same user has nothing left to do', () async {
    final overrides = await overridesWith({}, enabled: true);

    expect(
      await resumePoint(
        BundledOnboardingFlows.defaultFlow,
        catalogFor(overrides),
        completed: {'welcome', 'how_it_rings', 'real_ring'},
      ),
      isNull,
    );
  });

  test('a store build ignores the stored set', () async {
    final overrides = await overridesWith({
      key: ['permissions', 'connect'],
    }, enabled: false);
    final catalog = catalogFor(overrides);

    expect(await catalog.isSatisfied('permissions'), isTrue);
    expect(await catalog.isSatisfied('connect'), isTrue);
    expect(
      await resumePoint(
        BundledOnboardingFlows.defaultFlow,
        catalog,
        completed: {'welcome', 'how_it_rings', 'real_ring'},
      ),
      isNull,
    );
  });

  test('the engine stops on a forced step', () async {
    final overrides = await overridesWith({
      key: ['first_topic'],
    }, enabled: true);
    final repository = FakeOnboardingFlowRepository(
      pinned: BundledOnboardingFlows.defaultFlow,
      completed: {'welcome', 'how_it_rings'},
    );
    final progress = FakeOnboardingProgressRepository();
    final engine = OnboardingFlowEngine(
      sources: const [BundledOnboardingFlowSource()],
      catalog: catalogFor(overrides),
      repository: repository,
      completeOnboarding: CompleteOnboardingUsecase(progress, repository),
      getOnboardingCompleted: GetOnboardingCompletedUsecase(progress),
    );

    final destination = await engine.resume();

    expect(destination.stepId, 'first_topic');
  });

  test('turning a step on and off keeps the other forced steps', () async {
    final overrides = await overridesWith({}, enabled: true);

    await overrides.forceUnsatisfied('connect', forced: true);
    await overrides.forceUnsatisfied('permissions', forced: true);
    await overrides.forceUnsatisfied('connect', forced: false);

    expect(overrides.forcedUnsatisfied, {'permissions'});

    await overrides.forceUnsatisfied('permissions', forced: false);

    expect(overrides.forcedUnsatisfied, isEmpty);
  });

  test('the forceable list is the steps that have a check', () async {
    final everythingTrue = FakeOnboardingStepFacts(
      connected: true,
      permissions: true,
      ownsTopic: true,
    );
    final withCheck = [
      for (final entry in OnboardingStepRegistry.entries)
        if (await entry.isSatisfied(everythingTrue)) entry.id,
    ];

    expect(forceableOnboardingSteps, unorderedEquals(withCheck));
  });
}
