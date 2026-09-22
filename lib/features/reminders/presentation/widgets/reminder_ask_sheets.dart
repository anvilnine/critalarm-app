import 'package:critalarm/app/di.dart';
import 'package:critalarm/core/api/api_session.dart';
import 'package:critalarm/features/account/domain/repositories/account_repository.dart';
import 'package:critalarm/features/prompts/domain/repositories/home_prompt_repository.dart';
import 'package:critalarm/features/prompts/presentation/widgets/pro_prompt_sheet.dart';
import 'package:critalarm/features/reminders/domain/reminder_plan_trigger.dart';
import 'package:critalarm/features/reminders/domain/reminder_store.dart';
import 'package:critalarm/features/reminders/presentation/widgets/reminders_sheet.dart';
import 'package:flutter/widgets.dart';

/// The Reminders sheet as the alarm screen and home both ask it: reads the
/// server mode, then plans again once the user answers. Shows nothing if
/// [context] is gone by then.
Future<void> askRemindersSheet(BuildContext context) async {
  final mode = await getIt<AccountRepository>().readServerMode();
  if (!context.mounted) return;
  await showRemindersSheet(
    context: context,
    store: getIt<ReminderStore>(),
    isSelfHosted: mode == ServerMode.selfhosted,
    onAnswered: getIt<ReminderPlanTrigger>().run,
  );
}

/// The Pro sheet as the alarm screen and home both ask it. Shows nothing if
/// [context] is gone.
Future<void> askProSheet(BuildContext context) async {
  if (!context.mounted) return;
  await showProPromptSheet(
    context: context,
    repository: getIt<HomePromptRepository>(),
  );
}
