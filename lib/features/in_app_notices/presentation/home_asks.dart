import 'dart:async';

import 'package:critalarm/app/di.dart';
import 'package:critalarm/app/state/topics_cubit.dart';
import 'package:critalarm/core/alarm/alarm_focus.dart';
import 'package:critalarm/core/telemetry/telemetry_gate.dart';
import 'package:critalarm/features/in_app_notices/domain/home_ask_rules.dart';
import 'package:critalarm/features/in_app_notices/domain/pro_ask_rules.dart';
import 'package:critalarm/features/in_app_notices/domain/pro_ending.dart';
import 'package:critalarm/features/in_app_notices/domain/repositories/in_app_notice_repository.dart';
import 'package:critalarm/features/in_app_notices/domain/setup_gate.dart';
import 'package:critalarm/features/in_app_notices/presentation/cubits/in_app_notice_cubit.dart';
import 'package:critalarm/features/in_app_notices/presentation/widgets/consent_ask_sheet.dart';
import 'package:critalarm/features/in_app_notices/presentation/widgets/pro_plan_sheet.dart';
import 'package:critalarm/features/local_reminders/domain/local_reminder_home_ask_rules.dart';
import 'package:critalarm/features/local_reminders/domain/local_reminder_plan_trigger.dart';
import 'package:critalarm/features/local_reminders/domain/local_reminder_settler.dart';
import 'package:critalarm/features/local_reminders/domain/local_reminder_store.dart';
import 'package:critalarm/features/local_reminders/presentation/widgets/local_reminder_ask_sheets.dart';
import 'package:critalarm/features/settings/domain/repositories/privacy_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:in_app_review/in_app_review.dart';

bool _isAsking = false;

/// Runs whichever ask is due as home opens or comes back to the front.
/// `LocalReminderHomeAskRules` goes first (the Local reminders sheet, or a
/// Pro sheet a night ack left owed), then `HomeAskRules` (the consent sheet
/// or the store review popup). At most one shows.
///
/// When one is due, waits a moment so home has settled, and gives up if
/// another screen has been pushed on top in the meantime.
///
/// Nothing shows before onboarding is finished and the Topics Feature Guide
/// seen, or while any guide is up (`SetupGate`). Home runs this again when a
/// guide ends, so what was held back shows after it.
Future<void> runHomeAsk(BuildContext context) async {
  if (_isAsking) return;
  // Nothing pops up while an alarm is under way.
  if (getIt<AlarmFocus>().on) return;
  _isAsking = true;
  try {
    if (!await getIt<SetupGate>().isDone()) return;
    if (!context.mounted) return;
    // Pro ending or ended comes first: it has a date attached.
    final pro = await getIt<ProEnding>().read();
    if (pro.sheet != ProPlanSheet.none) {
      await Future<void>.delayed(const Duration(milliseconds: 800));
      if (!context.mounted || !await _stillFree(context)) return;
      if (!context.mounted) return;
      await showProPlanSheet(context, pro);
      // The pill waits for the sheet, so reload the notices.
      if (context.mounted) {
        unawaited(context.read<InAppNoticeCubit>().load());
      }
      return;
    }

    final localReminderAsk = await _nextLocalReminderAsk();
    if (localReminderAsk != LocalReminderHomeAsk.none) {
      await Future<void>.delayed(const Duration(milliseconds: 800));
      if (!context.mounted || !await _stillFree(context)) return;
      if (!context.mounted) return;
      await _showLocalReminderAsk(context, localReminderAsk);
      return;
    }

    final ask = await getIt<HomeAskRules>().next();
    if (ask == HomeAsk.none) return;

    await Future<void>.delayed(const Duration(milliseconds: 800));
    if (!context.mounted || !await _stillFree(context)) return;
    if (!context.mounted) return;

    switch (ask) {
      case HomeAsk.consent:
        await showConsentAskSheet(
          context: context,
          repository: getIt<InAppNoticeRepository>(),
          onShare: _share,
        );
      case HomeAsk.review:
        await _askForReview();
        // The popup moved the review ask time, so a planned review
        // reminder must be dropped.
        unawaited(getIt<LocalReminderPlanTrigger>().run());
      case HomeAsk.none:
        break;
    }
  } finally {
    _isAsking = false;
  }
}

/// Checked again after the wait, right before a sheet opens: a guide or an
/// alarm may have started in the meantime, another screen may be on top, or
/// home may be a tab the user is not looking at.
Future<bool> _stillFree(BuildContext context) async {
  if (ModalRoute.of(context)?.isCurrent == false) return false;
  if (!TickerMode.valuesOf(context).enabled) return false;
  if (getIt<AlarmFocus>().on) return false;
  return getIt<SetupGate>().isDone();
}

/// The Reminders sheet for an install that tested before this update, or a
/// Pro sheet a night ack left for the daytime. Checked before the consent
/// sheet and the review popup.
Future<LocalReminderHomeAsk> _nextLocalReminderAsk() async {
  final store = getIt<LocalReminderStore>();
  final notices = getIt<InAppNoticeRepository>();
  // A delivered review or feedback reminder counts as an ask before any ask
  // time is read below.
  await getIt<LocalReminderSettler>().settleAsks(now: DateTime.now());
  final isOwed = store.readProSheetOwed();
  final proShouldAsk = isOwed && await getIt<ProAskRules>().shouldAsk();
  if (isOwed && !proShouldAsk) await store.writeProSheetOwed(owed: false);
  return LocalReminderHomeAskRules.decide(
    isSetupDone: await getIt<SetupGate>().isDone(),
    now: DateTime.now(),
    isWeb: kIsWeb,
    isRinging: false,
    isSheetShown: store.readSheetShown(),
    hasCriticalTopic: getIt<TopicsCubit>().state.topics.any((t) => t.critical),
    lastAcknowledgedAt: notices.getLastAcknowledgedAt(),
    isProSheetOwed: isOwed,
    proShouldAsk: proShouldAsk,
    otherAskedAt: [
      notices.getProAskedAt(),
      notices.getConsentAskedAt(),
      notices.getReviewAskedAt(),
      notices.getFeedbackAskedAt(),
    ],
  );
}

Future<void> _showLocalReminderAsk(
  BuildContext context,
  LocalReminderHomeAsk ask,
) async {
  final store = getIt<LocalReminderStore>();
  switch (ask) {
    case LocalReminderHomeAsk.localRemindersSheet:
      await askLocalRemindersSheet(context);
    case LocalReminderHomeAsk.proSheet:
      await store.writeProSheetOwed(owed: false);
      if (!context.mounted) return;
      await askProSheet(context);
    case LocalReminderHomeAsk.none:
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
  await getIt<InAppNoticeRepository>().markReviewAsked();
  await review.requestReview();
}
