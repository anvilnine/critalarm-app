import 'package:critalarm/features/local_reminders/domain/rules/morning_after_rule.dart';

/// The one follow-up an acknowledged alarm may get.
enum AfterAck {
  /// The Reminders sheet, once, after the first test alarm.
  localRemindersSheet,

  /// The Pro sheet, now.
  proSheet,

  /// Nothing now; a plan pass plans idea 10 for 09:00.
  planMorningAfter,

  /// Nothing now; the Pro sheet waits for the next daytime home open.
  proSheetLater,

  nothing,
}

/// Picks at most one follow-up per ack, in place of the direct Pro sheet
/// call `critical_alarm_screen.dart` used to make.
///
/// It never shows the review popup or the consent sheet. Those stay with
/// `HomeAskRules` on the next home open, which already waits 24 hours after
/// the Pro sheet.
///
/// Nothing follows an ack before onboarding is finished and the first
/// Feature Guide has been seen or skipped (`isSetupDone`). The demo alarm at
/// the end of onboarding is acked with both still open.
abstract final class AfterAckDecider {
  static AfterAck decide({
    required bool isSetupDone,
    required DateTime ackedAt,
    required bool isTestAck,
    required bool isLocalRemindersSheetShown,
    required bool isWeb,
    required bool offersOn,
    required bool proShouldAsk,
    bool hasOtherOpenIncident = false,
    bool alreadyShownToday = false,
  }) {
    if (!isSetupDone) return AfterAck.nothing;
    // While another incident is still open, or a sheet already showed today,
    // no sheet pops up over the alarm. Planning and owing still run, because
    // neither puts anything on screen.
    final sheetBlocked = hasOtherOpenIncident || alreadyShownToday;
    if (isTestAck && !isLocalRemindersSheetShown && !isWeb) {
      return sheetBlocked ? AfterAck.nothing : AfterAck.localRemindersSheet;
    }
    if (MorningAfterRule.isNight(ackedAt)) {
      if (!proShouldAsk) return AfterAck.nothing;
      if (offersOn && !isTestAck) return AfterAck.planMorningAfter;
      return AfterAck.proSheetLater;
    }
    return proShouldAsk && !sheetBlocked ? AfterAck.proSheet : AfterAck.nothing;
  }
}
