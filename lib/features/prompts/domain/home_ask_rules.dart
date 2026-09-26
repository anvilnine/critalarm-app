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
    Future<void> Function()? settle,
    Future<bool> Function()? isSetupDone,
    DateTime? Function()? newestAckedAt,
  }) : _isWeb = isWeb ?? kIsWeb,
       _now = now ?? DateTime.now,
       // The field is private and the parameter is public, so it cannot be
       // an initializing formal.
       // ignore: prefer_initializing_formals
       _settle = settle,
       // Same reason as above.
       // ignore: prefer_initializing_formals
       _isSetupDone = isSetupDone,
       // Same reason as above.
       // ignore: prefer_initializing_formals
       _newestAckedAt = newestAckedAt;

  /// The shortest time between any two asks.
  static const Duration gap = Duration(hours: 24);

  /// The review popup waits this long after the install.
  static const Duration reviewMinInstallAge = Duration(days: 3);

  /// The review popup waits this long after the last time it was asked for.
  static const Duration reviewSnooze = Duration(days: 120);

  /// Apple shows its popup at most 3 times a year anyway.
  static const int maxReviewAsks = 3;

  /// An ack before this hour is a night ack. The review popup skips the 24
  /// hours after one, so it never shares a morning with the morning after
  /// reminder (idea 10).
  static const int nightAckEndHour = 6;

  final HomePromptRepository homePromptRepository;
  final PrivacyRepository privacyRepository;
  final bool _isWeb;
  final DateTime Function() _now;

  /// Books review and feedback reminders whose fire time passed, so a
  /// delivered one counts before this decides. `ReminderSettler.settleAsks`
  /// in the app; null in tests that do not care.
  final Future<void> Function()? _settle;

  /// `SetupGate.isDone` in the app: onboarding finished and the first
  /// Feature Guide seen. Null in tests that do not care, and counts as done.
  final Future<bool> Function()? _isSetupDone;

  /// The newest ack across the shared incident list. An ack made on another
  /// device counts too, which the repository's own stamp never sees. Null in
  /// tests that do not care.
  final DateTime? Function()? _newestAckedAt;

  /// Stamps the first home open, reads what is stored and answers.
  ///
  /// Nothing here asks whether the phone is ringing. `runHomeAsk` checks
  /// `AlarmFocus` before it gets this far, and that answer holds through a
  /// Stop and through the quiet seconds before the next ring.
  Future<HomeAsk> next() async {
    await _settle?.call();
    await homePromptRepository.markFirstSeen();
    final privacy = (await privacyRepository.getPrivacySettings()).getOrNull();
    final isSetupDone =
        await (_isSetupDone?.call() ?? Future<bool>.value(true));

    return decide(
      isSetupDone: isSetupDone,
      now: _now(),
      firstSeenAt: homePromptRepository.getFirstSeenAt(),
      consentAskedAt: homePromptRepository.getConsentAskedAt(),
      isConsentGiven:
          privacy != null &&
          privacy.analyticsEnabled &&
          privacy.crashReportingEnabled,
      reviewAskedAt: homePromptRepository.getReviewAskedAt(),
      reviewAskCount: homePromptRepository.getReviewAskCount(),
      lastAcknowledgedAt: newerOf(
        _newestAckedAt?.call(),
        homePromptRepository.getLastAcknowledgedAt(),
      ),
      proAskedAt: homePromptRepository.getProPromptAskedAt(),
      isRinging: false,
      isWeb: _isWeb,
      feedbackAskedAt: homePromptRepository.getFeedbackAskedAt(),
    );
  }

  /// The rules themselves, with nothing to read from. Nothing is asked
  /// before onboarding is finished and the first Feature Guide has been seen
  /// or skipped.
  ///
  /// Days are calendar days on the phone's clock, so an alarm acknowledged
  /// at 23:50 makes the review popup due ten minutes later.
  static HomeAsk decide({
    required bool isSetupDone,
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
    DateTime? feedbackAskedAt,
  }) {
    if (!isSetupDone) return HomeAsk.none;
    if (isWeb || isRinging || firstSeenAt == null) return HomeAsk.none;
    if (isWithinGap(
      now: now,
      askedAt: [proAskedAt, consentAskedAt, reviewAskedAt, feedbackAskedAt],
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
    if (lastAcknowledgedAt.hour < nightAckEndHour &&
        now.difference(lastAcknowledgedAt) < gap) {
      return HomeAsk.none;
    }
    if (!today.isAfter(_day(lastAcknowledgedAt))) return HomeAsk.none;
    if (now.difference(firstSeenAt) < reviewMinInstallAge) return HomeAsk.none;
    if (reviewAskCount >= maxReviewAsks) return HomeAsk.none;
    if (reviewAskedAt != null) {
      if (!lastAcknowledgedAt.isAfter(reviewAskedAt)) return HomeAsk.none;
      if (now.difference(reviewAskedAt) < reviewSnooze) return HomeAsk.none;
    }
    return HomeAsk.review;
  }

  /// The later of two times, or whichever one is not null.
  static DateTime? newerOf(DateTime? a, DateTime? b) {
    if (a == null) return b;
    if (b == null) return a;
    return a.isAfter(b) ? a : b;
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
