import 'package:critalarm/core/usecase/usecase.dart';
import 'package:critalarm/features/onboarding/domain/flow/onboarding_flow.dart';
import 'package:critalarm/features/onboarding/domain/flow/onboarding_flow_resume.dart';
import 'package:critalarm/features/onboarding/domain/flow/onboarding_flow_source.dart';
import 'package:critalarm/features/onboarding/domain/flow/onboarding_flow_validator.dart';
import 'package:critalarm/features/onboarding/domain/flow/onboarding_step_catalog.dart';
import 'package:critalarm/features/onboarding/domain/repositories/onboarding_flow_repository.dart';
import 'package:critalarm/features/onboarding/domain/usecases/complete_onboarding_usecase.dart';
import 'package:critalarm/features/onboarding/domain/usecases/get_onboarding_completed_usecase.dart';
import 'package:flutter/foundation.dart';

/// Where setup goes next.
@immutable
class OnboardingDestination {
  /// The screen of the next step.
  const OnboardingDestination.step(String this.stepId, String this.route)
    : isBack = false;

  /// Home, because setup is complete.
  const OnboardingDestination.home()
    : stepId = null,
      route = null,
      isBack = false;

  /// Back to wherever the user came from. A setup screen opened after setup
  /// was over, from Settings or a card on Home, is not part of a run.
  const OnboardingDestination.back()
    : stepId = null,
      route = null,
      isBack = true;

  final String? stepId;
  final String? route;
  final bool isBack;

  bool get isHome => route == null && !isBack;
}

/// A step was opened or finished, with the flow it happened in.
enum OnboardingStepEventKind { entered, finished }

@immutable
class OnboardingStepEvent {
  const OnboardingStepEvent({
    required this.kind,
    required this.stepId,
    required this.flowId,
    required this.isReplay,
  });

  final OnboardingStepEventKind kind;
  final String stepId;
  final String flowId;
  final bool isReplay;
}

/// Runs a setup flow: picks it, pins it, and says which step comes next.
///
/// The order of the steps is data. Where the user stands is never saved as a
/// position. It is worked out each time from the pinned list, the completed
/// steps, and what is already true for this user, so a reordered flow needs
/// no migration.
class OnboardingFlowEngine {
  OnboardingFlowEngine({
    required this.sources,
    required this.catalog,
    required this.repository,
    required this.completeOnboarding,
    required this.getOnboardingCompleted,
    this.origins = defaultOnboardingFlowOrigins,
    this.onStepEvent,
  });

  /// In priority order. The first one with a valid flow wins.
  final List<OnboardingFlowSource> sources;

  /// Names each of [sources] by position, for the screens that show which
  /// one won.
  final List<OnboardingFlowOrigin> origins;
  final OnboardingStepCatalog catalog;
  final OnboardingFlowRepository repository;
  final CompleteOnboardingUsecase completeOnboarding;
  final GetOnboardingCompletedUsecase getOnboardingCompleted;

  /// The one place a step is reported as entered or finished.
  final void Function(OnboardingStepEvent event)? onStepEvent;

  /// The flow a run starting now would get.
  OnboardingFlow chooseFlow() => chooseFlowWithOrigin().flow;

  /// The flow a run starting now would get, and the source that gave it:
  /// the developer override, Remote Config, or the bundled default.
  ChosenOnboardingFlow chooseFlowWithOrigin() => chooseOnboardingFlowWithOrigin(
    sources,
    requires: catalog.requires,
    origins: origins,
  );

  /// The flow the user is in: the pinned one, or the one a replay runs.
  OnboardingFlow runningFlow() => repository.read().pinned ?? chooseFlow();

  /// Whether [stepId] is already true for this user, whatever the flow says.
  Future<bool> isStepSatisfied(String stepId) => catalog.isSatisfied(stepId);

  /// Where the app opens while setup is not complete.
  Future<OnboardingDestination> resume() async {
    await migrateLegacyStep();
    final progress = repository.read();
    final pinned = await _checkedPin(progress.pinned);
    if (pinned == null) {
      final flow = chooseFlow();
      return _enter(OnboardingStepId.welcome, flow, isReplay: false);
    }
    return _open(pinned, progress.completed);
  }

