import 'package:critalarm/core/result/result.dart';
import 'package:critalarm/core/usecase/usecase.dart';
import 'package:critalarm/features/onboarding/domain/repositories/onboarding_progress_repository.dart';

class CompleteOnboardingUsecase implements UseCase<NoParams, Unit> {
  const CompleteOnboardingUsecase(this._repository);

  final OnboardingProgressRepository _repository;

  @override
  Future<AppResult<Unit>> call(NoParams input) => _repository.markCompleted();
}
