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
}