  /// The saved flow, put through the validator again. An update can leave a
  /// phone holding a list this version would not accept: step ids it no
  /// longer knows, or nothing at all. Unknown ids are dropped. A list the
  /// validator rejects is replaced by the bundled default, so an empty list
  /// never reads as "every step done". The completed steps are kept.
  Future<OnboardingFlow?> _checkedPin(OnboardingFlow? saved) async {
    if (saved == null) return null;
    final checked =
        validateOnboardingFlow(saved, requires: catalog.requires) ??
        BundledOnboardingFlows.defaultFlow;
    if (checked != saved) await repository.pin(checked);
    return checked;
  }

  /// The user is done with [stepId]. Marks it completed and returns the next
  /// step by the resume rule, or completes setup when none is left.
  ///
  /// The first call of a run pins the flow, which is the tap on Get started.
  ///
  /// On a replay nothing is saved and nothing is pinned. The next step is the
  /// one after [stepId] in the flow the sources give right now.
  ///
  /// Once setup is complete there is no run to move along. A setup screen
  /// opened then, to connect a server or test the alarm, saves nothing, pins
  /// nothing, and sends the user back to where they came from.
  Future<OnboardingDestination> finishStep(
    String stepId, {
    bool isReplay = false,
  }) async {
    if (isReplay) {
      final flow = chooseFlow();
      _report(OnboardingStepEventKind.finished, stepId, flow, isReplay: true);
      final next = nextReplayOnboardingStep(
        flow.steps,
        finished: stepId,
        isAvailable: catalog.isAvailable,
      );
      if (next == null) return const OnboardingDestination.home();
      return _enter(next, flow, isReplay: true);
    }

    final isComplete =
        (await getOnboardingCompleted(const NoParams())).getOrNull() ?? false;
    if (isComplete) return const OnboardingDestination.back();

    final progress = repository.read();
    var pinned = await _checkedPin(progress.pinned);
    if (pinned == null) {
      pinned = chooseFlow();
      await repository.pin(pinned);
    }
    final completed = {...progress.completed, stepId};
    await repository.saveCompleted(completed);
    _report(OnboardingStepEventKind.finished, stepId, pinned, isReplay: false);
    return _open(pinned, completed);
  }

  /// Places a user who was halfway through setup in a version that saved the
  /// step by name. Runs once. Running it again changes nothing.
  Future<void> migrateLegacyStep() async {
    final legacy = repository.readLegacyStep();
    if (legacy == null) return;
    final progress = repository.read();
    if (progress.pinned == null) {
      // Anyone past the welcome has seen both intro screens. The other steps
      // are placed by what is already true: a connected user resumes at the
      // permissions or later.
      if (legacy != OnboardingStepId.welcome) {
        await repository.saveCompleted({
          ...progress.completed,
          OnboardingStepId.welcome,
          OnboardingStepId.howItRings,
        });
      }
      await repository.pin(BundledOnboardingFlows.defaultFlow);
    }
    await repository.removeLegacyStep();
  }

  Future<OnboardingDestination> _open(
    OnboardingFlow flow,
    Set<String> completed,
  ) async {
    final next = await firstOpenOnboardingStep(
      flow.steps,
      completed: completed,
      isAvailable: catalog.isAvailable,
      isSatisfied: catalog.isSatisfied,
    );
    if (next == null) {
      await completeOnboarding(const NoParams());
      return const OnboardingDestination.home();
    }
    return _enter(next, flow, isReplay: false);
  }

  OnboardingDestination _enter(
    String stepId,
    OnboardingFlow flow, {
    required bool isReplay,
  }) {
    _report(OnboardingStepEventKind.entered, stepId, flow, isReplay: isReplay);
    return OnboardingDestination.step(stepId, catalog.routeOf(stepId)!);
  }

  void _report(
    OnboardingStepEventKind kind,
    String stepId,
    OnboardingFlow flow, {
    required bool isReplay,
  }) {
    onStepEvent?.call(
      OnboardingStepEvent(
        kind: kind,
        stepId: stepId,
        flowId: flow.id,
        isReplay: isReplay,
      ),
    );
  }
}
