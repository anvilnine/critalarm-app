import 'package:critalarm/features/incidents/domain/setup_test_kind.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('setupTestKind', () {
    test(
      'the incident the server opened for the setup test is server-sent',
      () {
        expect(
          setupTestKind(incidentId: 'inc_9', setupTestIncidentIds: {'inc_9'}),
          SetupTestKind.serverSent,
        );
      },
    );

    test('a cold start knows the test by the stored incident id alone', () {
      // The alarm started the app, so nothing is in memory: only the id
      // written when the server answered.
      expect(
        setupTestKind(incidentId: 'inc_9', setupTestIncidentIds: {'inc_9'}),
        SetupTestKind.serverSent,
      );
    });

    test('every test of the run counts, an earlier try included', () {
      for (final id in ['inc_8', 'inc_9']) {
        expect(
          setupTestKind(
            incidentId: id,
            setupTestIncidentIds: {'inc_8', 'inc_9'},
          ),
          SetupTestKind.serverSent,
        );
      }
    });

    test('the alarm the phone set for itself is phone-only', () {
      expect(
        setupTestKind(incidentId: 'inc_demo', setupTestIncidentIds: {}),
        SetupTestKind.phoneOnly,
      );
      expect(
        setupTestKind(incidentId: 'inc_demo', setupTestIncidentIds: {'inc_9'}),
        SetupTestKind.phoneOnly,
      );
    });

    test('a real alarm is never a test because of its topic name', () {
      // A user may name a topic anything, `demo-topic` included. The topic
      // is not even asked for.
      expect(
        setupTestKind(incidentId: 'inc_4', setupTestIncidentIds: {}),
        SetupTestKind.none,
      );
    });

    test('any other incident is not a setup test', () {
      expect(
        setupTestKind(incidentId: 'inc_4', setupTestIncidentIds: {'inc_9'}),
        SetupTestKind.none,
      );
    });

    test('no incident and nothing stored is not a setup test', () {
      expect(
        setupTestKind(incidentId: null, setupTestIncidentIds: {}),
        SetupTestKind.none,
      );
      // An empty id never matches, whatever is stored.
      expect(
        setupTestKind(incidentId: '', setupTestIncidentIds: {''}),
        SetupTestKind.none,
      );
    });
  });

  group('ackedExitsFor', () {
    test('a real incident keeps the usual exits', () {
      expect(
        ackedExitsFor(
          kind: SetupTestKind.none,
          isOnboardingDone: false,
          flowHasRealRing: true,
          hasOwnedTopic: true,
        ),
        AckedExits.incident,
      );
    });

    test('a setup run on a flow with the real ring continues', () {
      for (final kind in [SetupTestKind.serverSent, SetupTestKind.phoneOnly]) {
        expect(
          ackedExitsFor(
            kind: kind,
            isOnboardingDone: false,
            flowHasRealRing: true,
            hasOwnedTopic: true,
          ),
          AckedExits.continueSetup,
        );
      }
    });

    test('the first shipped order keeps both of its exits', () {
      expect(
        ackedExitsFor(
          kind: SetupTestKind.phoneOnly,
          isOnboardingDone: false,
          flowHasRealRing: false,
          hasOwnedTopic: false,
        ),
        AckedExits.legacyCreateTopicOrFinish,
      );
      expect(
        ackedExitsFor(
          kind: SetupTestKind.phoneOnly,
          isOnboardingDone: false,
          flowHasRealRing: false,
          hasOwnedTopic: true,
        ),
        AckedExits.legacyFinish,
      );
    });

    test('a test run again after setup only closes', () {
      // From Settings, Health, or a replay: setup is already complete.
      for (final hasRealRing in [true, false]) {
        expect(
          ackedExitsFor(
            kind: SetupTestKind.phoneOnly,
            isOnboardingDone: true,
            flowHasRealRing: hasRealRing,
            hasOwnedTopic: true,
          ),
          AckedExits.retest,
        );
      }
    });

    test('only the exits of the first shipped order complete setup', () {
      expect(AckedExits.continueSetup.completesSetup, isFalse);
      expect(AckedExits.retest.completesSetup, isFalse);
      expect(AckedExits.incident.completesSetup, isFalse);
      expect(AckedExits.legacyCreateTopicOrFinish.completesSetup, isTrue);
      expect(AckedExits.legacyFinish.completesSetup, isTrue);
    });
  });

  group('setupProofFor', () {
    test('a server-sent test proves the server, the push and the phone', () {
      expect(setupProofFor(SetupTestKind.serverSent), const [
        (point: ProofPoint.serverSent, isProved: true),
        (point: ProofPoint.pushArrived, isProved: true),
        (point: ProofPoint.phoneRang, isProved: true),
      ]);
    });

    test('a phone-only test proves the phone and nothing else', () {
      final proof = setupProofFor(SetupTestKind.phoneOnly);

      expect(proof.first, (point: ProofPoint.phoneRang, isProved: true));
      expect(proof.where((line) => line.isProved), hasLength(1));
      expect(
        {
          for (final line in proof)
            if (!line.isProved) line.point,
        },
        {ProofPoint.serverSent, ProofPoint.pushArrived},
      );
    });

    test('an alarm that is not a test proves nothing here', () {
      expect(setupProofFor(SetupTestKind.none), isEmpty);
    });
  });

  group('which acknowledged screen', () {
    AckedExits exits({
      required SetupTestKind kind,
      required bool isOnboardingDone,
      bool flowHasRealRing = true,
      bool isFirstToolAlarm = false,
    }) => ackedExitsFor(
      kind: kind,
      isOnboardingDone: isOnboardingDone,
      flowHasRealRing: flowHasRealRing,
      hasOwnedTopic: true,
      isFirstToolAlarm: isFirstToolAlarm,
    );

    test('a setup test during setup continues setup', () {
      for (final kind in [SetupTestKind.serverSent, SetupTestKind.phoneOnly]) {
        expect(
          exits(kind: kind, isOnboardingDone: false),
          AckedExits.continueSetup,
        );
      }
    });

    test('the first tool alarm of a setup run gets the setup screen', () {
      // Setup is complete by then: the hook-up step finished it before it
      // handed over to the alarm.
      expect(
        exits(
          kind: SetupTestKind.none,
          isOnboardingDone: true,
          isFirstToolAlarm: true,
        ),
        AckedExits.firstToolAlarm,
      );
      // And if the step had not been finished yet, still that screen.
      expect(
        exits(
          kind: SetupTestKind.none,
          isOnboardingDone: false,
          isFirstToolAlarm: true,
        ),
        AckedExits.firstToolAlarm,
      );
    });

    test('a real alarm during setup from another topic is a real alarm', () {
      expect(
        exits(kind: SetupTestKind.none, isOnboardingDone: false),
        AckedExits.incident,
      );
    });

    test('an alarm after setup is a real alarm', () {
      expect(
        exits(kind: SetupTestKind.none, isOnboardingDone: true),
        AckedExits.incident,
      );
      // A server-sent test met after setup is one to answer too.
      expect(
        exits(kind: SetupTestKind.serverSent, isOnboardingDone: true),
        AckedExits.incident,
      );
    });

    test('with setup skipped, no alarm gets the setup screen', () {
      // Set this up later completes setup and the hook-up step never
      // records an alarm, so nothing is ever the first tool alarm.
      expect(
        exits(kind: SetupTestKind.none, isOnboardingDone: true),
        AckedExits.incident,
      );
    });

    test('a setup test is never taken for the first tool alarm', () {
      expect(
        exits(
          kind: SetupTestKind.serverSent,
          isOnboardingDone: false,
          isFirstToolAlarm: true,
        ),
        AckedExits.continueSetup,
      );
    });

    test('only the real alarm and the first tool alarm are not tests', () {
      for (final value in AckedExits.values) {
        expect(
          value.isSetupTest,
          value != AckedExits.incident && value != AckedExits.firstToolAlarm,
        );
      }
      expect(AckedExits.firstToolAlarm.completesSetup, isFalse);
    });

    test('the first tool alarm proves the whole chain', () {
      expect(firstToolAlarmProof.every((line) => line.isProved), isTrue);
      expect(firstToolAlarmProof.first.point, ProofPoint.toolSent);
      expect(firstToolAlarmProof.last.point, ProofPoint.phoneRang);
    });
  });
}
