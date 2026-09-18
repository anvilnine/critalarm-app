import 'package:critalarm/features/prompts/domain/repositories/home_prompt_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SharedPrefsHomePromptRepository implements HomePromptRepository {
  const SharedPrefsHomePromptRepository(this._prefs);

  final SharedPreferences _prefs;

  static const _accountDismissedKey = 'home_prompt_account_dismissed_at';
  static const _proDismissedKey = 'home_prompt_pro_dismissed_at';
  static const _lastResolvedKey = 'home_prompt_last_cleared_at';

  @override
  DateTime? getAccountPromptDismissedAt() {
    final ms = _prefs.getInt(_accountDismissedKey);
    return ms != null ? DateTime.fromMillisecondsSinceEpoch(ms) : null;
  }

  @override
  Future<void> dismissAccountPrompt() async {
    await _prefs.setInt(
      _accountDismissedKey,
      DateTime.now().millisecondsSinceEpoch,
    );
    await markBannerResolvedOrDismissed();
  }

  @override
  DateTime? getProPromptDismissedAt() {
    final ms = _prefs.getInt(_proDismissedKey);
    return ms != null ? DateTime.fromMillisecondsSinceEpoch(ms) : null;
  }

  @override
  Future<void> dismissProPrompt() async {
    await _prefs.setInt(
      _proDismissedKey,
      DateTime.now().millisecondsSinceEpoch,
    );
    await markBannerResolvedOrDismissed();
  }

  @override
  DateTime? getLastBannerResolvedOrDismissedAt() {
    final ms = _prefs.getInt(_lastResolvedKey);
    return ms != null ? DateTime.fromMillisecondsSinceEpoch(ms) : null;
  }

  @override
  Future<void> markBannerResolvedOrDismissed() async {
    await _prefs.setInt(
      _lastResolvedKey,
      DateTime.now().millisecondsSinceEpoch,
    );
  }
}
