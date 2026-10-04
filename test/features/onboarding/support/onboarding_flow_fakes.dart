import 'package:critalarm/core/result/result.dart';
import 'package:critalarm/features/onboarding/domain/entities/onboarding_draft.dart';
import 'package:critalarm/features/onboarding/domain/flow/onboarding_flow.dart';
import 'package:critalarm/features/onboarding/domain/flow/onboarding_flow_engine.dart';
import 'package:critalarm/features/onboarding/domain/flow/onboarding_flow_source.dart';
import 'package:critalarm/features/onboarding/domain/flow/onboarding_step_facts.dart';
import 'package:critalarm/features/onboarding/domain/repositories/onboarding_flow_repository.dart';
import 'package:critalarm/features/onboarding/domain/repositories/onboarding_progress_repository.dart';
import 'package:critalarm/features/onboarding/domain/usecases/complete_onboarding_usecase.dart';
import 'package:critalarm/features/onboarding/domain/usecases/get_onboarding_completed_usecase.dart';
import 'package:critalarm/features/onboarding/presentation/flow/onboarding_step_registry.dart';
import 'package:flutter/foundation.dart';

/// Holds what the prefs would, and counts the writes.
class FakeOnboardingFlowRepository implements OnboardingFlowRepository {
  FakeOnboardingFlowRepository({
    this.pinned,
    Set<String> completed = const {},
    this.legacyStep,
  }) : completed = {...completed};

  OnboardingFlow? pinned;
  Set<String> completed;
  String? legacyStep;
  int writes = 0;

  @override
  OnboardingFlowProgress read() =>
      OnboardingFlowProgress(pinned: pinned, completed: {...completed});

  @override
  Future<void> pin(OnboardingFlow flow) async {
    writes++;
    pinned = flow;
  }

  @override
  Future<void> saveCompleted(Set<String> stepIds) async {
    writes++;
    completed = {...stepIds};
  }

  @override
  Future<void> clear() async {
    writes++;
    pinned = null;
    completed = {};
    legacyStep = null;
  }

  @override
  String? readLegacyStep() => legacyStep;

  @override
  Future<void> removeLegacyStep() async {
    writes++;
    legacyStep = null;
  }
}

class FakeOnboardingProgressRepository implements OnboardingProgressRepository {
  bool completed = false;

  @override
  Future<AppResult<bool>> isCompleted() async => completed.toSuccess();

  @override
  Future<AppResult<Unit>> markCompleted() async {
    completed = true;
    return unit.toSuccess();
  }

  @override
  Future<AppResult<OnboardingDraft>> readDraft() async =>
      const OnboardingDraft().toSuccess();

  @override
  Future<AppResult<Unit>> saveDraft(OnboardingDraft draft) async =>
      unit.toSuccess();

  @override
  Future<AppResult<Unit>> clearDraft() async => unit.toSuccess();
}

class FakeOnboardingStepFacts implements OnboardingStepFacts {
  FakeOnboardingStepFacts({
    this.connected = false,
    this.permissions = false,
    this.ownsTopic = false,
    this.firstMessage = false,
  });

  bool connected;
  bool permissions;
  bool ownsTopic;
  bool firstMessage;

  @override
  Future<bool> hasReceivedFirstMessage() async => firstMessage;

  @override
  Future<bool> hasConnection() async => connected;

  @override
  Future<bool> hasEveryPermission() async => permissions;

  @override
  Future<bool> hasOwnedTopic() async => ownsTopic;
}

/// A source whose flow can be swapped while a test runs.
class FakeOnboardingFlowSource implements OnboardingFlowSource {
  FakeOnboardingFlowSource([this.flow]);

  OnboardingFlow? flow;

  @override
  OnboardingFlow? current() => flow;
}

const iPhone = OnboardingPlatform(platform: TargetPlatform.iOS, isWeb: false);
const androidPhone = OnboardingPlatform(
  platform: TargetPlatform.android,
  isWeb: false,
);
const web = OnboardingPlatform(platform: TargetPlatform.android, isWeb: true);

/// The real registry and the real engine over fakes for everything that
/// touches the phone.
class EngineHarness {
  EngineHarness({
    OnboardingPlatform on = iPhone,
    FakeOnboardingStepFacts? facts,
    FakeOnboardingFlowRepository? repository,
    List<OnboardingFlowSource>? sources,
    OnboardingFlowRepository? store,
    void Function(OnboardingStepEvent event)? onStepEvent,
  }) : facts = facts ?? FakeOnboardingStepFacts(),
       repository = repository ?? FakeOnboardingFlowRepository() {
    engine = OnboardingFlowEngine(
      sources: sources ?? const [BundledOnboardingFlowSource()],
      catalog: OnboardingStepRegistry(on: on, facts: this.facts),
      repository: store ?? this.repository,
      completeOnboarding: CompleteOnboardingUsecase(
        progress,
        store ?? this.repository,
      ),
      getOnboardingCompleted: GetOnboardingCompletedUsecase(progress),
      onStepEvent: (event) {
        events.add(event);
        onStepEvent?.call(event);
      },
    );
  }

  final FakeOnboardingStepFacts facts;

  /// Unused when a `store` was passed in.
  final FakeOnboardingFlowRepository repository;
  final progress = FakeOnboardingProgressRepository();
  final events = <OnboardingStepEvent>[];
  late final OnboardingFlowEngine engine;
}
