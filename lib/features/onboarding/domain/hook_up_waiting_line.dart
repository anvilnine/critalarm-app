import 'package:critalarm/features/onboarding/domain/setup_use/setup_use_profile.dart';
import 'package:critalarm/gen/locale_keys.g.dart';

/// The `en.json` key of the mono line the hook-up step's waiting card shows
/// for [line].
///
/// An exhaustive switch, so a line added to [SetupWaitingLine] stops the
/// build until it has words here.
String hookUpWaitingLineKey(SetupWaitingLine line) => switch (line) {
  SetupWaitingLine.sendFirstLine => LocaleKeys.home_card_foot_send_the_line,
  SetupWaitingLine.fromYourServer =>
    LocaleKeys.setup_use_waiting_from_your_server,
  SetupWaitingLine.runTheJob => LocaleKeys.setup_use_waiting_run_the_job,
  SetupWaitingLine.uptimeKuma => LocaleKeys.setup_use_waiting_uptime_kuma,
  SetupWaitingLine.homeAssistant => LocaleKeys.setup_use_waiting_home_assistant,
  SetupWaitingLine.healthchecks => LocaleKeys.setup_use_waiting_healthchecks,
};
