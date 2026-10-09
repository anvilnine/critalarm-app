import 'package:critalarm/core/models/incident.dart';
import 'package:critalarm/core/models/message.dart';
import 'package:critalarm/core/models/weekly_check.dart';
import 'package:critalarm/features/local_reminders/domain/incident_kinds.dart';
import 'package:critalarm/features/reliability/domain/proof/proof_entry.dart';
import 'package:critalarm/features/reliability/domain/proof/proof_sources.dart';
import 'package:critalarm/features/reliability/domain/proof/proof_weeks.dart';
import 'package:flutter_test/flutter_test.dart';

int _seconds(DateTime at) => at.millisecondsSinceEpoch ~/ 1000;

void main() {
  group('proofIsServerTest', () {
    Message message(String title) =>
        Message(id: 'm', topic: 'prod-db', title: title);

    test('the server test counts', () {
      expect(
        proofIsServerTest(
          Incident(
            id: 'inc_1',
            topic: 'prod-db',
            messages: [message(IncidentKinds.testAlarmTitle)],
          ),
        ),
        isTrue,
      );
    });

    test('the onboarding demo does not', () {
      expect(
        proofIsServerTest(
          Incident(
            id: IncidentKinds.demoIncidentId,
            topic: IncidentKinds.demoTopic,
            messages: [message(IncidentKinds.testAlarmTitle)],
          ),
        ),
        isFalse,
      );
      expect(
        proofIsServerTest(
          Incident(
            id: IncidentKinds.demoIncidentId,
            topic: 'prod-db',
            messages: [message('anything')],
          ),
        ),
        isFalse,
      );
    });

    test('a real incident does not', () {
      expect(
        proofIsServerTest(
          Incident(
            id: 'inc_2',
            topic: 'prod-db',
            messages: [message('Database is down')],
          ),
        ),
        isFalse,
      );
      expect(
        proofIsServerTest(const Incident(id: 'inc_3', topic: 'prod-db')),
        isFalse,
      );
    });
  });

  group('proofEntriesFromWeeklyCheck', () {
    // 2026-10-07 is a Wednesday, week of 2026-10-05.
    final received = DateTime(2026, 10, 7, 9);
    final earlier = DateTime(2026, 9, 30, 9); // week of 2026-09-28

    test('a new lastReceivedAt marks rang for the week of that second', () {
      final entries = proofEntriesFromWeeklyCheck(
        WeeklyCheck(
          enabled: true,
          state: WeeklyCheckState.received,
          lastReceivedAt: _seconds(received),
        ),
      );
      expect(entries, hasLength(1));
      expect(entries.single.key, '2026-10-05');
      expect(entries.single.rangAt, received);
      expect(entries.single.failedAt, isNull);
    });

    test('misses with no receipt mark failed for the week of lastSentAt', () {
      final entries = proofEntriesFromWeeklyCheck(
        WeeklyCheck(
          enabled: true,
          state: WeeklyCheckState.missedOnce,
          misses: 1,
          lastSentAt: _seconds(earlier),
        ),
      );
      expect(entries, hasLength(1));
      expect(entries.single.key, '2026-09-28');
      expect(entries.single.failedAt, earlier);
      expect(entries.single.rangAt, isNull);
    });

    test('misses in a week that has rang stays rang', () {
      final entries = proofEntriesFromWeeklyCheck(
        WeeklyCheck(
          enabled: true,
          state: WeeklyCheckState.missedOnce,
          misses: 1,
          lastSentAt: _seconds(DateTime(2026, 10, 8, 9)),
          lastReceivedAt: _seconds(received),
        ),
      );
      var log = <ProofEntry>[];
      for (final entry in entries) {
        log = proofMerge(log, entry);
      }
      expect(log, hasLength(1));
      expect(
        proofWeeksFor(log, DateTime(2026, 10, 9)).last.mark,
        ProofMark.rang,
      );
    });

    test('no misses and no receipt adds nothing', () {
      expect(
        proofEntriesFromWeeklyCheck(
          const WeeklyCheck(enabled: true, state: WeeklyCheckState.waiting),
        ),
        isEmpty,
      );
      expect(
        proofEntriesFromWeeklyCheck(
          WeeklyCheck(
            enabled: true,
            state: WeeklyCheckState.received,
            lastSentAt: _seconds(received),
          ),
        ),
        isEmpty,
      );
    });

    test('misses with no lastSentAt adds nothing', () {
      expect(
        proofEntriesFromWeeklyCheck(
          const WeeklyCheck(
            enabled: true,
            state: WeeklyCheckState.missedOnce,
            misses: 2,
          ),
        ),
        isEmpty,
      );
    });
  });
}
