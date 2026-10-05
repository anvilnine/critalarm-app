import 'package:critalarm/core/result/result.dart';
import 'package:critalarm/core/usecase/usecase.dart';
import 'package:critalarm/features/onboarding/domain/real_ring/setup_test_ring.dart';
import 'package:critalarm/features/onboarding/domain/usecases/complete_onboarding_usecase.dart';

/// The user leaves setup early, through any "Set this up later" exit.
///
/// Every such exit calls this, so they all end setup the same way: setup is
/// marked complete and the app opens Home, where what was skipped is offered
/// again. A replay from Settings is a look at the screens and completes
/// nothing.
class SetUpLaterUsecase {
  const SetUpLaterUsecase(this._completeOnboarding, [this._ring]);

  final CompleteOnboardingUsecase _completeOnboarding;

  /// Null in tests that do not look at it.
  final SetupTestRing? _ring;

  Future<AppResult<Unit>> call({bool isReplay = false}) async {
    if (isReplay) return unit.toSuccess();
    // Leaving early is not the hook-up step proving anything, so an alarm
    // it may have heard is not owed the setup acknowledged screen.
    try {
      await _ring?.forgetFirstTool();
    } on Object catch (_) {
      // The phone would not save it. Setup still ends.
    }
    return _completeOnboarding(const NoParams());
  }
}
