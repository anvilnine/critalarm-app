import 'package:critalarm/core/api/api_session.dart';
import 'package:critalarm/core/paywall/pro_override.dart';
import 'package:critalarm/features/account/domain/repositories/account_repository.dart';
import 'package:critalarm/features/prompts/domain/repositories/home_prompt_repository.dart';

enum ProAskTrigger {
  /// The user is one topic under the free critical topic limit.
  nearCriticalTopicLimit,

  /// A create was refused because the cap was reached.
  criticalTopicCapReached,

  /// The first incident was acknowledged.
  firstIncidentAcknowledged,
}

/// Answers "should the Pro sheet ask right now". Holds no widgets and reads
/// the clock through the `now` it is given, so it tests without a screen
/// and without waiting.
class ProPromptRules {
  ProPromptRules({
    required this.homePromptRepository,
    required this.accountRepository,
    ProOverride? proOverride,
    DateTime Function()? now,
  })  : _proOverride = proOverride ?? appProOverride,
        _now = now ?? DateTime.now;

  /// The first "Not now" buys 30 days of quiet.
  static const Duration snooze = Duration(days: 30);

  /// A second "Not now" means never ask again. Pro lives in Settings then.
  static const int maxDismissals = 2;

  final HomePromptRepository homePromptRepository;
  final AccountRepository accountRepository;
  final ProOverride _proOverride;
  final DateTime Function() _now;

  /// Reads what is stored and answers for [trigger].
  Future<bool> shouldAsk(ProAskTrigger trigger) async {
    final isPaid =
        (await accountRepository.readIsPaid()) || _proOverride.isForcingPro;
    final serverMode = await accountRepository.readServerMode();

    return decide(
      trigger: trigger,
      isPaid: isPaid,
      isSelfHosted: serverMode == ServerMode.selfhosted,
      dismissCount: homePromptRepository.getProPromptDismissCount(),
      lastDismissedAt: homePromptRepository.getProPromptDismissedAt(),
      now: _now(),
    );
  }

  /// The rules themselves, with nothing to read from. Somebody who already
  /// pays is never asked, and neither is a self hosted server, whatever the
  /// [trigger] is.
  static bool decide({
    required ProAskTrigger trigger,
    required bool isPaid,
    required bool isSelfHosted,
    required int dismissCount,
    required DateTime? lastDismissedAt,
    required DateTime now,
  }) {
    if (isPaid || isSelfHosted) return false;
    if (dismissCount >= maxDismissals) return false;
    if (lastDismissedAt != null && now.difference(lastDismissedAt) < snooze) {
      return false;
    }
    return true;
  }
}
