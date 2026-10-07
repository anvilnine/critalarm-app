import 'package:critalarm/core/models/incident.dart';
import 'package:critalarm/features/reliability/domain/missed_alarm/missed_alarm_reader.dart';
import 'package:critalarm/features/reliability/domain/missed_alarm/missed_alarm_rule.dart';
import 'package:critalarm/features/reliability/domain/missed_alarm/missed_alarm_store.dart';
import 'package:critalarm/features/reliability/domain/missed_alarm/phone_record.dart';
import 'package:flutter_test/flutter_test.dart';

import 'missed_alarm_fixtures.dart';

void main() {
  const serverUrl = 'https://alerts.example.com';

  late MemoryMissedAlarmStore store;
  late DateTime now;
  late List<Incident> incidents;
  late Set<String>? topics;
  late PhoneCapture capture;
  late bool setupDone;
  late String? server;
  late DateTime? firstLaunchAt;
  late Set<String> setupTests;
  late int captures;

  MissedAlarmReader build({bool everyPushIsLogged = true}) => MissedAlarmReader(
    store: store,
    readIncidents: () => incidents,
    readTopicNames: () async => topics,
    capture: () async {
      captures++;
      return capture;
    },
    isSetupDone: () async => setupDone,
    readServer: () async => server,
    firstLaunchAt: () => firstLaunchAt,
    setupIncidentIds: () => setupTests,
    everyPushIsLogged: everyPushIsLogged,
    now: () => now,
  );

  /// A phone set up, connected and holding `prod` for a week, keeping its
  /// record since the day before the incident.
  MemoryMissedAlarmStore stampedStore() => MemoryMissedAlarmStore()
    ..setupDoneAt = cutoffsLongAgo.setupDoneAt
    ..connected = ConnectedServer(
      server: serverUrl,
      since: cutoffsLongAgo.connectedSince!,
    )
    ..topicsHeldSince = {'prod': cutoffsLongAgo.topicHeldSince!}
    ..record = const PhoneRecord().merged(
      const PhoneCapture(),
      now: opened.subtract(const Duration(days: 1)),
    );

  setUp(() {
    store = stampedStore();
    now = expired.add(const Duration(hours: 4));
    incidents = [incidentFixture()];
    topics = {'prod'};
    capture = const PhoneCapture();
    setupDone = true;
    server = serverUrl;
    firstLaunchAt = cutoffsLongAgo.firstLaunchAt;
    setupTests = {};
    captures = 0;
  });

  test('an expired incident nobody acknowledged is missed', () async {
    final missed = await build().read();
    expect(missed, [
      MissedAlarm(
        incidentId: 'inc_1',
        topic: 'prod',
        at: expired,
        reason: MissedReason.noPushReached,
      ),
    ]);
  });

  test('an iPhone, which does not log every push, names no cause', () async {
    final missed = await build(everyPushIsLogged: false).read();
    expect(missed.single.reason, MissedReason.unanswered);
  });

  group('arrival is not a ring', () {
    test(
      'a push that arrived, or an alarm that was set, names no cause',
      () async {
        capture = const PhoneCapture(arrivedIds: {'inc_1'});
        expect((await build().read()).single.reason, MissedReason.unanswered);
      },
    );

    test('an alarm_fired row alone names no cause', () async {
      capture = PhoneCapture(
        eventRows: [
          {
            'name': 'alarm_fired',
            'at_ms': opened.millisecondsSinceEpoch + 2000,
            'incident_id': 'inc_1',
          },
        ],
      );
      expect((await build().read()).single.reason, MissedReason.unanswered);
    });

    test('an alarm the phone saw sounding is "it rang"', () async {
      capture = const PhoneCapture(startedIds: {'inc_1'});
      expect(
        (await build().read()).single.reason,
        MissedReason.rangUnanswered,
      );
    });

    test(
      'with no stored hold decision it claims neither held nor rang',
      () async {
        // The reader takes no quiet hours setting at all. Whatever the
        // setting says today, an arrival stays an arrival.
        capture = const PhoneCapture(arrivedIds: {'inc_1'});
        final reason = (await build().read()).single.reason;
        expect(reason, isNot(MissedReason.rangUnanswered));
        expect(reason, isNot(MissedReason.pushButNoRing));
      },
    );
  });

  test('an acknowledgement waiting on this phone is not missed', () async {
    capture = const PhoneCapture(acknowledgedHereIds: {'inc_1'});
    expect(await build().read(), isEmpty);
  });

  test('acknowledged on another device is not missed', () async {
    incidents = [
      incidentFixture(ackedAt: opened.add(const Duration(minutes: 3))),
      incidentFixture(id: 'inc_2', state: IncidentStates.closed),
    ];
    expect(await build().read(), isEmpty);
  });

  test('open and acknowledged incidents are not missed', () async {
    incidents = [
      incidentFixture(state: IncidentStates.open),
      incidentFixture(id: 'inc_2', state: IncidentStates.acked),
    ];
    expect(await build().read(), isEmpty);
  });

  test('a setup test is not missed', () async {
    setupTests = {'inc_1'};
    expect(await build().read(), isEmpty);
  });

  group('the critical switch as it is today is not asked', () {
    test('a miss stays a miss after Critical is turned off', () async {
      final reader = build();
      expect(await reader.read(), hasLength(1));
      // The user turns Critical off on the topic. The topic is still held,
      // and nothing the reader reads says what the switch is.
      expect(await reader.read(), hasLength(1));
      expect(await reader.readToShow(), hasLength(1));
    });

    test('a miss stays a miss after the topic is deleted', () async {
      final reader = build();
      expect(await reader.read(), hasLength(1));
      topics = {};
      // The stretch the phone held it in is kept, with an end.
      expect(await reader.read(), hasLength(1));
      expect(store.topicHolds['prod']!.single.until, now);
    });
  });

  group('a topic this phone did not hold yet', () {
    test('an incident that opened before the phone held the topic is not '
        'classified', () async {
      store.topicsHeldSince = {};
      topics = {'prod'};
      // This read is the first time the phone is seen holding it.
      expect(await build().read(), isEmpty);
      expect(store.topicsHeldSince, {'prod': now});
    });

    test('an incident on another held topic still counts', () async {
      incidents = [
        incidentFixture(),
        incidentFixture(id: 'inc_2', topic: 'new-topic'),
      ];
      topics = {'prod', 'new-topic'};
      final missed = await build().read();
      expect([for (final m in missed) m.incidentId], ['inc_1']);
    });

    test('topicsSeen stamps a new topic at that moment, and an incident '
        'after it counts', () async {
      store.topicsHeldSince = {};
      now = opened.subtract(const Duration(hours: 3));
      await build().topicsSeen(['prod']);
      expect(store.topicsHeldSince, {'prod': now});
      now = expired.add(const Duration(hours: 4));
      expect((await build().read()).single.incidentId, 'inc_1');
    });

    test('a stamp is written once', () async {
      final first = store.topicsHeldSince['prod'];
      await build().topicsSeen(['prod']);
      await build().record();
      expect(store.topicsHeldSince['prod'], first);
    });

    test('a topic that left and came back: what opened while it was gone '
        'is not classified, what opened before still is', () async {
      // Held for a week, gone an hour before the incident, back the
      // morning after.
      now = opened.subtract(const Duration(hours: 1));
      final reader = build();
      await reader.topicsSeen(const []);
      now = expired.add(const Duration(hours: 4));
      await reader.topicsSeen(['prod']);
      expect(store.topicHolds['prod'], hasLength(2));
      expect(await reader.read(), isEmpty);

      // An older incident, from while it was held the first time.
      incidents = [
        incidentFixture(
          id: 'inc_before',
          openedAt: opened.subtract(const Duration(hours: 5)),
          closedAt: opened.subtract(const Duration(hours: 4, minutes: 30)),
        ),
      ];
      expect((await reader.read()).single.incidentId, 'inc_before');
    });

    test(
      'an ended stretch is dropped once nothing in it can be shown',
      () async {
        final reader = build();
        await reader.topicsSeen(const []);
        now = now.add(const Duration(days: 9));
        await reader.topicsSeen(const []);
        expect(store.topicHolds, isEmpty);
      },
    );

    test('a topic list that cannot be read changes no stamp', () async {
      topics = null;
      final before = Map.of(store.topicsHeldSince);
      expect(await build().read(), hasLength(1));
      expect(store.topicsHeldSince, before);
    });
  });

  group('the connection', () {
    test('no server connected misses nothing', () async {
      server = null;
      expect(await build().read(), isEmpty);
    });

    test('connectionSaved stamps at that moment', () async {
      store = MemoryMissedAlarmStore()
        ..setupDoneAt = cutoffsLongAgo.setupDoneAt;
      now = opened.subtract(const Duration(hours: 2));
      final reader = build();
      await reader.connectionSaved(' $serverUrl ');
      expect(store.connected!.server, serverUrl);
      expect(store.connected!.since, now);
      await reader.topicsSeen(['prod']);
      // The incident opens two hours later, before anything reads again.
      now = expired.add(const Duration(hours: 4));
      expect((await reader.read()).single.incidentId, 'inc_1');
    });

    test('saving the same server again keeps the stamp', () async {
      final since = store.connected!.since;
      await build().connectionSaved(serverUrl);
      expect(store.connected!.since, since);
      expect(store.serverClears, 0);
    });

    test('a switch to another server clears the record of the old one, its '
        'closed entries and topic stamps', () async {
      final reader = build();
      capture = const PhoneCapture(arrivedIds: {'inc_1'});
      await reader.record();
      await reader.dismiss(['inc_old']);
      expect(store.record.arrivedAtMs, isNotEmpty);

      await reader.connectionSaved('https://other.example.com');
      expect(store.serverClears, 1);
      expect(store.record.arrivedAtMs, isEmpty);
      expect(store.dismissed, isEmpty);
      expect(store.topicsHeldSince, isEmpty);
      expect(store.connected!.server, 'https://other.example.com');
      expect(store.connected!.since, now);
    });

    test(
      'after a switch, what the old server opened is not classified',
      () async {
        final reader = build();
        await reader.connectionSaved('https://other.example.com');
        server = 'https://other.example.com';
        // The shared list can still hold the old server's incidents.
        expect(await reader.read(), isEmpty);
      },
    );

    test(
      'a switch seen only at the next read clears and restamps too',
      () async {
        server = 'https://other.example.com';
        expect(await build().read(), isEmpty);
        expect(store.serverClears, 1);
        expect(store.connected!.server, 'https://other.example.com');
        expect(store.connected!.since, now);
      },
    );

    test('an incident that opened while the phone had no server is not '
        'missed after it connects to the same server again', () async {
      now = opened.subtract(const Duration(hours: 1));
      final reader = build();
      await reader.connectionCleared();
      expect(store.connected!.server, isEmpty);
      expect(store.serverClears, 1);
      // Connected again the morning after.
      now = expired.add(const Duration(hours: 4));
      await reader.connectionSaved(serverUrl);
      expect(await reader.read(), isEmpty);
      expect(store.connected!.since, now);
    });
  });

  group('setup', () {
    test('setupCompleted stamps at that moment, and an incident that opens '
        'before the next read counts', () async {
      store = stampedStore()..setupDoneAt = null;
      now = opened.subtract(const Duration(minutes: 30));
      final reader = build();
      await reader.setupCompleted();
      expect(store.setupDoneAt, now);
      now = expired.add(const Duration(hours: 4));
      expect((await reader.read()).single.incidentId, 'inc_1');
    });

    test('the stamp is written once', () async {
      final first = store.setupDoneAt;
      await build().setupCompleted();
      await build().record();
      expect(store.setupDoneAt, first);
    });

    test('setup is not stamped while it is unfinished', () async {
      store = stampedStore()..setupDoneAt = null;
      setupDone = false;
      await build().record();
      expect(store.setupDoneAt, isNull);
      expect(await build().read(), isEmpty);
    });

    test('an incident opened during unfinished setup is never missed, '
        'even after setup is done', () async {
      store = stampedStore()..setupDoneAt = null;
      setupDone = false;
      final reader = build();
      await reader.read();
      now = now.add(const Duration(hours: 1));
      setupDone = true;
      await reader.setupCompleted();
      expect(await reader.read(), isEmpty);
      now = now.add(const Duration(days: 1));
      expect(await reader.read(), isEmpty);
    });
  });

  group('an install with no stamp at all', () {
    setUp(() {
      store = MemoryMissedAlarmStore();
    });

    test('the stretch before the first stamp is not classified', () async {
      expect(await build().read(), isEmpty);
      // The first run stamped all three, as of now.
      expect(store.setupDoneAt, now);
      expect(store.connected!.since, now);
      expect(store.topicsHeldSince, {'prod': now});
      // And it stays unclassified on every later read.
      now = now.add(const Duration(days: 2));
      expect(await build().read(), isEmpty);
    });

    test('an incident after the first stamps is missed', () async {
      now = opened.subtract(const Duration(hours: 2));
      await build().record();
      now = expired.add(const Duration(hours: 4));
      expect((await build().read()).single.incidentId, 'inc_1');
    });
  });

  test('a first launch nobody stamped misses nothing', () async {
    firstLaunchAt = null;
    expect(await build().read(), isEmpty);
  });

  test('a capture that throws does not throw, names no cause, and the '
      'stamps are still written', () async {
    store = stampedStore()..topicsHeldSince = {};
    final reader = MissedAlarmReader(
      store: store,
      readIncidents: () => incidents,
      readTopicNames: () async => topics,
      capture: () async => throw StateError('no channel'),
      isSetupDone: () async => true,
      readServer: () async => server,
      firstLaunchAt: () => firstLaunchAt,
      setupIncidentIds: () => const {},
      everyPushIsLogged: true,
      now: () => now,
    );
    await reader.record();
    expect(store.topicsHeldSince, {'prod': now});
    store.topicsHeldSince = {'prod': cutoffsLongAgo.topicHeldSince!};
    // The record was never read after the incident, so it names no cause.
    expect((await reader.read()).single.reason, MissedReason.unanswered);
  });

  test('every read looks at the phone once', () async {
    await build().read();
    expect(captures, 1);
  });

  test('writes take turns: a close made while a record is running is not '
      'lost', () async {
    final reader = build();
    final recording = reader.record();
    final closing = reader.dismiss(['inc_1']);
    await Future.wait([recording, closing]);
    expect(store.dismissed.keys, ['inc_1']);
    expect(await reader.readToShow(), isEmpty);
  });

  group('closing an entry', () {
    test('a closed incident is not shown again', () async {
      final reader = build();
      expect(await reader.readToShow(), hasLength(1));
      await reader.dismiss(['inc_1']);
      expect(await reader.readToShow(), isEmpty);
      // Still missed, as far as the rule goes.
      expect(await reader.read(), hasLength(1));
    });

    test('closing keeps earlier closed entries', () async {
      final reader = build();
      await reader.dismiss(['inc_1']);
      now = now.add(const Duration(days: 3));
      await reader.dismiss(['inc_2']);
      expect(store.dismissed.keys, containsAll(['inc_1', 'inc_2']));
    });

    test('a closed entry is forgotten after thirty days, long after its '
        'incident left the window', () async {
      final reader = build();
      await reader.dismiss(['inc_1']);
      now = now.add(const Duration(days: 31));
      await reader.dismiss(['inc_9']);
      expect(store.dismissed.keys, ['inc_9']);
      expect(await reader.readToShow(), isEmpty);
    });
  });

  group('what to show', () {
    MissedAlarm alarm(String id, DateTime at) => MissedAlarm(
      incidentId: id,
      topic: 'prod',
      at: at,
      reason: MissedReason.unanswered,
    );

    test('newest first', () {
      final shown = missedAlarmsToShow(
        missed: [
          alarm('a', now.subtract(const Duration(days: 2))),
          alarm('b', now.subtract(const Duration(hours: 1))),
          alarm('c', now.subtract(const Duration(days: 1))),
        ],
        dismissedIds: const {},
        now: now,
      );
      expect([for (final a in shown) a.incidentId], ['b', 'c', 'a']);
    });

    test('seven days old is shown, a second older is not', () {
      final edge = now.subtract(missedAlarmWindow);
      expect(
        missedAlarmsToShow(
          missed: [alarm('a', edge)],
          dismissedIds: const {},
          now: now,
        ),
        hasLength(1),
      );
      expect(
        missedAlarmsToShow(
          missed: [alarm('a', edge.subtract(const Duration(seconds: 1)))],
          dismissedIds: const {},
          now: now,
        ),
        isEmpty,
      );
    });

    test('a time after now is left out', () {
      expect(
        missedAlarmsToShow(
          missed: [alarm('a', now.add(const Duration(minutes: 1)))],
          dismissedIds: const {},
          now: now,
        ),
        isEmpty,
      );
    });
  });
}
