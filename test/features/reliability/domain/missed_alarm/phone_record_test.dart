import 'package:critalarm/features/reliability/domain/missed_alarm/missed_alarm_rule.dart';
import 'package:critalarm/features/reliability/domain/missed_alarm/phone_record.dart';
import 'package:flutter_test/flutter_test.dart';

import 'missed_alarm_fixtures.dart';

int ms(DateTime at) => at.toUtc().millisecondsSinceEpoch;

Map<String, Object?> received(DateTime at, {String kind = 'open'}) => {
  'name': 'push_received',
  'at_ms': ms(at),
  'kind': kind,
  'priority': '5',
};

Map<String, Object?> fired(DateTime at, String id) => {
  'name': 'alarm_fired',
  'at_ms': ms(at),
  'incident_id': id,
};

void main() {
  final watchingSince = opened.subtract(const Duration(days: 1));
  final morning = expired.add(const Duration(hours: 4));

  /// A record that started a day before the incident and was read the
  /// morning after, with [rows] seen at that read.
  PhoneRecord recordWith(
    List<Object?> rows, {
    Set<String> rangIds = const {},
    Set<String> acked = const {},
    int? lostBeforeMs,
  }) => const PhoneRecord()
      .merged(const PhoneCapture(), now: watchingSince)
      .merged(
        PhoneCapture(
          eventRows: rows,
          rangIds: rangIds,
          acknowledgedHereIds: acked,
          lostBeforeMs: lostBeforeMs,
        ),
        now: morning,
      );

  group('what the record says about an incident', () {
    test('an alarm_fired row for it means it rang', () {
      final record = recordWith([
        received(opened.add(const Duration(seconds: 2))),
        fired(opened.add(const Duration(seconds: 2)), 'inc_1'),
      ]);
      expect(
        record.knowledgeFor(incidentFixture(), everyPushIsLogged: true),
        const PhoneKnowledge(rang: true, pushReached: true),
      );
    });

    test('an id the platform reported means it rang', () {
      final record = recordWith(const [], rangIds: {'inc_1'});
      expect(
        record.knowledgeFor(incidentFixture(), everyPushIsLogged: false).rang,
        isTrue,
      );
    });

    test('another incident ringing says nothing about this one', () {
      final record = recordWith([
        fired(opened.add(const Duration(seconds: 2)), 'inc_other'),
      ]);
      final knowledge = record.knowledgeFor(
        incidentFixture(),
        everyPushIsLogged: true,
      );
      expect(knowledge.rang, isFalse);
      expect(knowledge.pushReached, isFalse);
    });

    test('a full record with nothing in the window means no push', () {
      final record = recordWith([
        // A push the day before, and a state push in the window.
        received(opened.subtract(const Duration(hours: 5))),
        received(opened.add(const Duration(minutes: 31)), kind: 'expire'),
      ]);
      expect(
        record.knowledgeFor(incidentFixture(), everyPushIsLogged: true),
        const PhoneKnowledge(silenceMeansNoPush: true),
      );
    });

    test('a phone that does not log every push never claims silence', () {
      final record = recordWith(const []);
      expect(
        record.knowledgeFor(incidentFixture(), everyPushIsLogged: false),
        PhoneKnowledge.none,
      );
    });

    test('a ring push in the window that names no incident is not silence', () {
      final record = recordWith([
        received(opened.add(const Duration(minutes: 3))),
      ]);
      expect(
        record.knowledgeFor(incidentFixture(), everyPushIsLogged: true),
        PhoneKnowledge.none,
      );
    });

    test('a push dropped unread in the window is not silence', () {
      final record = recordWith([
        {
          'name': 'push_dropped',
          'at_ms': ms(opened.add(const Duration(minutes: 3))),
          'reason': 'other_server',
        },
      ]);
      expect(
        record
            .knowledgeFor(incidentFixture(), everyPushIsLogged: true)
            .silenceMeansNoPush,
        isFalse,
      );
    });

    test('a repeat dropped as already acknowledged does not break it', () {
      final record = recordWith([
        {
          'name': 'push_dropped',
          'at_ms': ms(opened.add(const Duration(minutes: 3))),
          'reason': 'already_acked',
        },
      ]);
      expect(
        record
            .knowledgeFor(incidentFixture(), everyPushIsLogged: true)
            .silenceMeansNoPush,
        isTrue,
      );
    });

    test('a record that started after the incident opened is not silence', () {
      final record = const PhoneRecord()
          .merged(
            const PhoneCapture(),
            now: opened.add(const Duration(minutes: 10)),
          )
          .merged(const PhoneCapture(), now: morning);
      expect(
        record.knowledgeFor(incidentFixture(), everyPushIsLogged: true),
        PhoneKnowledge.none,
      );
    });

    test('a record last read before it ran out is not silence', () {
      final record = const PhoneRecord()
          .merged(const PhoneCapture(), now: watchingSince)
          .merged(
            const PhoneCapture(),
            now: opened.add(const Duration(minutes: 10)),
          );
      expect(
        record.knowledgeFor(incidentFixture(), everyPushIsLogged: true),
        PhoneKnowledge.none,
      );
    });

    test('a native list that was full moves the start of the record', () {
      final record = recordWith(
        const [],
        lostBeforeMs: ms(opened.add(const Duration(minutes: 20))),
      );
      expect(
        record.knowledgeFor(incidentFixture(), everyPushIsLogged: true),
        PhoneKnowledge.none,
      );
    });

    test('a ring that a setting can hold only proves the push', () {
      final record = recordWith([
        fired(opened.add(const Duration(seconds: 2)), 'inc_1'),
      ]);
      expect(
        record.knowledgeFor(
          incidentFixture(),
          everyPushIsLogged: true,
          ringsCanBeHeld: true,
        ),
        const PhoneKnowledge(pushReached: true),
      );
    });

    test('an acknowledgement on this phone is kept', () {
      final record = recordWith(const [], acked: {'inc_1'});
      expect(
        record
            .knowledgeFor(incidentFixture(), everyPushIsLogged: true)
            .acknowledgedHere,
        isTrue,
      );
    });

    test('an incident with no end time is not silence', () {
      final record = recordWith(const []);
      expect(
        record.knowledgeFor(
          incidentFixture(state: 'open'),
          everyPushIsLogged: true,
        ),
        PhoneKnowledge.none,
      );
    });
  });

  group('keeping the record', () {
    test('the same rows seen twice are held once', () {
      final rows = [received(opened), received(opened)];
      final record = recordWith(rows).merged(
        PhoneCapture(eventRows: rows),
        now: morning.add(const Duration(minutes: 1)),
      );
      expect(record.rows, hasLength(1));
    });

    test('the first time an alarm is seen is the one kept', () {
      final first = recordWith([fired(opened, 'inc_1')]);
      final again = first.merged(
        PhoneCapture(
          eventRows: [fired(opened.add(const Duration(minutes: 9)), 'inc_1')],
          rangIds: const {'inc_1'},
        ),
        now: morning.add(const Duration(minutes: 1)),
      );
      expect(again.rangAtMs['inc_1'], ms(opened));
    });

    test('anything older than eight days is dropped', () {
      final record =
          recordWith(
            [received(opened), fired(opened, 'inc_1')],
            acked: {'inc_2'},
          ).merged(
            const PhoneCapture(),
            now: opened.add(const Duration(days: 8, hours: 1)),
          );
      expect(record.rows, isEmpty);
      expect(record.rangAtMs, isEmpty);
      // Stamped at the morning read, so it is a few hours younger.
      expect(record.acknowledgedHereAtMs.keys, ['inc_2']);
    });

    test('rows of another shape are skipped', () {
      final record = recordWith([
        'not a row',
        {'name': 'push_received'},
        {'name': 'debug_action', 'at_ms': ms(opened)},
        {'name': 'alarm_fired', 'at_ms': ms(opened)},
        null,
      ]);
      expect(record.rows, isEmpty);
      expect(record.rangAtMs, isEmpty);
    });

    test('more rows than the cap drops the oldest and moves the start', () {
      final rows = [
        for (var i = 0; i < PhoneRecord.maxRows + 5; i++)
          received(opened.add(Duration(seconds: i))),
      ];
      final record = recordWith(rows);
      expect(record.rows, hasLength(PhoneRecord.maxRows));
      expect(record.completeSinceMs, record.rows.first.atMs);
    });

    test('it reads back what it wrote', () {
      final record = recordWith(
        [
          received(opened),
          fired(opened, 'inc_1'),
          {'name': 'push_dropped', 'at_ms': ms(opened), 'reason': 'x'},
        ],
        acked: {'inc_2'},
      );
      final back = PhoneRecord.fromJson(record.toJson());
      expect(back.rows, record.rows);
      expect(back.rangAtMs, record.rangAtMs);
      expect(back.acknowledgedHereAtMs, record.acknowledgedHereAtMs);
      expect(back.completeSinceMs, record.completeSinceMs);
      expect(back.lastCaptureMs, record.lastCaptureMs);
    });

    test('a damaged value reads as a record that knows nothing', () {
      expect(PhoneRecord.fromJson('nope').rows, isEmpty);
      expect(
        PhoneRecord.fromJson(const {'rang': 4, 'rows': 'x'}).rangAtMs,
        isEmpty,
      );
    });
  });
}
