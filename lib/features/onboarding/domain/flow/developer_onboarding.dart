import 'package:critalarm/core/paywall/paywall_build_mode.dart';
import 'package:critalarm/features/onboarding/domain/flow/developer_step_list_parser.dart';
import 'package:critalarm/features/onboarding/domain/flow/onboarding_flow.dart';
import 'package:critalarm/features/onboarding/domain/flow/onboarding_flow_source.dart';
import 'package:critalarm/features/onboarding/domain/flow/onboarding_step_catalog.dart';
import 'package:flutter/foundation.dart';

/// Whether this build carries the setup controls in developer settings.
///
/// Decided when the app is compiled, from the same two flags that show the
/// developer row in Settings. A store build has neither, so everything that
/// hangs off this constant is dropped from it.
const bool buildHasOnboardingDeveloperTools =
    buildSkipsPaywall || buildHasPaywallLab;

/// The setup steps that have an `isSatisfied` check, so the ones a developer
/// can force to count as not done. `hook_up` joins them once it has a check
/// and a screen.
const forceableOnboardingSteps = <String>[
  OnboardingStepId.connect,
  OnboardingStepId.permissions,
  OnboardingStepId.firstTopic,
];

/// The flow a developer picked.
@immutable
class DeveloperFlowChoice {
  /// One of [BundledOnboardingFlows.all], by id.
  const DeveloperFlowChoice.bundled(String this.bundledId) : customText = null;

  /// A step list as typed, comma separated.
  const DeveloperFlowChoice.custom(String this.customText) : bundledId = null;

  final String? bundledId;
  final String? customText;

  bool get isCustom => customText != null;

  static const _customPrefix = 'custom:';

  /// What is saved: the flow id for a bundled flow, or `custom:` and the
  /// typed text.
  String encode() => isCustom ? '$_customPrefix$customText' : bundledId!;

  /// Reads what [encode] wrote. Null for nothing, or for an empty value.
  static DeveloperFlowChoice? decode(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    if (raw.startsWith(_customPrefix)) {
      return DeveloperFlowChoice.custom(raw.substring(_customPrefix.length));
    }
    return DeveloperFlowChoice.bundled(raw);
  }

  /// The flow this choice stands for, or null when it stands for none: a
  /// bundled id this version does not have, or a typed list the validator
  /// rejects.
  OnboardingFlow? toFlow({required Map<String, Set<String>> requires}) {
    final custom = customText;
    if (custom != null) {
      return parseDeveloperStepList(custom, requires: requires).flow;
    }
    for (final flow in BundledOnboardingFlows.all) {
      if (flow.id == bundledId) return flow;
    }
    return null;
  }

  @override
  bool operator ==(Object other) =>
      other is DeveloperFlowChoice &&
      bundledId == other.bundledId &&
      customText == other.customText;

  @override
  int get hashCode => Object.hash(bundledId, customText);
}

/// What a developer has set for setup: the flow to run, and the steps to
/// treat as not done. A store build is compiled with
/// [NoDeveloperOnboardingOverrides], which holds nothing.
abstract interface class DeveloperOnboardingOverrides implements Listenable {
  /// False in a build with no developer tools. The setup section of
  /// developer settings stays hidden then.
  bool get isActive;

  /// The flow picked, or null to let the next source decide.
  DeveloperFlowChoice? get flowChoice;

  /// The step ids forced to count as not satisfied.
  Set<String> get forcedUnsatisfied;

  /// Saves [choice], or clears the pick when it is null.
  Future<void> chooseFlow(DeveloperFlowChoice? choice);

  /// Turns the forcing of [stepId] on or off.
  Future<void> forceUnsatisfied(String stepId, {required bool forced});
}

/// What a store build is compiled with. It keeps nothing and answers with
/// nothing, so the stored values of a developer build mean nothing to it.
class NoDeveloperOnboardingOverrides implements DeveloperOnboardingOverrides {
  const NoDeveloperOnboardingOverrides();

  @override
  bool get isActive => false;

  @override
  DeveloperFlowChoice? get flowChoice => null;

  @override
  Set<String> get forcedUnsatisfied => const {};

  @override
  Future<void> chooseFlow(DeveloperFlowChoice? choice) async {}

  @override
  Future<void> forceUnsatisfied(String stepId, {required bool forced}) async {}

  @override
  void addListener(VoidCallback listener) {}

  @override
  void removeListener(VoidCallback listener) {}
}

/// The highest priority source: the flow a developer picked.
///
/// It still answers with what it has and nothing more. The engine puts every
/// source through the validator.
class DeveloperOnboardingFlowSource implements OnboardingFlowSource {
  const DeveloperOnboardingFlowSource({
    required this.overrides,
    required this.requires,
  });

  final DeveloperOnboardingOverrides overrides;

  /// The step rules, for reading a typed list.
  final Map<String, Set<String>> requires;

  @override
  OnboardingFlow? current() => overrides.flowChoice?.toFlow(requires: requires);
}

/// Wraps the step catalog so a developer can make a step count as not done.
/// A step that is forced reads as unsatisfied, whatever the phone says, so
/// the resume rule stops on it.
class ForcedUnsatisfiedStepCatalog implements OnboardingStepCatalog {
  const ForcedUnsatisfiedStepCatalog(this.inner, this.overrides);

  final OnboardingStepCatalog inner;
  final DeveloperOnboardingOverrides overrides;

  @override
  Map<String, Set<String>> get requires => inner.requires;

  @override
  bool isAvailable(String stepId) => inner.isAvailable(stepId);

  @override
  Future<bool> isSatisfied(String stepId) async {
    if (overrides.forcedUnsatisfied.contains(stepId)) return false;
    return inner.isSatisfied(stepId);
  }

  @override
  String? routeOf(String stepId) => inner.routeOf(stepId);
}
