import 'package:critalarm/features/incidents/domain/setup_test_kind.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('setupTestKind', () {
    test(
      'the incident the server opened for the setup test is server-sent',
      () {
        expect(
          setupTestKind(
            incidentId: 'inc_9',
            topic: 'prod-db',
            storedRealRingIncidentId: 'inc_9',
          ),
          SetupTestKind.serverSent,
        );
      },
    );

    test('a cold start knows the test by the stored incident id alone', () {
      // The alarm started the app, so nothing is in memory: no topic yet, and
      // only the id written when the server answered.
      expect(
        setupTestKind(
          incidentId: 'inc_9',
          topic: '',
          storedRealRingIncidentId: 'inc_9',
        ),
        SetupTestKind.serverSent,
      );
    });

    test('the alarm the phone set for itself is phone-only', () {
      expect(
        setupTestKind(
          incidentId: 'inc_demo',
          topic: 'demo-topic',
          storedRealRingIncidentId: null,
        ),
        SetupTestKind.phoneOnly,
      );
      expect(
        setupTestKind(
          incidentId: null,
          topic: 'demo-topic',
          storedRealRingIncidentId: null,
        ),
        SetupTestKind.phoneOnly,
      );
    });

    test('the phone-only alarm stays phone-only after a server test', () {
      expect(
        setupTestKind(
          incidentId: 'inc_demo',
          topic: 'demo-topic',
          storedRealRingIncidentId: 'inc_9',
        ),
        SetupTestKind.phoneOnly,
      );
    });

    test('any other incident is not a setup test', () {
      expect(
        setupTestKind(
          incidentId: 'inc_4',
          topic: 'prod-db',
          storedRealRingIncidentId: 'inc_9',
        ),
        SetupTestKind.none,
      );
      expect(
        setupTestKind(
          incidentId: 'inc_4',
          topic: 'prod-db',
          storedRealRingIncidentId: null,
        ),
        SetupTestKind.none,
      );
    });

    test('no incident and nothing stored is not a setup test', () {
      expect(
        setupTestKind(
          incidentId: null,
          topic: 'prod-db',
          storedRealRingIncidentId: null,
        ),
        SetupTestKind.none,
      );
      // An empty stored id never matches an empty incident id.
      expect(
        setupTestKind(
          incidentId: '',
          topic: 'prod-db',
          storedRealRingIncidentId: '',
        ),
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
