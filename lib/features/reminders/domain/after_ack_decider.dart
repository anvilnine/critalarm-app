import 'package:critalarm/features/reminders/domain/rules/morning_after_rule.dart';

/// The one follow-up an acknowledged alarm may get.
enum AfterAck {
  /// The Reminders sheet, once, after the first test alarm.
  remindersSheet,

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
abstract final class AfterAckDecider {
  static AfterAck decide({
    required DateTime ackedAt,
    required bool isTestAck,
    required bool isRemindersSheetShown,
    required bool isWeb,
    required bool offersOn,
    required bool proShouldAsk,
  }) {
    if (isTestAck && !isRemindersSheetShown && !isWeb) {
      return AfterAck.remindersSheet;
    }
    if (MorningAfterRule.isNight(ackedAt)) {
      if (!proShouldAsk) return AfterAck.nothing;
      if (offersOn && !isTestAck) return AfterAck.planMorningAfter;
      return AfterAck.proSheetLater;
    }
    return proShouldAsk ? AfterAck.proSheet : AfterAck.nothing;
  }
}
