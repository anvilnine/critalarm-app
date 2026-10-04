import 'package:critalarm/core/result/result.dart';
import 'package:critalarm/core/usecase/usecase.dart';
import 'package:critalarm/features/onboarding/domain/repositories/onboarding_flow_repository.dart';
import 'package:critalarm/features/onboarding/domain/repositories/onboarding_progress_repository.dart';

class CompleteOnboardingUsecase implements UseCase<NoParams, Unit> {
  const CompleteOnboardingUsecase(this._repository, [this._flow]);

  final OnboardingProgressRepository _repository;

  /// Null in tests that only care about the completed flag.
  final OnboardingFlowRepository? _flow;

  @override
  Future<AppResult<Unit>> call(NoParams input) async {
    final result = await _repository.markCompleted();
    // The half-finished draft has served its purpose. Leaving it behind would
    // drop a second run back into a step the user already got past. The
    // pinned flow and its completed steps go for the same reason.
    await _repository.clearDraft();
    await _flow?.clear();
    return result;
  }
}
