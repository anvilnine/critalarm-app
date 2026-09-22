import 'package:critalarm/features/reminders/domain/after_ack_decider.dart';
import 'package:critalarm/features/reminders/domain/home_reminder_ask_rules.dart';
import 'package:critalarm/features/reminders/domain/reminder_switches.dart';
import 'package:critalarm/features/reminders/domain/reminders_sheet_choice.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AfterAckDecider', () {
    AfterAck decide({
      DateTime? ackedAt,
      bool isTestAck = false,
      bool isRemindersSheetShown = true,
      bool isWeb = false,
      bool offersOn = false,
      bool proShouldAsk = true,
    }) => AfterAckDecider.decide(
      ackedAt: ackedAt ?? DateTime(2026, 9, 22, 14),
      isTestAck: isTestAck,
      isRemindersSheetShown: isRemindersSheetShown,
      isWeb: isWeb,
      offersOn: offersOn,
      proShouldAsk: proShouldAsk,
    );

    test('the first test ack shows the Reminders sheet', () {
      expect(
        decide(isTestAck: true, isRemindersSheetShown: false),
        AfterAck.remindersSheet,
      );
    });

    test('the Reminders sheet shows once', () {
      expect(decide(isTestAck: true), AfterAck.proSheet);
    });

    test('never on web', () {
      expect(
        decide(isTestAck: true, isRemindersSheetShown: false, isWeb: true),
        AfterAck.proSheet,
      );
    });

    test('a night ack with Offers on plans the morning after', () {
      expect(
        decide(ackedAt: DateTime(2026, 9, 23, 3), offersOn: true),
        AfterAck.planMorningAfter,
      );
    });

    test('a night ack with Offers off owes the Pro sheet to the daytime', () {
      expect(
        decide(ackedAt: DateTime(2026, 9, 23, 3)),
        AfterAck.proSheetLater,
      );
    });

    test('a night test ack never plans the morning after', () {
      expect(
        decide(
          ackedAt: DateTime(2026, 9, 23, 3),
          offersOn: true,
          isTestAck: true,
        ),
        AfterAck.proSheetLater,
      );
    });

    test('a night ack when Pro should not ask does nothing', () {
      expect(
        decide(ackedAt: DateTime(2026, 9, 23, 3), proShouldAsk: false),
        AfterAck.nothing,
      );
    });

    test('a daytime ack asks about Pro only when the rules say so', () {
      expect(decide(), AfterAck.proSheet);
      expect(decide(proShouldAsk: false), AfterAck.nothing);
    });
  });

  group('HomeReminderAskRules', () {
    HomeReminderAsk decide({
      DateTime? now,
      bool isWeb = false,
      bool isRinging = false,
      bool isSheetShown = false,
      bool hasCriticalTopic = true,
      DateTime? lastAcknowledgedAt,
      bool isProSheetOwed = false,
      bool proShouldAsk = false,
      List<DateTime?> otherAskedAt = const [],
    }) => HomeReminderAskRules.decide(
      now: now ?? DateTime(2026, 9, 22, 14),
      isWeb: isWeb,
      isRinging: isRinging,
      isSheetShown: isSheetShown,
      hasCriticalTopic: hasCriticalTopic,
      lastAcknowledgedAt: lastAcknowledgedAt,
      isProSheetOwed: isProSheetOwed,
      proShouldAsk: proShouldAsk,
      otherAskedAt: otherAskedAt,
    );

    test('an existing install that already tested sees the sheet once', () {
      expect(
        decide(lastAcknowledgedAt: DateTime(2026, 9)),
        HomeReminderAsk.remindersSheet,
      );
      expect(
        decide(lastAcknowledgedAt: DateTime(2026, 9), isSheetShown: true),
        HomeReminderAsk.none,
      );
    });

    test('no sheet without a critical topic or an ack', () {
      expect(decide(), HomeReminderAsk.none);
      expect(
        decide(lastAcknowledgedAt: DateTime(2026, 9), hasCriticalTopic: false),
        HomeReminderAsk.none,
      );
    });

    test('an owed Pro sheet shows in the daytime only', () {
      expect(
        decide(isSheetShown: true, isProSheetOwed: true, proShouldAsk: true),
        HomeReminderAsk.proSheet,
      );
      expect(
        decide(
          now: DateTime(2026, 9, 23, 5),
          isSheetShown: true,
          isProSheetOwed: true,
          proShouldAsk: true,
        ),
        HomeReminderAsk.none,
      );
    });

    test('waits out the 24 hour gap, a ring and web', () {
      expect(
        decide(
          lastAcknowledgedAt: DateTime(2026, 9),
          otherAskedAt: [DateTime(2026, 9, 22, 9)],
        ),
        HomeReminderAsk.none,
      );
      expect(
        decide(lastAcknowledgedAt: DateTime(2026, 9), isRinging: true),
        HomeReminderAsk.none,
      );
      expect(
        decide(lastAcknowledgedAt: DateTime(2026, 9), isWeb: true),
        HomeReminderAsk.none,
      );
    });
  });

  group('RemindersSheetChoice', () {
    test('Turn on keeps Offers to the checkbox', () {
      expect(
        RemindersSheetChoice.turnOn(offersTicked: true, isSelfHosted: false),
        const ReminderSwitches(reminders: true, offers: true),
      );
      expect(
        RemindersSheetChoice.turnOn(offersTicked: false, isSelfHosted: false),
        ReminderSwitches.defaults,
      );
    });

    test('self-hosted never turns Offers on', () {
      expect(
        RemindersSheetChoice.turnOn(offersTicked: true, isSelfHosted: true),
        ReminderSwitches.defaults,
      );
    });

    test('No thanks turns both off', () {
      expect(RemindersSheetChoice.noThanks, ReminderSwitches.allOff);
    });
  });
}
