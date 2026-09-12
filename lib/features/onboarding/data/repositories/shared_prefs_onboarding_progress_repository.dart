import 'package:critalarm/core/failures/failure.dart';
import 'package:critalarm/core/result/result.dart';
import 'package:critalarm/features/onboarding/domain/repositories/onboarding_progress_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SharedPrefsOnboardingProgressRepository
    implements OnboardingProgressRepository {
  const SharedPrefsOnboardingProgressRepository(this._prefs);

  final SharedPreferences _prefs;

  static const _keyOnboardingCompleted = 'onboarding_completed';

  @override
  Future<AppResult<bool>> isCompleted() async {
    try {
      return (_prefs.getBool(_keyOnboardingCompleted) ?? false).toSuccess();
    } on Exception catch (e) {
      return Failure.unexpected(message: e.toString()).toFailure();
    }
  }

  @override
  Future<AppResult<Unit>> markCompleted() async {
    try {
      await _prefs.setBool(_keyOnboardingCompleted, true);
      return unit.toSuccess();
    } on Exception catch (e) {
      return Failure.unexpected(message: e.toString()).toFailure();
    }
  }
}
