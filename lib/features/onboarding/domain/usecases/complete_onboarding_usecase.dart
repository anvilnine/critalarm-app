import 'package:critalarm/core/result/result.dart';
import 'package:critalarm/core/usecase/usecase.dart';
import 'package:critalarm/features/onboarding/domain/real_ring/setup_test_ring.dart';
import 'package:critalarm/features/onboarding/domain/repositories/onboarding_flow_repository.dart';
import 'package:critalarm/features/onboarding/domain/repositories/onboarding_progress_repository.dart';
import 'package:critalarm/features/topics/domain/first_topic_handoff.dart';

class CompleteOnboardingUsecase implements UseCase<NoParams, Unit> {
  const CompleteOnboardingUsecase(
    this._repository, [
    this._flow,
    this.onCompleted,
    this._firstTopic,
    this._testRing,
  ]);

  /// Runs once setup is marked complete, however the user left it.
  final void Function()? onCompleted;

  final OnboardingProgressRepository _repository;

  /// Null in tests that only care about the completed flag.
  final OnboardingFlowRepository? _flow;

  /// The first topic held for the last steps, with its token. Null in tests
  /// that do not need it.
  final FirstTopicHandoff? _firstTopic;

  /// The incident of the test alarm setup sent. Null in tests that do not
  /// need it.
  final SetupTestRing? _testRing;

  @override
  Future<AppResult<Unit>> call(NoParams input) async {
    final result = await _repository.markCompleted();
    // The half-finished draft has served its purpose. Leaving it behind would
    // drop a second run back into a step the user already got past. The
    // pinned flow and its completed steps go for the same reason.
    await _repository.clearDraft();
    await _flow?.clear();
    // Setup is over, so the token held in memory for its last steps goes.
    await _firstTopic?.clear();
    // The test incident was only kept for the steps after the ring.
    await _testRing?.clear();
    onCompleted?.call();
    return result;
  }
}
