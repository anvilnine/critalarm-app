import 'package:critalarm/core/api/api_session.dart';
import 'package:critalarm/core/paywall/pro_override.dart';
import 'package:critalarm/features/account/domain/repositories/account_repository.dart';
import 'package:critalarm/features/in_app_notices/domain/home_ask_rules.dart';
import 'package:critalarm/features/in_app_notices/domain/repositories/in_app_notice_repository.dart';

/// Answers "should the Pro sheet ask right now". Holds no widgets and reads
/// the clock through the `now` it is given, so it tests without a screen
/// and without waiting.
///
/// Three moments ask: one critical topic under the free limit, a create
/// refused by the critical topic cap, and an alarm acknowledged. They all
/// follow the same rules, so the answer does not depend on which one called.
class ProAskRules {
  ProAskRules({
    required this.noticeRepository,
    required this.accountRepository,
    ProOverride? proOverride,
    DateTime Function()? now,
    bool Function()? offersOn,
    Future<bool> Function()? isSetupDone,
  }) : _proOverride = proOverride ?? appProOverride,
       _now = now ?? DateTime.now,
       // The field is private and the parameter is public, so it cannot be
       // an initializing formal.
       // ignore: prefer_initializing_formals
       _offersOn = offersOn,
       // Same reason as above.
       // ignore: prefer_initializing_formals
       _isSetupDone = isSetupDone;

  /// Being asked once buys 30 days of quiet, however the user left the sheet.
  static const Duration snooze = Duration(days: 30);

  /// A second "Not now" means never ask again. Pro lives in Settings then.
  static const int maxDismissals = 2;

  final InAppNoticeRepository noticeRepository;
  final AccountRepository accountRepository;
  final ProOverride _proOverride;
  final DateTime Function() _now;

  /// Reads the Offers switch. With Offers on, a "Remind me later" comes back
  /// as a notification, so the sheet stays away until that is delivered.
  final bool Function()? _offersOn;

  /// `SetupGate.isDone` in the app: onboarding finished and the first
  /// Feature Guide seen. Null in tests that do not care, and counts as done.
  final Future<bool> Function()? _isSetupDone;

  /// Reads what is stored and answers.
  Future<bool> shouldAsk() async {
    final isPaid = (await _readIsPaid()) || _proOverride.isForcingPro;
    final serverMode = await accountRepository.readServerMode();
    final isSetupDone =
        await (_isSetupDone?.call() ?? Future<bool>.value(true));

    return decide(
      isSetupDone: isSetupDone,
      isPaid: isPaid,
      isSelfHosted: serverMode == ServerMode.selfhosted,
      dismissCount: noticeRepository.getProAskDismissCount(),
      lastAskedAt: noticeRepository.getProAskedAt(),
      otherAskedAt: [
        noticeRepository.getConsentAskedAt(),
        noticeRepository.getReviewAskedAt(),
        noticeRepository.getFeedbackAskedAt(),
      ],
      isHandedToNotification:
          (_offersOn?.call() ?? false) &&
          noticeRepository.getProAskLaterAt() != null,
      now: _now(),
    );
  }

  /// A failed read counts as paid, the same as the reminder inputs reader,
  /// so a paying user is never asked because of a Keychain hiccup.
  Future<bool> _readIsPaid() async {
    try {
      return await accountRepository.readIsPaid();
    } on Object {
      return true;
    }
  }

  /// The rules themselves, with nothing to read from. Nobody is asked before
  /// onboarding is finished and the first Feature Guide has been seen or
  /// skipped. Somebody who already pays is never asked, and neither is a self
  /// hosted server.
  ///
  /// [lastAskedAt] is when the sheet was last shown, not when it was last
  /// turned down. Walking away from the sheet is an answer too, so the quiet
  /// period starts the moment it opens.
  ///
  /// [otherAskedAt] holds the consent sheet, the review popup and the
  /// feedback ask. The Pro sheet waits out `HomeAskRules.gap` after any of
  /// them.
  static bool decide({
    required bool isPaid,
    required bool isSelfHosted,
    required int dismissCount,
    required DateTime? lastAskedAt,
    required DateTime now,
    required bool isSetupDone,
    List<DateTime?> otherAskedAt = const [],
    bool isHandedToNotification = false,
  }) {
    if (!isSetupDone) return false;
    if (isPaid || isSelfHosted) return false;
    if (isHandedToNotification) return false;
    if (HomeAskRules.isWithinGap(now: now, askedAt: otherAskedAt)) {
      return false;
    }
    if (dismissCount >= maxDismissals) return false;
    if (lastAskedAt != null && now.difference(lastAskedAt) < snooze) {
      return false;
    }
    return true;
  }
}
