import 'package:critalarm/features/in_app_notices/domain/home_ask_rules.dart';
import 'package:critalarm/features/incidents/domain/real_use.dart';
import 'package:critalarm/features/incidents/domain/setup_test_kind.dart';
import 'package:critalarm/features/local_reminders/domain/after_ack_decider.dart';
import 'package:critalarm/features/local_reminders/domain/local_reminder_home_ask_rules.dart';
import 'package:critalarm/features/onboarding/data/repositories/prefs_setup_test_ring.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const setupIds = {'inc_test', 'inc_first_message'};

  bool real(String? id) =>
      countsAsRealUse(incidentId: id, setupIncidentIds: setupIds);

  group('countsAsRealUse', () {
    test('a test setup asked the server for is not real use', () {
      expect(real('inc_test'), isFalse);
    });

    test('the alarm of the first hook-up message is not real use', () {
      expect(real('inc_first_message'), isFalse);
    });

    test('the test of this phone only is not real use', () {
      expect(real(phoneOnlyTestIncidentId), isFalse);
    });

    test('no incident at all is not real use', () {
      expect(real(null), isFalse);
      expect(real(''), isFalse);
    });

    test('any other alarm is real use', () {
      expect(real('inc_prod_down'), isTrue);
    });

    test('with nothing on record every server alarm is real use', () {
      expect(
        countsAsRealUse(incidentId: 'inc_test', setupIncidentIds: const {}),
        isTrue,
      );
    });
  });

  group('the ids outlive setup', () {
    test('a test and the first message are both kept after clear', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final ring = PrefsSetupTestRing(prefs);

      await ring.hold('inc_test');
      await ring.holdFirstMessage('inc_first_message');
      // Setup completes.
      await ring.clear();

      expect(ring.incidentIds, isEmpty);
      expect(ring.setupIncidentIds, {'inc_test', 'inc_first_message'});
      // The first message is not a test: it never joins the test set.
      await ring.holdFirstMessage('inc_another');
      expect(ring.incidentIds, isEmpty);
    });

    test('the list is capped, newest kept', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final ring = PrefsSetupTestRing(prefs);

      for (var i = 0; i < 30; i++) {
        await ring.hold('inc_$i');
      }

      expect(ring.setupIncidentIds, hasLength(20));
      expect(ring.setupIncidentIds, contains('inc_29'));
      expect(ring.setupIncidentIds, isNot(contains('inc_0')));
    });
  });

  group('the rules that wait for real use', () {
    final ackedAt = DateTime(2026, 10, 4, 14);
    final now = DateTime(2026, 10, 12, 14);

    /// The newest ack the asks may count, given which incidents are acked.
    DateTime? newest(List<String> ackedIds) => newestRealAckedAt(
      acks: [for (final id in ackedIds) (id: id, ackedAt: ackedAt)],
      setupIncidentIds: setupIds,
    );

    test('only setup alarms acknowledged: there is no ack to count', () {
      expect(newest(['inc_test', 'inc_first_message']), isNull);
      expect(newest([phoneOnlyTestIncidentId]), isNull);
    });

    test('a real alarm acknowledged is counted', () {
      expect(newest(['inc_test', 'inc_prod_down']), ackedAt);
    });

    LocalReminderHomeAsk remindersAsk(DateTime? lastAck) =>
        LocalReminderHomeAskRules.decide(
          isSetupDone: true,
          now: now,
          isWeb: false,
          isRinging: false,
          isSheetShown: false,
          hasCriticalTopic: true,
          lastAcknowledgedAt: lastAck,
          isProSheetOwed: false,
          proShouldAsk: true,
        );

    test('the Local reminders sheet on Home waits for a real ack', () {
      expect(
        remindersAsk(newest(['inc_test', 'inc_first_message'])),
        LocalReminderHomeAsk.none,
      );
      expect(
        remindersAsk(newest(['inc_prod_down'])),
        LocalReminderHomeAsk.localRemindersSheet,
      );
    });

    HomeAsk homeAsk(DateTime? lastAck) => HomeAskRules.decide(
      isSetupDone: true,
      now: now,
      firstSeenAt: DateTime(2026, 9),
      // Answered, so only the review ask is in play.
      consentAskedAt: DateTime(2026, 9, 2),
      isConsentGiven: true,
      reviewAskedAt: null,
      reviewAskCount: 0,
      lastAcknowledgedAt: lastAck,
      proAskedAt: null,
      isRinging: false,
      isWeb: false,
    );

    test('the rating ask waits for a real ack', () {
      expect(homeAsk(newest(['inc_test', 'inc_first_message'])), HomeAsk.none);
      expect(homeAsk(newest(['inc_prod_down'])), HomeAsk.review);
    });

    test('the consent ask does not read acks at all', () {
      final ask = HomeAskRules.decide(
        isSetupDone: true,
        now: now,
        firstSeenAt: DateTime(2026, 9),
        consentAskedAt: null,
        isConsentGiven: false,
        reviewAskedAt: null,
        reviewAskCount: 0,
        lastAcknowledgedAt: newest(['inc_test']),
        proAskedAt: null,
        isRinging: false,
        isWeb: false,
      );
      expect(ask, HomeAsk.consent);
    });

    /// What the alarm screen does after an acknowledge: nothing at all for
    /// an alarm that is not real use, the decider for one that is.
    AfterAck afterAck(String incidentId) {
      if (!real(incidentId)) return AfterAck.nothing;
      return AfterAckDecider.decide(
        isSetupDone: true,
        ackedAt: ackedAt,
        isTestAck: false,
        isLocalRemindersSheetShown: true,
        isWeb: false,
        offersOn: false,
        proShouldAsk: true,
      );
    }

    test('the Hosted sheet after an ack waits for a real alarm', () {
      expect(afterAck('inc_test'), AfterAck.nothing);
      expect(afterAck('inc_first_message'), AfterAck.nothing);
      expect(afterAck(phoneOnlyTestIncidentId), AfterAck.nothing);
      expect(afterAck('inc_prod_down'), AfterAck.proSheet);
    });
  });

  group('countsAsFirstRealAck', () {
    bool first(String? id, {bool isTest = false}) => countsAsFirstRealAck(
      incidentId: id,
      isTest: isTest,
      setupIncidentIds: setupIds,
    );

    test('a setup ring does not set the first real acknowledge', () {
      expect(first('inc_test'), isFalse);
      expect(first('inc_first_message'), isFalse);
      expect(first(phoneOnlyTestIncidentId), isFalse);
    });

    test('a Settings test alarm does not set it', () {
      expect(first('inc_settings_test', isTest: true), isFalse);
    });

    test('an unknown incident does not set it', () {
      expect(first(null, isTest: true), isFalse);
      expect(first(null), isFalse);
    });

    test('a real alarm sets it', () {
      expect(first('inc_prod_down'), isTrue);
    });
  });
}
