import 'package:critalarm/core/result/result.dart';
import 'package:critalarm/core/usecase/usecase.dart';
import 'package:critalarm/features/onboarding/domain/repositories/onboarding_progress_repository.dart';

class CompleteOnboardingUsecase implements UseCase<NoParams, Unit> {
  const CompleteOnboardingUsecase(this._repository);

  final OnboardingProgressRepository _repository;

  @override
  Future<AppResult<Unit>> call(NoParams input) async {
    final result = await _repository.markCompleted();
    // The half-finished draft has served its purpose. Leaving it behind would
    // drop a second run back into a step the user already got past.
    await _repository.clearDraft();
    return result;
  }
}
