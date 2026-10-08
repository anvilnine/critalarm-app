import 'dart:async';

import 'package:critalarm/core/models/incident.dart';
import 'package:critalarm/features/in_app_notices/domain/missed_alarm_notice_rule.dart';
import 'package:critalarm/features/reliability/domain/missed_alarm/missed_alarm_reader.dart';
import 'package:critalarm/features/reliability/domain/missed_alarm/missed_alarm_rule.dart';
import 'package:critalarm/features/topics/data/reader_missed_alarm_feed.dart';
import 'package:flutter_test/flutter_test.dart';

import '../domain/home_card/home_card_fixtures.dart'
    show incident, message, now;

MissedAlarm _missed(
  String id, {
  String topic = 'prod-db',
  Duration endedAgo = const Duration(hours: 2),
  MissedReason reason = MissedReason.rangUnanswered,
}) => MissedAlarm(
  incidentId: id,
  topic: topic,
  at: now.subtract(endedAgo),
  reason: reason,
);

Incident _expired(String id, {DateTime? openedAt, DateTime? closedAt}) =>
    incident(
      id: id,
      state: IncidentStates.expired,
      openedAt: openedAt,
      closedAt: closedAt,
      messages: [message(priority: 5)],
    );

class _Rig {
  _Rig({
    this.missed = const [],
    this.incidents = const [],
    this.setupDone = true,
    this.failRead = false,
  });

  List<MissedAlarm>? missed;
  List<Incident> incidents;
  bool setupDone;
  bool failRead;
  final Set<String> dismissed = {};
  final StreamController<void> incidentChanges = StreamController.broadcast();

  late final ReaderMissedAlarmFeed feed = ReaderMissedAlarmFeed(
    readMissed: () async {
      if (failRead) throw StateError('disk');
      return missed;
    },
    readDismissed: () => dismissed,
    writeDismissed: (ids) async => dismissed.addAll(ids),
    readIncidents: () => incidents,
    isSetupDone: () async => setupDone,
    incidentChanges: incidentChanges.stream,
    clock: () => now,
  );
}

void main() {
  test('reads the newest missed alarm and how long it rang', () async {
    final opened = now.subtract(const Duration(hours: 2, minutes: 10));
    final rig = _Rig(
      missed: [
        _missed('a', endedAgo: const Duration(days: 1)),
        _missed('b'),
      ],
      incidents: [
        _expired('a'),
        _expired(
          'b',
          openedAt: opened,
          closedAt: opened.add(const Duration(minutes: 10)),
        ),
      ],
    );
    final fact = await rig.feed.read();
    expect(fact?.notice.incidentIds, ['b', 'a']);
    expect(fact?.notice.count, 2);
    expect(fact?.notice.topic, 'prod-db');
    expect(fact?.ringDuration, const Duration(minutes: 10));
  });

  test('is the notice the notice rule makes from the same inputs', () async {
    final rig = _Rig(
      missed: [
        _missed('a'),
        _missed('b', topic: 'backups'),
      ],
    );
    final fact = await rig.feed.read();
    expect(
      fact?.notice,
      MissedAlarmNoticeRule.noticeFor(
        isSetupDone: true,
        missed: rig.missed,
        dismissedIds: rig.dismissed,
        now: now,
      ),
    );
  });

  group('the ring duration', () {
    test('is null when the incident is not in the list', () async {
      final rig = _Rig(missed: [_missed('a')]);
      expect((await rig.feed.read())?.ringDuration, isNull);
    });

    test('is null when the incident has no opening time', () async {
      final rig = _Rig(
        missed: [_missed('a')],
        incidents: [_expired('a', closedAt: now)],
      );
      expect((await rig.feed.read())?.ringDuration, isNull);
    });

    test('is null when the times run backwards', () async {
      final rig = _Rig(
        missed: [_missed('a')],
        incidents: [
          _expired(
            'a',
            openedAt: now,
            closedAt: now.subtract(const Duration(minutes: 1)),
          ),
        ],
      );
      expect((await rig.feed.read())?.ringDuration, isNull);
    });
  });

  group('nothing to say', () {
    test('before setup is done', () async {
      final rig = _Rig(missed: [_missed('a')], setupDone: false);
      expect(await rig.feed.read(), isNull);
    });

    test('with no missed alarm', () async {
      expect(await _Rig().feed.read(), isNull);
    });

    test('when the read has no answer', () async {
      expect(await _Rig(missed: null).feed.read(), isNull);
    });

    test('when the read throws', () async {
      final rig = _Rig(missed: [_missed('a')], failRead: true);
      expect(await rig.feed.read(), isNull);
    });

    test('for an alarm that ran out more than a week ago', () async {
      final rig = _Rig(
        missed: [_missed('a', endedAgo: const Duration(days: 8))],
      );
      expect(await rig.feed.read(), isNull);
    });
  });

  group('dismiss', () {
    test('writes the ids to the record the notice reads', () async {
      final rig = _Rig(missed: [_missed('a'), _missed('b')]);
      await rig.feed.dismiss(['a', 'b']);
      expect(rig.dismissed, {'a', 'b'});
    });

    test('takes the entry off the card and off the notice', () async {
      final rig = _Rig(missed: [_missed('a')]);
      expect(await rig.feed.read(), isNotNull);
      await rig.feed.dismiss(['a']);
      expect(await rig.feed.read(), isNull);
      expect(
        MissedAlarmNoticeRule.noticeFor(
          isSetupDone: true,
          missed: rig.missed,
          dismissedIds: rig.dismissed,
          now: now,
        ),
        isNull,
      );
    });

    test('an entry closed elsewhere is gone from the card too', () async {
      final rig = _Rig(missed: [_missed('a')]);
      // The notice cubit and the Reliability screen write the same record.
      rig.dismissed.add('a');
      expect(await rig.feed.read(), isNull);
    });

    test('only the closed alarms go; a later one still shows', () async {
      final rig = _Rig(missed: [_missed('a')]);
      await rig.feed.dismiss(['a']);
      rig.missed = [_missed('a'), _missed('c', endedAgo: Duration.zero)];
      final fact = await rig.feed.read();
      expect(fact?.notice.incidentIds, ['c']);
    });
  });

  group('changes', () {
    test('fire when an incident change comes in', () async {
      final rig = _Rig();
      var fired = 0;
      final sub = rig.feed.changes.listen((_) => fired++);
      rig.incidentChanges.add(null);
      await pumpEventQueue();
      expect(fired, 1);
      await sub.cancel();
    });

    test('fire after a dismiss, once the record is written', () async {
      final rig = _Rig(missed: [_missed('a')]);
      Set<String>? seenWhenFired;
      final sub = rig.feed.changes.listen(
        (_) => seenWhenFired = {...rig.dismissed},
      );
      await rig.feed.dismiss(['a']);
      await pumpEventQueue();
      expect(seenWhenFired, {'a'});
      await sub.cancel();
    });

    test('can be listened to by several views', () async {
      final rig = _Rig();
      var first = 0;
      var second = 0;
      final a = rig.feed.changes.listen((_) => first++);
      final b = rig.feed.changes.listen((_) => second++);
      rig.incidentChanges.add(null);
      await pumpEventQueue();
      expect([first, second], [1, 1]);
      await a.cancel();
      await b.cancel();
    });
  });
}
