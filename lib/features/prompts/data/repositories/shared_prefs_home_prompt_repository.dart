import 'package:critalarm/features/prompts/domain/repositories/home_prompt_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SharedPrefsHomePromptRepository implements HomePromptRepository {
  const SharedPrefsHomePromptRepository(this._prefs);

  final SharedPreferences _prefs;

  static const _accountDismissedKey = 'home_prompt_account_dismissed_at';
  static const _proAskedKey = 'home_prompt_pro_asked_at';
  static const _proDismissedKey = 'home_prompt_pro_dismissed_at';
  static const _proDismissCountKey = 'home_prompt_pro_dismiss_count';
  static const _lastResolvedKey = 'home_prompt_last_cleared_at';
  static const _firstSeenKey = 'home_prompt_first_seen_at';
  static const _consentAskedKey = 'home_prompt_consent_asked_at';
  static const _reviewAskedKey = 'home_prompt_review_asked_at';
  static const _reviewAskCountKey = 'home_prompt_review_ask_count';
  static const _feedbackAskedKey = 'home_prompt_feedback_asked_at';
  static const _proLaterKey = 'home_prompt_pro_later_at';
  static const _lastAcknowledgedKey = 'home_prompt_last_acknowledged_at';
  static const _afterAckSheetKey = 'home_prompt_after_ack_sheet_at';

  DateTime? _readTime(String key) {
    final ms = _prefs.getInt(key);
    return ms != null ? DateTime.fromMillisecondsSinceEpoch(ms) : null;
  }

  Future<void> _stampNow(String key) =>
      _prefs.setInt(key, DateTime.now().millisecondsSinceEpoch);

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
  DateTime? getProPromptAskedAt() {
    final ms = _prefs.getInt(_proAskedKey);
    return ms != null ? DateTime.fromMillisecondsSinceEpoch(ms) : null;
  }

  @override
  Future<void> markProPromptAsked() async {
    await _prefs.setInt(_proAskedKey, DateTime.now().millisecondsSinceEpoch);
  }

  @override
  DateTime? getProPromptDismissedAt() {
    final ms = _prefs.getInt(_proDismissedKey);
    return ms != null ? DateTime.fromMillisecondsSinceEpoch(ms) : null;
  }

  @override
  int getProPromptDismissCount() => _prefs.getInt(_proDismissCountKey) ?? 0;

  @override
  Future<void> dismissProPrompt() async {
    await _prefs.setInt(
      _proDismissedKey,
      DateTime.now().millisecondsSinceEpoch,
    );
    await _prefs.setInt(_proDismissCountKey, getProPromptDismissCount() + 1);
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

  @override
  DateTime? getFirstSeenAt() => _readTime(_firstSeenKey);

  @override
  Future<void> markFirstSeen() async {
    if (_prefs.containsKey(_firstSeenKey)) return;
    await _stampNow(_firstSeenKey);
  }

  @override
  DateTime? getConsentAskedAt() => _readTime(_consentAskedKey);

  @override
  Future<void> markConsentAsked() => _stampNow(_consentAskedKey);

  @override
  DateTime? getReviewAskedAt() => _readTime(_reviewAskedKey);

  @override
  int getReviewAskCount() => _prefs.getInt(_reviewAskCountKey) ?? 0;

  @override
  Future<void> markReviewAsked({DateTime? at}) async {
    await _prefs.setInt(
      _reviewAskedKey,
      (at ?? DateTime.now()).millisecondsSinceEpoch,
    );
    await _prefs.setInt(_reviewAskCountKey, getReviewAskCount() + 1);
  }

  @override
  DateTime? getFeedbackAskedAt() => _readTime(_feedbackAskedKey);

  @override
  Future<void> markFeedbackAsked({DateTime? at}) => _prefs.setInt(
    _feedbackAskedKey,
    (at ?? DateTime.now()).millisecondsSinceEpoch,
  );

  @override
  DateTime? getProPromptLaterAt() => _readTime(_proLaterKey);

  @override
  Future<void> remindProPromptLater() => _stampNow(_proLaterKey);

  @override
  Future<void> clearProPromptLater() => _prefs.remove(_proLaterKey);

  @override
  DateTime? getLastAcknowledgedAt() => _readTime(_lastAcknowledgedKey);

  @override
  Future<void> markAcknowledged() => _stampNow(_lastAcknowledgedKey);

  @override
  DateTime? getAfterAckSheetShownAt() => _readTime(_afterAckSheetKey);

  @override
  Future<void> markAfterAckSheetShown() => _stampNow(_afterAckSheetKey);

  static const _proEndingSheetKey = 'home_prompt_pro_ending_sheet_for';
  static const _proEndingPillKey = 'home_prompt_pro_ending_pill_dismissed_at';
  static const _proEndingLastDaysKey = 'home_prompt_pro_ending_last_days_for';
  static const _proKnownExpiryKey = 'home_prompt_pro_known_expiry';
  static const _proPaidAccountKey = 'home_prompt_pro_paid_account';
  static const _proEndedDueKey = 'home_prompt_pro_ended_due_for';

  @override
  String? getProEndingSheetShownFor() => _prefs.getString(_proEndingSheetKey);

  @override
  Future<void> markProEndingSheetShown(String key) =>
      _prefs.setString(_proEndingSheetKey, key);

  @override
  DateTime? getProEndingPillDismissedAt() => _readTime(_proEndingPillKey);

  @override
  Future<void> dismissProEndingPill() => _stampNow(_proEndingPillKey);

  @override
  String? getProEndingLastDaysDismissedFor() =>
      _prefs.getString(_proEndingLastDaysKey);

  @override
  Future<void> markProEndingLastDaysDismissed(String key) =>
      _prefs.setString(_proEndingLastDaysKey, key);

  @override
  DateTime? getProKnownExpiry() => _readTime(_proKnownExpiryKey);

  @override
  Future<void> setProKnownExpiry(DateTime at) =>
      _prefs.setInt(_proKnownExpiryKey, at.millisecondsSinceEpoch);

  @override
  String? getProPaidAccountId() => _prefs.getString(_proPaidAccountKey);

  @override
  Future<void> setProPaidAccountId(String? accountId) => accountId == null
      ? _prefs.remove(_proPaidAccountKey)
      : _prefs.setString(_proPaidAccountKey, accountId);

  @override
  String? getProEndedSheetDueFor() => _prefs.getString(_proEndedDueKey);

  @override
  Future<void> setProEndedSheetDueFor(String? accountId) => accountId == null
      ? _prefs.remove(_proEndedDueKey)
      : _prefs.setString(_proEndedDueKey, accountId);
}
