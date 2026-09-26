import 'package:critalarm/features/local_reminders/domain/after_ack_decider.dart';
import 'package:critalarm/features/local_reminders/domain/local_reminder_home_ask_rules.dart';
import 'package:critalarm/features/local_reminders/domain/local_reminder_switches.dart';
import 'package:critalarm/features/local_reminders/domain/local_reminders_sheet_choice.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AfterAckDecider', () {
    AfterAck decide({
      DateTime? ackedAt,
      bool isTestAck = false,
      bool isLocalRemindersSheetShown = true,
      bool isWeb = false,
      bool offersOn = false,
      bool proShouldAsk = true,
      bool isSetupDone = true,
      bool hasOtherOpenIncident = false,
      bool alreadyShownToday = false,
    }) => AfterAckDecider.decide(
      ackedAt: ackedAt ?? DateTime(2026, 9, 22, 14),
      isTestAck: isTestAck,
      isLocalRemindersSheetShown: isLocalRemindersSheetShown,
      isWeb: isWeb,
      offersOn: offersOn,
      proShouldAsk: proShouldAsk,
      isSetupDone: isSetupDone,
      hasOtherOpenIncident: hasOtherOpenIncident,
      alreadyShownToday: alreadyShownToday,
    );

    test('the first test ack shows the Reminders sheet', () {
      expect(
        decide(isTestAck: true, isLocalRemindersSheetShown: false),
        AfterAck.localRemindersSheet,
      );
    });

    test('nothing before onboarding and the first Feature Guide are done', () {
      expect(
        decide(
          isTestAck: true,
          isLocalRemindersSheetShown: false,
          isSetupDone: false,
        ),
        AfterAck.nothing,
      );
    });

    test('the Reminders sheet shows once', () {
      expect(decide(isTestAck: true), AfterAck.proSheet);
    });

    test('never on web', () {
      expect(
        decide(isTestAck: true, isLocalRemindersSheetShown: false, isWeb: true),
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

    test('no sheet while another incident is still open', () {
      expect(decide(hasOtherOpenIncident: true), AfterAck.nothing);
      expect(
        decide(
          isTestAck: true,
          isLocalRemindersSheetShown: false,
          hasOtherOpenIncident: true,
        ),
        AfterAck.nothing,
      );
    });

    test('no sheet on the second ack of the same day', () {
      expect(decide(alreadyShownToday: true), AfterAck.nothing);
      expect(
        decide(
          isTestAck: true,
          isLocalRemindersSheetShown: false,
          alreadyShownToday: true,
        ),
        AfterAck.nothing,
      );
    });

    test('planning the morning after runs even with a sheet blocked', () {
      // Nothing about it goes on screen, so an alarm it would cover does
      // not stop it.
      expect(
        decide(
          ackedAt: DateTime(2026, 9, 23, 3),
          offersOn: true,
          hasOtherOpenIncident: true,
        ),
        AfterAck.planMorningAfter,
      );
    });
  });

  group('LocalReminderHomeAskRules', () {
    LocalReminderHomeAsk decide({
      DateTime? now,
      bool isWeb = false,
      bool isRinging = false,
      bool isSheetShown = false,
      bool hasCriticalTopic = true,
      DateTime? lastAcknowledgedAt,
      bool isProSheetOwed = false,
      bool proShouldAsk = false,
      List<DateTime?> otherAskedAt = const [],
      bool isSetupDone = true,
    }) => LocalReminderHomeAskRules.decide(
      now: now ?? DateTime(2026, 9, 22, 14),
      isWeb: isWeb,
      isRinging: isRinging,
      isSheetShown: isSheetShown,
      hasCriticalTopic: hasCriticalTopic,
      lastAcknowledgedAt: lastAcknowledgedAt,
      isProSheetOwed: isProSheetOwed,
      proShouldAsk: proShouldAsk,
      otherAskedAt: otherAskedAt,
      isSetupDone: isSetupDone,
    );

    test('an existing install that already tested sees the sheet once', () {
      expect(
        decide(lastAcknowledgedAt: DateTime(2026, 9)),
        LocalReminderHomeAsk.localRemindersSheet,
      );
      expect(
        decide(lastAcknowledgedAt: DateTime(2026, 9), isSheetShown: true),
        LocalReminderHomeAsk.none,
      );
    });

    test('nothing before onboarding and the first Feature Guide are done', () {
      expect(
        decide(lastAcknowledgedAt: DateTime(2026, 9), isSetupDone: false),
        LocalReminderHomeAsk.none,
      );
    });

    test('no sheet without a critical topic or an ack', () {
      expect(decide(), LocalReminderHomeAsk.none);
      expect(
        decide(lastAcknowledgedAt: DateTime(2026, 9), hasCriticalTopic: false),
        LocalReminderHomeAsk.none,
      );
    });

    test('an owed Pro sheet shows in the daytime only', () {
      expect(
        decide(isSheetShown: true, isProSheetOwed: true, proShouldAsk: true),
        LocalReminderHomeAsk.proSheet,
      );
      expect(
        decide(
          now: DateTime(2026, 9, 23, 5),
          isSheetShown: true,
          isProSheetOwed: true,
          proShouldAsk: true,
        ),
        LocalReminderHomeAsk.none,
      );
    });

    test('waits out the 24 hour gap, a ring and web', () {
      expect(
        decide(
          lastAcknowledgedAt: DateTime(2026, 9),
          otherAskedAt: [DateTime(2026, 9, 22, 9)],
        ),
        LocalReminderHomeAsk.none,
      );
      expect(
        decide(lastAcknowledgedAt: DateTime(2026, 9), isRinging: true),
        LocalReminderHomeAsk.none,
      );
      expect(
        decide(lastAcknowledgedAt: DateTime(2026, 9), isWeb: true),
        LocalReminderHomeAsk.none,
      );
    });
  });

  group('LocalRemindersSheetChoice', () {
    test('Turn on keeps Offers to the checkbox', () {
      expect(
        LocalRemindersSheetChoice.turnOn(
          offersTicked: true,
          isSelfHosted: false,
        ),
        const LocalReminderSwitches(reminders: true, offers: true),
      );
      expect(
        LocalRemindersSheetChoice.turnOn(
          offersTicked: false,
          isSelfHosted: false,
        ),
        LocalReminderSwitches.defaults,
      );
    });

    test('self-hosted never turns Offers on', () {
      expect(
        LocalRemindersSheetChoice.turnOn(
          offersTicked: true,
          isSelfHosted: true,
        ),
        LocalReminderSwitches.defaults,
      );
    });

    test('a paid user never gets Offers, even with the box ticked', () {
      expect(
        LocalRemindersSheetChoice.turnOn(
          offersTicked: true,
          isSelfHosted: false,
          isPaid: true,
        ),
        LocalReminderSwitches.defaults,
      );
    });

    test('No thanks turns both off', () {
      expect(LocalRemindersSheetChoice.noThanks, LocalReminderSwitches.allOff);
    });
  });
}
