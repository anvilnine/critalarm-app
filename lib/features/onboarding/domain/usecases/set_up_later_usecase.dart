import 'package:critalarm/core/result/result.dart';
import 'package:critalarm/core/usecase/usecase.dart';
import 'package:critalarm/features/onboarding/domain/usecases/complete_onboarding_usecase.dart';

/// The user leaves setup early, through any "Set this up later" exit.
///
/// Every such exit calls this, so they all end setup the same way: setup is
/// marked complete and the app opens Home, where what was skipped is offered
/// again. A replay from Settings is a look at the screens and completes
/// nothing.
class SetUpLaterUsecase {
  const SetUpLaterUsecase(this._completeOnboarding);

  final CompleteOnboardingUsecase _completeOnboarding;

  Future<AppResult<Unit>> call({bool isReplay = false}) async {
    if (isReplay) return unit.toSuccess();
    return _completeOnboarding(const NoParams());
  }
}
