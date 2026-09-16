import 'package:critalarm/core/result/result.dart';
import 'package:critalarm/features/onboarding/domain/entities/onboarding_draft.dart';

abstract interface class OnboardingProgressRepository {
  Future<AppResult<bool>> isCompleted();

  Future<AppResult<Unit>> markCompleted();

  /// Where the user had got to, and what they had typed.
  Future<AppResult<OnboardingDraft>> readDraft();

  Future<AppResult<Unit>> saveDraft(OnboardingDraft draft);

  /// Called once onboarding finishes, so a second run starts clean.
  Future<AppResult<Unit>> clearDraft();
}
