import 'package:critalarm/core/models/incident.dart';
import 'package:critalarm/features/reliability/domain/missed_alarm/missed_alarm_reader.dart';
import 'package:critalarm/features/reliability/domain/missed_alarm/missed_alarm_rule.dart';
import 'package:critalarm/features/reliability/domain/missed_alarm/missed_alarm_store.dart';
import 'package:critalarm/features/reliability/domain/missed_alarm/phone_record.dart';
import 'package:flutter_test/flutter_test.dart';

import 'missed_alarm_fixtures.dart';

void main() {
  late MemoryMissedAlarmStore store;
  late DateTime now;
  late List<Incident> incidents;
  late Set<String>? critical;
  late PhoneCapture capture;
  late bool setupDone;
  late String? server;
  late DateTime? firstLaunchAt;
  late Set<String> setupTests;
  late bool held;
  late int captures;

  MissedAlarmReader build({bool everyPushIsLogged = true}) => MissedAlarmReader(
    store: store,
    readIncidents: () => incidents,
    readCriticalTopics: () async => critical,
    capture: () async {
      captures++;
      return capture;
    },
    isSetupDone: () async => setupDone,
    readServer: () async => server,
    firstLaunchAt: () => firstLaunchAt,
    setupIncidentIds: () => setupTests,
    everyPushIsLogged: everyPushIsLogged,
    ringsCanBeHeld: () => held,
    now: () => now,
  );

  setUp(() {
    store = MemoryMissedAlarmStore()
      ..setupDoneAt = cutoffsLongAgo.setupDoneAt
      ..connected = ConnectedServer(
        server: 'https://alerts.example.com',
        since: cutoffsLongAgo.connectedSince!,
      )
      // The phone has been keeping its record since the day before.
      ..record = const PhoneRecord().merged(
        const PhoneCapture(),
        now: opened.subtract(const Duration(days: 1)),
      );
    now = expired.add(const Duration(hours: 4));
    incidents = [incidentFixture()];
    critical = {'prod'};
    capture = const PhoneCapture();
    setupDone = true;
    server = 'https://alerts.example.com';
    firstLaunchAt = cutoffsLongAgo.firstLaunchAt;
    setupTests = {};
    held = false;
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

  test('an alarm on record is "it rang"', () async {
    capture = const PhoneCapture(rangIds: {'inc_1'});
    expect(
      (await build().read()).single.reason,
      MissedReason.rangUnanswered,
    );
  });

  test('with a setting that can hold the ring it names no cause', () async {
    capture = const PhoneCapture(rangIds: {'inc_1'});
    held = true;
    expect((await build().read()).single.reason, MissedReason.unanswered);
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

  test('a topic list that cannot be read misses nothing', () async {
    critical = null;
    expect(await build().read(), isEmpty);
  });

  test('a setup test is not missed', () async {
    setupTests = {'inc_1'};
    expect(await build().read(), isEmpty);
  });

  test('no server connected misses nothing', () async {
    server = null;
    expect(await build().read(), isEmpty);
  });

  test('another server than the one stamped misses nothing old', () async {
    server = 'https://other.example.com';
    // The stamp is rewritten for the new server at this read, which is
    // after the incident opened.
    expect(await build().read(), isEmpty);
    expect(store.connected!.server, 'https://other.example.com');
    expect(store.connected!.since, now);
  });

  group('stamps', () {
    setUp(() {
      store = MemoryMissedAlarmStore();
    });

    test('nothing stamped yet means nothing is missed', () async {
      final missed = await build().read();
      expect(missed, isEmpty);
      // This read stamped both, at a time after the incident opened.
      expect(store.setupDoneAt, now);
      expect(store.connected!.since, now);
    });

    test('setup is not stamped while it is unfinished', () async {
      setupDone = false;
      await build().record();
      expect(store.setupDoneAt, isNull);
    });

    test('an incident opened during unfinished setup is never missed, '
        'even after setup is done', () async {
      setupDone = false;
      await build().read();
      // Setup is finished an hour later. The incident opened before that.
      now = now.add(const Duration(hours: 1));
      setupDone = true;
      expect(await build().read(), isEmpty);
      now = now.add(const Duration(days: 1));
      expect(await build().read(), isEmpty);
    });

    test('the stamps are written once', () async {
      await build().record();
      final first = store.setupDoneAt;
      now = now.add(const Duration(days: 2));
      await build().record();
      expect(store.setupDoneAt, first);
      expect(store.connected!.since, first);
    });

    test('an incident after the stamps is missed', () async {
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

  test(
    'a capture that throws misses nothing wrongly and does not throw',
    () async {
      final reader = MissedAlarmReader(
        store: store,
        readIncidents: () => incidents,
        readCriticalTopics: () async => critical,
        capture: () async => throw StateError('no channel'),
        isSetupDone: () async => true,
        readServer: () async => server,
        firstLaunchAt: () => firstLaunchAt,
        setupIncidentIds: () => const {},
        everyPushIsLogged: true,
        now: () => now,
      );
      // The record was never read after the incident, so it names no cause.
      expect((await reader.read()).single.reason, MissedReason.unanswered);
    },
  );

  test('every read looks at the phone once', () async {
    await build().read();
    expect(captures, 1);
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
