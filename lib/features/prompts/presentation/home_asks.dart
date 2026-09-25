import 'dart:async';

import 'package:critalarm/app/di.dart';
import 'package:critalarm/app/state/topics_cubit.dart';
import 'package:critalarm/core/alarm/alarm_focus.dart';
import 'package:critalarm/core/telemetry/telemetry_gate.dart';
import 'package:critalarm/features/prompts/domain/home_ask_rules.dart';
import 'package:critalarm/features/prompts/domain/pro_ending.dart';
import 'package:critalarm/features/prompts/domain/pro_prompt_rules.dart';
import 'package:critalarm/features/prompts/domain/repositories/home_prompt_repository.dart';
import 'package:critalarm/features/prompts/domain/setup_gate.dart';
import 'package:critalarm/features/prompts/presentation/cubits/home_prompt_cubit.dart';
import 'package:critalarm/features/prompts/presentation/widgets/consent_prompt_sheet.dart';
import 'package:critalarm/features/prompts/presentation/widgets/pro_plan_sheet.dart';
import 'package:critalarm/features/reminders/domain/home_reminder_ask_rules.dart';
import 'package:critalarm/features/reminders/domain/reminder_plan_trigger.dart';
import 'package:critalarm/features/reminders/domain/reminder_settler.dart';
import 'package:critalarm/features/reminders/domain/reminder_store.dart';
import 'package:critalarm/features/reminders/presentation/widgets/reminder_ask_sheets.dart';
import 'package:critalarm/features/settings/domain/repositories/privacy_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:in_app_review/in_app_review.dart';

bool _isAsking = false;

/// Runs whichever ask is due as home opens or comes back to the front.
/// `HomeReminderAskRules` goes first (the Reminders sheet, or a Pro sheet
/// a night ack left owed), then `HomeAskRules` (the consent sheet or the
/// store review popup). At most one shows.
///
/// When one is due, waits a moment so home has settled, and gives up if
/// another screen has been pushed on top in the meantime.
Future<void> runHomeAsk(BuildContext context) async {
  if (_isAsking) return;
  // Nothing pops up while an alarm is under way.
  if (getIt<AlarmFocus>().on) return;
  _isAsking = true;
  try {
    // Pro ending or ended comes first: it has a date attached.
    final pro = await getIt<ProEnding>().read();
    if (pro.sheet != ProPlanSheet.none) {
      await Future<void>.delayed(const Duration(milliseconds: 800));
      if (!context.mounted) return;
      if (ModalRoute.of(context)?.isCurrent == false) return;
      await showProPlanSheet(context, pro);
      // The pill waits for the sheet, so ask the home prompts again.
      if (context.mounted) {
        unawaited(context.read<HomePromptCubit>().load());
      }
      return;
    }

    final reminderAsk = await _nextReminderAsk();
    if (reminderAsk != HomeReminderAsk.none) {
      await Future<void>.delayed(const Duration(milliseconds: 800));
      if (!context.mounted) return;
      if (ModalRoute.of(context)?.isCurrent == false) return;
      await _showReminderAsk(context, reminderAsk);
      return;
    }

    final ask = await getIt<HomeAskRules>().next();
    if (ask == HomeAsk.none) return;

    await Future<void>.delayed(const Duration(milliseconds: 800));
    if (!context.mounted) return;
    if (ModalRoute.of(context)?.isCurrent == false) return;

    switch (ask) {
      case HomeAsk.consent:
        await showConsentPromptSheet(
          context: context,
          repository: getIt<HomePromptRepository>(),
          onShare: _share,
        );
      case HomeAsk.review:
        await _askForReview();
        // The popup moved the review ask time, so a planned review
        // reminder must be dropped.
        unawaited(getIt<ReminderPlanTrigger>().run());
      case HomeAsk.none:
        break;
    }
  } finally {
    _isAsking = false;
  }
}

/// The Reminders sheet for an install that tested before this update, or a
/// Pro sheet a night ack left for the daytime. Checked before the consent
/// sheet and the review popup.
Future<HomeReminderAsk> _nextReminderAsk() async {
  final store = getIt<ReminderStore>();
  final prompts = getIt<HomePromptRepository>();
  // A delivered review or feedback reminder counts as an ask before any ask
  // time is read below.
  await getIt<ReminderSettler>().settleAsks(now: DateTime.now());
  final isOwed = store.readProSheetOwed();
  final proShouldAsk = isOwed && await getIt<ProPromptRules>().shouldAsk();
  if (isOwed && !proShouldAsk) await store.writeProSheetOwed(owed: false);
  return HomeReminderAskRules.decide(
    isSetupDone: await getIt<SetupGate>().isDone(),
    now: DateTime.now(),
    isWeb: kIsWeb,
    isRinging: false,
    isSheetShown: store.readSheetShown(),
    hasCriticalTopic: getIt<TopicsCubit>().state.topics.any((t) => t.critical),
    lastAcknowledgedAt: prompts.getLastAcknowledgedAt(),
    isProSheetOwed: isOwed,
    proShouldAsk: proShouldAsk,
    otherAskedAt: [
      prompts.getProPromptAskedAt(),
      prompts.getConsentAskedAt(),
      prompts.getReviewAskedAt(),
      prompts.getFeedbackAskedAt(),
    ],
  );
}

Future<void> _showReminderAsk(
  BuildContext context,
  HomeReminderAsk ask,
) async {
  final store = getIt<ReminderStore>();
  switch (ask) {
    case HomeReminderAsk.remindersSheet:
      await askRemindersSheet(context);
    case HomeReminderAsk.proSheet:
      await store.writeProSheetOwed(owed: false);
      if (!context.mounted) return;
      await askProSheet(context);
    case HomeReminderAsk.none:
      break;
  }
}

/// Saves the choice and switches collection on, the same two steps the
/// Privacy screen's switches take.
Future<void> _share({
  required bool crashReports,
  required bool analytics,
}) async {
  final gate = getIt<TelemetryGate>();
  final privacy = getIt<PrivacyRepository>();
  if (crashReports) {
    await gate.setCrashlyticsEnabled(true);
    await privacy.setCrashReportingEnabled(enabled: true);
  }
  if (analytics) {
    await gate.setAnalyticsEnabled(true);
    await privacy.setAnalyticsEnabled(enabled: true);
  }
}

/// The store decides whether its popup really shows, and never says. So the
/// ask counts the moment it is made.
Future<void> _askForReview() async {
  final review = InAppReview.instance;
  if (!await review.isAvailable()) return;
  await getIt<HomePromptRepository>().markReviewAsked();
  await review.requestReview();
}
