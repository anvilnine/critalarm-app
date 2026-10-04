import 'package:critalarm/features/onboarding/domain/flow/onboarding_flow.dart';
import 'package:flutter/foundation.dart';

/// What the phone remembers about a setup run in progress.
@immutable
class OnboardingFlowProgress {
  const OnboardingFlowProgress({this.pinned, this.completed = const {}});

  /// The flow chosen when the user tapped Get started. Null before that.
  final OnboardingFlow? pinned;

  /// The steps the user has finished.
  final Set<String> completed;
}

abstract interface class OnboardingFlowRepository {
  OnboardingFlowProgress read();

  /// Stores the flow this run keeps until setup is complete.
  Future<void> pin(OnboardingFlow flow);

  Future<void> saveCompleted(Set<String> stepIds);

  /// Drops the pinned flow and the completed steps.
  Future<void> clear();

  /// The step name an earlier version of the app saved, or null.
  String? readLegacyStep();

  Future<void> removeLegacyStep();
}
