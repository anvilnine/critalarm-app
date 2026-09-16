import 'package:critalarm/core/failures/failure.dart';
import 'package:critalarm/core/result/result.dart';
import 'package:critalarm/features/onboarding/domain/entities/onboarding_draft.dart';
import 'package:critalarm/features/onboarding/domain/repositories/onboarding_progress_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SharedPrefsOnboardingProgressRepository
    implements OnboardingProgressRepository {
  const SharedPrefsOnboardingProgressRepository(this._prefs);

  final SharedPreferences _prefs;

  static const _keyOnboardingCompleted = 'onboarding_completed';
  static const _keyStep = 'onboarding_step';
  static const _keyServerUrl = 'onboarding_draft_server_url';
  static const _keyAdminToken = 'onboarding_draft_admin_token';
  static const _keySelfHosting = 'onboarding_draft_self_hosting';
  static const _keyCountdownEndsAt = 'onboarding_countdown_ends_at';

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

  @override
  Future<AppResult<OnboardingDraft>> readDraft() async {
    try {
      final endsAtMs = _prefs.getInt(_keyCountdownEndsAt);
      return OnboardingDraft(
        step: OnboardingStep.fromName(_prefs.getString(_keyStep)),
        serverUrl: _prefs.getString(_keyServerUrl) ?? '',
        adminToken: _prefs.getString(_keyAdminToken) ?? '',
        isSelfHosting: _prefs.getBool(_keySelfHosting) ?? false,
        countdownEndsAt: endsAtMs == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(endsAtMs),
      ).toSuccess();
    } on Exception catch (e) {
      return Failure.unexpected(message: e.toString()).toFailure();
    }
  }

  @override
  Future<AppResult<Unit>> saveDraft(OnboardingDraft draft) async {
    try {
      await _prefs.setString(_keyStep, draft.step.name);
      await _prefs.setString(_keyServerUrl, draft.serverUrl);
      await _prefs.setString(_keyAdminToken, draft.adminToken);
      await _prefs.setBool(_keySelfHosting, draft.isSelfHosting);
      final endsAt = draft.countdownEndsAt;
      if (endsAt == null) {
        await _prefs.remove(_keyCountdownEndsAt);
      } else {
        await _prefs.setInt(_keyCountdownEndsAt, endsAt.millisecondsSinceEpoch);
      }
      return unit.toSuccess();
    } on Exception catch (e) {
      return Failure.unexpected(message: e.toString()).toFailure();
    }
  }

  @override
  Future<AppResult<Unit>> clearDraft() async {
    try {
      await _prefs.remove(_keyStep);
      await _prefs.remove(_keyServerUrl);
      await _prefs.remove(_keyAdminToken);
      await _prefs.remove(_keySelfHosting);
      await _prefs.remove(_keyCountdownEndsAt);
      return unit.toSuccess();
    } on Exception catch (e) {
      return Failure.unexpected(message: e.toString()).toFailure();
    }
  }
}
