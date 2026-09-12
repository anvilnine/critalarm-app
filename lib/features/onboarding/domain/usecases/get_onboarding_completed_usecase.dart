import 'package:critalarm/core/result/result.dart';
import 'package:critalarm/core/usecase/usecase.dart';
import 'package:critalarm/features/onboarding/domain/repositories/onboarding_progress_repository.dart';

class GetOnboardingCompletedUsecase implements UseCase<NoParams, bool> {
  const GetOnboardingCompletedUsecase(this._repository);

  final OnboardingProgressRepository _repository;

  @override
  Future<AppResult<bool>> call(NoParams input) => _repository.isCompleted();
}
