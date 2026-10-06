import 'package:critalarm/core/api/api_session.dart';
import 'package:critalarm/core/paywall/pro_override.dart';
import 'package:critalarm/features/account/domain/repositories/account_repository.dart';
import 'package:critalarm/features/in_app_notices/domain/home_ask_rules.dart';
import 'package:critalarm/features/in_app_notices/domain/repositories/in_app_notice_repository.dart';
import 'package:critalarm/features/topics/domain/first_message/first_message_store.dart';

/// What Home does with the day-0 card on an open.
///
/// [start] shows it for the first time, [keep] keeps showing it, [end] ends
/// it for good, and [none] shows nothing.
enum Day0CardDecision { none, start, keep, end }

/// Answers "should Home show the day-0 card now". The card is a quiet line
/// in the Home list, shown once after the app has really worked: a message
/// arrived and a real alarm was acknowledged. It says what the free plan
/// keeps and what Hosted adds. It is a card on a screen. It is not a
/// notification and it makes no alert, so it stays inside the rule that the
/// app never generates alerts.
///
/// It is an ask. Its first show stamps `getDay0CardShownAt`, which the Pro
/// sheet, the consent sheet, the review popup and the reminders read as an
/// ask for the 24 hour gap (`HomeAskRules.gap`), and it waits out that gap
/// after any of them. It ends for good when dismissed, when "See plans" is
/// tapped, or after it was on screen for [maxOpens] Home opens.
///
/// Holds no widgets and reads the clock through the `now` it is given.
class Day0CardRules {
  Day0CardRules({
    required this.noticeRepository,
    required this.accountRepository,
    required this.firstMessageStore,
    required bool isWeb,
    ProOverride? proOverride,
    DateTime Function()? now,
    Future<bool> Function()? isSetupDone,
    bool Function()? isRinging,
  }) : _isWeb = isWeb,
       _proOverride = proOverride ?? appProOverride,
       _now = now ?? DateTime.now,
       // The field is private and the parameter is public, so it cannot be
       // an initializing formal.
       // ignore: prefer_initializing_formals
       _isSetupDone = isSetupDone,
       // Same reason as above.
       // ignore: prefer_initializing_formals
       _isRinging = isRinging;

  /// The card ends for good once it has been on screen for this many Home
  /// opens without a tap.
  static const int maxOpens = 3;

  final InAppNoticeRepository noticeRepository;
  final AccountRepository accountRepository;
  final FirstMessageStore firstMessageStore;
  final bool _isWeb;
  final ProOverride _proOverride;
  final DateTime Function() _now;

  /// `SetupGate.isDone` in the app. Null in tests that do not care, and
  /// counts as done.
  final Future<bool> Function()? _isSetupDone;

  /// `AlarmFocus.on` in the app. Null counts as not ringing.
  final bool Function()? _isRinging;

  /// Reads what is stored and answers. [isNewOpen] is true for a Home open
  /// and false for any other look at the same screen, such as a guide
  /// ending, so only an open uses up one of the [maxOpens].
  Future<Day0CardDecision> next({required bool isNewOpen}) async {
    final isPaid = (await _readIsPaid()) || _proOverride.isForcingPro;
    final serverMode = await accountRepository.readServerMode();
    final isSetupDone =
        await (_isSetupDone?.call() ?? Future<bool>.value(true));

    return decide(
      isHosted: serverMode == ServerMode.hosted,
      isPaid: isPaid,
      isSetupDone: isSetupDone,
      isFirstMessageReceived: firstMessageStore.isReceived,
      firstRealAckAt: noticeRepository.getFirstRealAcknowledgedAt(),
      shownAt: noticeRepository.getDay0CardShownAt(),
      endedAt: noticeRepository.getDay0CardEndedAt(),
      openCount: noticeRepository.getDay0CardOpenCount(),
      isNewOpen: isNewOpen,
      otherAskedAt: [
        noticeRepository.getProAskedAt(),
        noticeRepository.getConsentAskedAt(),
        noticeRepository.getReviewAskedAt(),
        noticeRepository.getFeedbackAskedAt(),
      ],
      isWeb: _isWeb,
      isRinging: _isRinging?.call() ?? false,
      now: _now(),
    );
  }

  /// A failed read counts as paid, the same as `ProAskRules`, so a paying
  /// user is never shown the card because of a Keychain hiccup.
  Future<bool> _readIsPaid() async {
    try {
      return await accountRepository.readIsPaid();
    } on Object {
      return true;
    }
  }

  /// The rules themselves, with nothing to read from.
  ///
  /// To start, every one of these holds: hosted server mode, not paid, setup
  /// done, a first message received, a first real acknowledge stored, the
  /// card never shown before, no other ask inside the gap, not on web, and
  /// no alarm ringing.
  ///
  /// Once started, the card stays while the user is still on the hosted plan
  /// without paying, not on web and not in an alarm. The gap does not apply
  /// to it again, because its own stamp is the one the others wait for.
  /// [endedAt] set means it never comes back.
  static Day0CardDecision decide({
    required bool isHosted,
    required bool isPaid,
    required bool isSetupDone,
    required bool isFirstMessageReceived,
    required DateTime? firstRealAckAt,
    required DateTime? shownAt,
    required DateTime? endedAt,
    required int openCount,
    required bool isNewOpen,
    required DateTime now,
    required bool isWeb,
    required bool isRinging,
    List<DateTime?> otherAskedAt = const [],
  }) {
    if (endedAt != null) return Day0CardDecision.none;
    if (isWeb || isRinging) return Day0CardDecision.none;
    if (!isHosted || isPaid || !isSetupDone) return Day0CardDecision.none;

    if (shownAt != null) {
      if (isNewOpen && openCount >= maxOpens) return Day0CardDecision.end;
      return Day0CardDecision.keep;
    }

    if (!isFirstMessageReceived || firstRealAckAt == null) {
      return Day0CardDecision.none;
    }
    if (HomeAskRules.isWithinGap(now: now, askedAt: otherAskedAt)) {
      return Day0CardDecision.none;
    }
    return Day0CardDecision.start;
  }
}
