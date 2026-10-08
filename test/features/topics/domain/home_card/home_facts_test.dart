import 'package:critalarm/core/models/incident.dart';
import 'package:critalarm/core/models/topic.dart';
import 'package:critalarm/features/topics/domain/home_card/handled_window.dart';
import 'package:critalarm/features/topics/domain/home_card/home_card_input.dart';
import 'package:critalarm/features/topics/domain/home_card/home_facts.dart';
import 'package:flutter_test/flutter_test.dart';

import 'home_card_fixtures.dart';

const _topics = [Topic(name: 'prod-db'), Topic(name: 'backups')];

int _seconds(DateTime at) => at.millisecondsSinceEpoch ~/ 1000;

HomeFacts _facts({
  List<Topic> topics = _topics,
  List<Incident> incidents = const [],
  Set<String> warningTopics = const {},
  Map<String, List<int>> messageTimes = const {},
}) => homeFactsFrom(
  topics: topics,
  incidents: incidents,
  warningTopics: warningTopics,
  messageTimes: messageTimes,
  now: now,
);

void main() {
  group('a quiet phone', () {
    test('no incidents and no messages is no facts', () {
      expect(_facts(), HomeFacts.none);
    });

    test('the newest message over all topics', () {
      final newest = now.subtract(const Duration(hours: 3));
      final facts = _facts(
        messageTimes: {
          'prod-db': [
            _seconds(now.subtract(const Duration(days: 2))),
            _seconds(newest),
          ],
          'backups': [_seconds(now.subtract(const Duration(days: 9)))],
        },
      );
      expect(facts.newestMessageAt, newest);
    });

    test('a topic with no messages adds nothing', () {
      final facts = _facts(messageTimes: {'prod-db': [], 'backups': []});
      expect(facts.newestMessageAt, isNull);
    });

    test('the last alarm is the newest start, closed or not', () {
      final facts = _facts(
        incidents: [
          incident(
            id: 'old',
            state: IncidentStates.closed,
            openedAt: now.subtract(const Duration(days: 20)),
            closedAt: now.subtract(const Duration(days: 20)),
          ),
          incident(
            id: 'newer',
            state: IncidentStates.closed,
            openedAt: now.subtract(const Duration(days: 3)),
            closedAt: now.subtract(const Duration(days: 3)),
          ),
        ],
      );
      expect(facts.lastAlarmAt, now.subtract(const Duration(days: 3)));
    });

    test('a test setup sent is still the last alarm', () {
      final facts = _facts(
        incidents: [
          incident(
            id: 'real',
            state: IncidentStates.closed,
            openedAt: now.subtract(const Duration(days: 5)),
            closedAt: now.subtract(const Duration(days: 5)),
          ),
          incident(
            id: 'setup-test',
            state: IncidentStates.closed,
            openedAt: now.subtract(const Duration(days: 1)),
            closedAt: now.subtract(const Duration(days: 1)),
          ),
        ],
      );
      expect(facts.lastAlarmAt, now.subtract(const Duration(days: 1)));
    });

    test('two answered alarms yesterday are the last alarm', () {
      final facts = _facts(
        incidents: [
          incident(
            id: 'first',
            state: IncidentStates.closed,
            openedAt: now.subtract(const Duration(hours: 24, minutes: 1)),
            closedAt: now.subtract(const Duration(hours: 23)),
          ),
          incident(
            id: 'second',
            state: IncidentStates.closed,
            openedAt: now.subtract(const Duration(hours: 24)),
            closedAt: now.subtract(const Duration(hours: 23)),
          ),
        ],
      );
      expect(facts.lastAlarmAt, now.subtract(const Duration(hours: 24)));
    });

    test('no incident leaves the last alarm null', () {
      expect(_facts().lastAlarmAt, isNull);
      expect(
        _facts(incidents: [incident(id: 'no-start')]).lastAlarmAt,
        isNull,
      );
    });
  });

  group('warnings', () {
    test('count the topics with a live warning', () {
      expect(_facts(warningTopics: {'prod-db', 'backups'}).warningCount, 2);
      expect(_facts().warningCount, 0);
    });
  });

  group('ringing', () {
    final opened = now.subtract(const Duration(minutes: 2, seconds: 17));

    test('is an open incident with a priority 5 message', () {
      final facts = _facts(
        incidents: [
          incident(openedAt: opened, messages: [message(priority: 5)]),
        ],
      );
      expect(
        facts.ringing,
        RingingFact(incidentId: 'i1', topic: 'prod-db', openedAt: opened),
      );
    });

    test('is not an open incident that never reached priority 5', () {
      final facts = _facts(
        incidents: [
          incident(openedAt: opened, messages: [message(priority: 4)]),
        ],
      );
      expect(facts.ringing, isNull);
    });

    test('is not an incident that was acknowledged', () {
      final facts = _facts(
        incidents: [
          incident(
            state: IncidentStates.acked,
            openedAt: opened,
            ackedAt: now,
            messages: [message(priority: 5)],
          ),
        ],
      );
      expect(facts.ringing, isNull);
    });

    test('takes the one that opened last when several ring', () {
      final facts = _facts(
        incidents: [
          incident(
            id: 'first',
            openedAt: now.subtract(const Duration(minutes: 10)),
            messages: [message(priority: 5)],
          ),
          incident(
            id: 'second',
            topic: 'backups',
            openedAt: now.subtract(const Duration(minutes: 1)),
            messages: [message(priority: 5)],
          ),
          incident(
            id: 'third',
            openedAt: now.subtract(const Duration(minutes: 5)),
            messages: [message(priority: 5)],
          ),
        ],
      );
      expect(facts.ringing?.incidentId, 'second');
    });

    test('one with an opening time beats one without', () {
      final facts = _facts(
        incidents: [
          incident(id: 'no-time', messages: [message(priority: 5)]),
          incident(
            id: 'timed',
            openedAt: opened,
            messages: [message(priority: 5)],
          ),
        ],
      );
      expect(facts.ringing?.incidentId, 'timed');
    });
  });

  group('acknowledged', () {
    final ackedAt = now.subtract(const Duration(minutes: 1));

    test('uses the deadline the server sent', () {
      final fires = now.add(const Duration(minutes: 9));
      final facts = _facts(
        incidents: [
          incident(
            state: IncidentStates.acked,
            ackedAt: ackedAt,
            deskTimerFiresAt: fires,
          ),
        ],
      );
      expect(
        facts.acknowledged,
        AcknowledgedFact(
          incidentId: 'i1',
          topic: 'prod-db',
          deadline: fires,
        ),
      );
    });

    test("falls back to the ack time plus the topic's desk timer", () {
      final facts = _facts(
        topics: const [Topic(name: 'prod-db', deskTimerS: 300)],
        incidents: [incident(state: IncidentStates.acked, ackedAt: ackedAt)],
      );
      expect(
        facts.acknowledged?.deadline,
        ackedAt.add(const Duration(seconds: 300)),
      );
    });

    test('is not an acknowledgement whose deadline passed', () {
      final facts = _facts(
        incidents: [
          incident(
            state: IncidentStates.acked,
            ackedAt: now.subtract(const Duration(minutes: 30)),
            deskTimerFiresAt: now.subtract(const Duration(minutes: 20)),
          ),
        ],
      );
      expect(facts.acknowledged, isNull);
    });

    test('takes the newest acknowledgement when several count', () {
      final facts = _facts(
        incidents: [
          incident(
            id: 'older',
            state: IncidentStates.acked,
            ackedAt: now.subtract(const Duration(minutes: 4)),
          ),
          incident(
            id: 'newer',
            topic: 'backups',
            state: IncidentStates.acked,
            ackedAt: now.subtract(const Duration(minutes: 1)),
          ),
        ],
      );
      expect(facts.acknowledged?.incidentId, 'newer');
    });
  });

  group('handled', () {
    test('has how long the first answer took', () {
      final opened = now.subtract(const Duration(seconds: 16));
      final facts = _facts(
        incidents: [
          incident(
            state: IncidentStates.closed,
            openedAt: opened,
            ackedAt: opened.add(const Duration(seconds: 11)),
            closedAt: now.subtract(const Duration(seconds: 5)),
          ),
        ],
      );
      expect(
        facts.handled,
        HandledFact(
          topic: 'prod-db',
          closedAt: now.subtract(const Duration(seconds: 5)),
          answeredAfter: const Duration(seconds: 11),
        ),
      );
    });

    test('has no answer time for a close with no acknowledgement', () {
      final facts = _facts(
        incidents: [
          incident(
            state: IncidentStates.closed,
            openedAt: now.subtract(const Duration(minutes: 1)),
            closedAt: now.subtract(const Duration(seconds: 5)),
          ),
        ],
      );
      expect(facts.handled, isNotNull);
      expect(facts.handled?.answeredAfter, isNull);
    });

    test('ends with the window', () {
      final facts = _facts(
        incidents: [
          incident(
            state: IncidentStates.closed,
            openedAt: now.subtract(const Duration(minutes: 1)),
            closedAt: now.subtract(handledCardWindow),
          ),
        ],
      );
      expect(facts.handled, isNull);
    });

    test('is never an alarm that ran out', () {
      final facts = _facts(
        incidents: [
          incident(
            state: IncidentStates.expired,
            openedAt: now.subtract(const Duration(minutes: 20)),
            closedAt: now.subtract(const Duration(seconds: 5)),
          ),
        ],
      );
      expect(facts.handled, isNull);
    });

    test('takes the newest close', () {
      final facts = _facts(
        incidents: [
          incident(
            id: 'older',
            state: IncidentStates.closed,
            closedAt: now.subtract(const Duration(seconds: 20)),
          ),
          incident(
            id: 'newer',
            topic: 'backups',
            state: IncidentStates.closed,
            closedAt: now.subtract(const Duration(seconds: 3)),
          ),
        ],
      );
      expect(facts.handled?.topic, 'backups');
    });
  });

  group('withoutLive', () {
    test('keeps the times and drops what is live now', () {
      final facts = _facts(
        incidents: [
          incident(
            openedAt: now.subtract(const Duration(minutes: 1)),
            messages: [message(priority: 5)],
          ),
        ],
        warningTopics: {'backups'},
        messageTimes: {
          'prod-db': [_seconds(now.subtract(const Duration(hours: 1)))],
        },
      ).withoutLive();
      expect(facts.ringing, isNull);
      expect(facts.acknowledged, isNull);
      expect(facts.handled, isNull);
      expect(facts.warningCount, 0);
      expect(facts.lastAlarmAt, now.subtract(const Duration(minutes: 1)));
      expect(facts.newestMessageAt, now.subtract(const Duration(hours: 1)));
    });
  });

  test('equal facts are equal', () {
    final a = _facts(warningTopics: {'backups'});
    final b = _facts(warningTopics: {'prod-db'});
    expect(a, b);
    expect(a.hashCode, b.hashCode);
    expect(a, isNot(_facts(warningTopics: {'prod-db', 'backups'})));
  });
}
