// Spelling out a default in a fixture keeps the case readable.
// ignore_for_file: avoid_redundant_argument_values

import 'package:critalarm/core/models/incident.dart';
import 'package:critalarm/features/incidents/domain/setup_test_kind.dart';
import 'package:critalarm/features/topics/domain/home_card/handled_window.dart';
import 'package:critalarm/features/topics/domain/home_card/home_card_input.dart';
import 'package:flutter_test/flutter_test.dart';

import 'home_card_fixtures.dart';

void main() {
  group('RingingFact.fromIncident', () {
    test('reads an open incident', () {
      final opened = now.subtract(const Duration(minutes: 1));
      final fact = RingingFact.fromIncident(incident(openedAt: opened));
      expect(
        fact,
        RingingFact(incidentId: 'i1', topic: 'prod-db', openedAt: opened),
      );
    });

    test('ignores an incident that is not open', () {
      expect(
        RingingFact.fromIncident(incident(state: IncidentStates.acked)),
        isNull,
      );
    });
  });

  group('AcknowledgedFact.fromIncident', () {
    final ackedAt = now.subtract(const Duration(minutes: 1));

    test('takes the deadline the server sent', () {
      final fires = now.add(const Duration(minutes: 4));
      final fact = AcknowledgedFact.fromIncident(
        incident(
          state: IncidentStates.acked,
          ackedAt: ackedAt,
          deskTimerFiresAt: fires,
        ),
        deskTimerS: 900,
      );
      expect(fact?.deadline, fires);
    });

    test('falls back to the ack time plus the desk timer', () {
      final fact = AcknowledgedFact.fromIncident(
        incident(state: IncidentStates.acked, ackedAt: ackedAt),
        deskTimerS: 300,
      );
      expect(fact?.deadline, ackedAt.add(const Duration(seconds: 300)));
    });

    test('falls back to ten minutes when the desk timer is not known', () {
      final fact = AcknowledgedFact.fromIncident(
        incident(state: IncidentStates.acked, ackedAt: ackedAt),
      );
      expect(fact?.deadline, ackedAt.add(const Duration(minutes: 10)));
    });

    test('has no deadline to give without either time', () {
      expect(
        AcknowledgedFact.fromIncident(incident(state: IncidentStates.acked)),
        isNull,
      );
    });

    test('ignores an incident that is not acknowledged', () {
      expect(
        AcknowledgedFact.fromIncident(
          incident(ackedAt: ackedAt, deskTimerFiresAt: now),
        ),
        isNull,
      );
    });
  });

  group('HandledFact.fromIncident', () {
    final closedAt = now.subtract(const Duration(seconds: 10));

    Incident closed({DateTime? openedAt, DateTime? ackedAt, DateTime? at}) =>
        incident(
          state: IncidentStates.closed,
          openedAt: openedAt,
          ackedAt: ackedAt,
          closedAt: at ?? closedAt,
        );

    test('measures the time to the first acknowledgement', () {
      final opened = closedAt.subtract(const Duration(minutes: 5));
      final fact = HandledFact.fromIncident(
        closed(
          openedAt: opened,
          ackedAt: opened.add(const Duration(seconds: 11)),
        ),
        now: now,
      );
      expect(fact?.answeredAfter, const Duration(seconds: 11));
      expect(fact?.closedAt, closedAt);
    });

    test(
      'has no time to answer when it was closed without an acknowledgement',
      () {
        final fact = HandledFact.fromIncident(
          closed(openedAt: closedAt.subtract(const Duration(minutes: 5))),
          now: now,
        );
        expect(fact, isNotNull);
        expect(fact?.answeredAfter, isNull);
      },
    );

    test('has no time to answer when the start is missing', () {
      final fact = HandledFact.fromIncident(
        closed(ackedAt: closedAt.subtract(const Duration(seconds: 3))),
        now: now,
      );
      expect(fact?.answeredAfter, isNull);
    });

    test('has no time to answer when the times run backwards', () {
      final opened = closedAt.subtract(const Duration(minutes: 1));
      final fact = HandledFact.fromIncident(
        closed(
          openedAt: opened,
          ackedAt: opened.subtract(const Duration(seconds: 5)),
        ),
        now: now,
      );
      expect(fact?.answeredAfter, isNull);
    });

    test('is gone once the window has passed', () {
      expect(
        HandledFact.fromIncident(
          closed(at: now.subtract(handledCardWindow)),
          now: now,
        ),
        isNull,
      );
      expect(
        HandledFact.fromIncident(
          closed(
            at: now.subtract(handledCardWindow - const Duration(seconds: 1)),
          ),
          now: now,
        ),
        isNotNull,
      );
    });

    test('never reports an alarm that ran out', () {
      expect(
        HandledFact.fromIncident(
          incident(state: IncidentStates.expired, closedAt: closedAt),
          now: now,
        ),
        isNull,
      );
    });

    test('needs a close time', () {
      expect(
        HandledFact.fromIncident(
          incident(state: IncidentStates.closed),
          now: now,
        ),
        isNull,
      );
    });
  });

  group('lastRealAlarmAt', () {
    test('is the newest start', () {
      final older = DateTime(2026, 10, 1);
      final newer = DateTime(2026, 10, 5);
      expect(
        lastRealAlarmAt([
          incident(id: 'a', openedAt: older),
          incident(id: 'b', openedAt: newer),
        ], setupIncidentIds: const {}),
        newer,
      );
    });

    test('skips a setup test and the phone-only test', () {
      final real = DateTime(2026, 10, 1);
      expect(
        lastRealAlarmAt(
          [
            incident(id: 'real', openedAt: real),
            incident(id: 'setup', openedAt: DateTime(2026, 10, 8)),
            incident(
              id: phoneOnlyTestIncidentId,
              openedAt: DateTime(2026, 10, 9),
            ),
          ],
          setupIncidentIds: const {'setup'},
        ),
        real,
      );
    });

    test('is null with nothing that counts', () {
      expect(
        lastRealAlarmAt([incident(id: 'x')], setupIncidentIds: const {}),
        isNull,
      );
      expect(lastRealAlarmAt(const [], setupIncidentIds: const {}), isNull);
    });
  });

  group('HomeCardInput', () {
    test('equal fields are equal', () {
      expect(Draft().build(), Draft().build());
      expect(Draft().build().hashCode, Draft().build().hashCode);
    });

    test('a different field is different', () {
      final other = Draft()..warningCount = 1;
      expect(Draft().build(), isNot(other.build()));
    });
  });
}
