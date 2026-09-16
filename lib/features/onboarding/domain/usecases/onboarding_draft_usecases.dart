import 'package:critalarm/core/result/result.dart';
import 'package:critalarm/core/usecase/usecase.dart';
import 'package:critalarm/features/onboarding/domain/entities/onboarding_draft.dart';
import 'package:critalarm/features/onboarding/domain/repositories/onboarding_progress_repository.dart';

/// What the user had reached and typed last time, so a relaunch picks up
/// where they left off.
class ReadOnboardingDraftUsecase implements UseCase<NoParams, OnboardingDraft> {
  const ReadOnboardingDraftUsecase(this._repository);

  final OnboardingProgressRepository _repository;

  @override
  Future<AppResult<OnboardingDraft>> call(NoParams input) =>
      _repository.readDraft();
}

class SaveOnboardingDraftUsecase implements UseCase<OnboardingDraft, Unit> {
  const SaveOnboardingDraftUsecase(this._repository);

  final OnboardingProgressRepository _repository;

  @override
  Future<AppResult<Unit>> call(OnboardingDraft input) =>
      _repository.saveDraft(input);
}

class ClearOnboardingDraftUsecase implements UseCase<NoParams, Unit> {
  const ClearOnboardingDraftUsecase(this._repository);

  final OnboardingProgressRepository _repository;

  @override
  Future<AppResult<Unit>> call(NoParams input) => _repository.clearDraft();
}
