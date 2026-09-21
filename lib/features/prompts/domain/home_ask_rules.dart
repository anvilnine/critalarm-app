import 'package:critalarm/features/prompts/domain/repositories/home_prompt_repository.dart';
import 'package:critalarm/features/settings/domain/repositories/privacy_repository.dart';
import 'package:flutter/foundation.dart';

/// What the home screen should ask for as it opens, if anything.
enum HomeAsk { none, consent, review }

/// Answers "should home ask for something right now". Two asks live here:
/// the analytics and crash report sheet, and the store review popup. Like
/// `ProPromptRules`, it holds no widgets and reads the clock through the
/// `now` it is given.
///
/// The consent sheet goes first. Both wait 24 hours after any other ask,
/// the Pro sheet included, so the user never gets two in one sitting.
class HomeAskRules {
  HomeAskRules({
    required this.homePromptRepository,
    required this.privacyRepository,
    bool? isWeb,
    DateTime Function()? now,
  }) : _isWeb = isWeb ?? kIsWeb,
       _now = now ?? DateTime.now;

  /// The shortest time between any two asks.
  static const Duration gap = Duration(hours: 24);

  /// The review popup waits this long after the install.
  static const Duration reviewMinInstallAge = Duration(days: 3);

  /// The review popup waits this long after the last time it was asked for.
  static const Duration reviewSnooze = Duration(days: 120);

  /// Apple shows its popup at most 3 times a year anyway.
  static const int maxReviewAsks = 3;

  final HomePromptRepository homePromptRepository;
  final PrivacyRepository privacyRepository;
  final bool _isWeb;
  final DateTime Function() _now;

  /// Stamps the first home open, reads what is stored and answers.
  Future<HomeAsk> next({required bool isRinging}) async {
    await homePromptRepository.markFirstSeen();
    final privacy = (await privacyRepository.getPrivacySettings()).getOrNull();

    return decide(
      now: _now(),
      firstSeenAt: homePromptRepository.getFirstSeenAt(),
      consentAskedAt: homePromptRepository.getConsentAskedAt(),
      isConsentGiven:
          privacy != null &&
          privacy.analyticsEnabled &&
          privacy.crashReportingEnabled,
      reviewAskedAt: homePromptRepository.getReviewAskedAt(),
      reviewAskCount: homePromptRepository.getReviewAskCount(),
      lastAcknowledgedAt: homePromptRepository.getLastAcknowledgedAt(),
      proAskedAt: homePromptRepository.getProPromptAskedAt(),
      isRinging: isRinging,
      isWeb: _isWeb,
    );
  }

  /// The rules themselves, with nothing to read from.
  ///
  /// Days are calendar days on the phone's clock, so an alarm acknowledged
  /// at 23:50 makes the review popup due ten minutes later.
  static HomeAsk decide({
    required DateTime now,
    required DateTime? firstSeenAt,
    required DateTime? consentAskedAt,
    required bool isConsentGiven,
    required DateTime? reviewAskedAt,
    required int reviewAskCount,
    required DateTime? lastAcknowledgedAt,
    required DateTime? proAskedAt,
    required bool isRinging,
    required bool isWeb,
  }) {
    if (isWeb || isRinging || firstSeenAt == null) return HomeAsk.none;
    if (isWithinGap(
      now: now,
      askedAt: [proAskedAt, consentAskedAt, reviewAskedAt],
    )) {
      return HomeAsk.none;
    }

    final today = _day(now);

    final isConsentDue =
        consentAskedAt == null &&
        !isConsentGiven &&
        today.isAfter(_day(firstSeenAt));
    if (isConsentDue) return HomeAsk.consent;

    if (lastAcknowledgedAt == null) return HomeAsk.none;
    if (!today.isAfter(_day(lastAcknowledgedAt))) return HomeAsk.none;
    if (now.difference(firstSeenAt) < reviewMinInstallAge) return HomeAsk.none;
    if (reviewAskCount >= maxReviewAsks) return HomeAsk.none;
    if (reviewAskedAt != null) {
      if (!lastAcknowledgedAt.isAfter(reviewAskedAt)) return HomeAsk.none;
      if (now.difference(reviewAskedAt) < reviewSnooze) return HomeAsk.none;
    }
    return HomeAsk.review;
  }

  /// Whether the latest of [askedAt] is less than [gap] ago.
  static bool isWithinGap({
    required DateTime now,
    required List<DateTime?> askedAt,
  }) {
    for (final at in askedAt) {
      if (at != null && now.difference(at) < gap) return true;
    }
    return false;
  }

  static DateTime _day(DateTime at) => DateTime(at.year, at.month, at.day);
}
