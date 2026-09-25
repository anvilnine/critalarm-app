import 'package:critalarm/app/di.dart';
import 'package:critalarm/core/api/api_session.dart';
import 'package:critalarm/features/account/domain/repositories/account_repository.dart';
import 'package:critalarm/features/prompts/domain/pro_prompt_rules.dart';
import 'package:critalarm/features/prompts/domain/repositories/home_prompt_repository.dart';
import 'package:critalarm/features/prompts/presentation/widgets/pro_prompt_sheet.dart';
import 'package:critalarm/features/reminders/domain/reminder_plan_trigger.dart';
import 'package:critalarm/features/reminders/domain/reminder_store.dart';
import 'package:critalarm/features/reminders/presentation/widgets/reminders_sheet.dart';
import 'package:flutter/widgets.dart';

/// The Reminders sheet as the alarm screen and home both ask it: reads the
/// server mode and whether the user pays, then plans again once the user
/// answers. Shows nothing if [context] is gone by then.
Future<void> askRemindersSheet(BuildContext context) async {
  final account = getIt<AccountRepository>();
  final mode = await account.readServerMode();
  final isPaid = await _readIsPaid(account);
  if (!context.mounted) return;
  await showRemindersSheet(
    context: context,
    store: getIt<ReminderStore>(),
    isSelfHosted: mode == ServerMode.selfhosted,
    isPaid: isPaid,
    onAnswered: getIt<ReminderPlanTrigger>().run,
  );
}

/// The Pro sheet as the alarm screen and home both ask it. Checks the rules
/// once more right before showing, because the user may have bought Pro
/// since the moment that decided to ask. Shows nothing if [context] is gone.
Future<void> askProSheet(BuildContext context) async {
  if (!await getIt<ProPromptRules>().shouldAsk()) return;
  if (!context.mounted) return;
  await showProPromptSheet(
    context: context,
    repository: getIt<HomePromptRepository>(),
  );
}

/// A failed read counts as paid, so a paying user never sees an offer.
Future<bool> _readIsPaid(AccountRepository account) async {
  try {
    return await account.readIsPaid();
  } on Object {
    return true;
  }
}
