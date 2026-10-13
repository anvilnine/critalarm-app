import 'package:critalarm/app/state/incidents_cubit.dart';
import 'package:critalarm/core/models/incident.dart';
import 'package:critalarm/core/models/message.dart';
import 'package:critalarm/core/result/result.dart';
import 'package:critalarm/features/incidents/domain/usecases/acknowledge_incident_usecase.dart';
import 'package:critalarm/features/incidents/domain/usecases/close_incident_usecase.dart';
import 'package:critalarm/features/incidents/domain/usecases/get_incident_usecase.dart';
import 'package:critalarm/features/incidents/domain/usecases/get_incidents_usecase.dart';
import 'package:critalarm/features/incidents/presentation/cubits/critical_alarm_cubit.dart';
import 'package:critalarm/features/incidents/presentation/cubits/critical_alarm_state.dart';
import 'package:critalarm/features/onboarding/domain/setup_use/setup_use.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../core/alarm/fake_alarm_host.dart';
import '../../helpers/load_translations.dart';
import '../onboarding/support/fake_setup_test_ring.dart';

class _MockGetIncident extends Mock implements GetIncidentUsecase {}

class _MockGetIncidents extends Mock implements GetIncidentsUsecase {}

class _MockAck extends Mock implements AcknowledgeIncidentUsecase {}

class _MockClose extends Mock implements CloseIncidentUsecase {}

/// The alarm screen of the setup test shows a sample message for the user's
/// answer. Every other incident shows what the server sent.
void main() {
  const testId = 'inc_test';
  const realId = 'inc_real';
  const serverTitle = 'Crit Alarm test';
  const serverBody = 'triggered';
  const sampleBody = 'This is what a real one looks like.';
  final openedAt = DateTime(2026, 10, 4, 21, 45);

  Incident incident(
    String id, {
    String state = IncidentStates.open,
    String topic = 'prod-db',
    String title = serverTitle,
    String message = serverBody,
    bool hasMessage = true,
  }) => Incident(
    id: id,
    topic: topic,
    openedAt: openedAt,
    ackedAt: state == IncidentStates.acked ? openedAt : null,
    state: state,
    messages: hasMessage
        ? [
            Message(
              id: 'm_$id',
              topic: topic,
              title: title,
              message: message,
              priority: 5,
              time: openedAt.millisecondsSinceEpoch ~/ 1000,
            ),
          ]
        : const [],
  );

  late _MockGetIncident getIncident;
  late _MockGetIncidents getIncidents;
  late _MockAck ack;
  late _MockClose close;
  late FakeAlarmHost alarm;
  late FakeSetupTestRing ring;
  late IncidentsCubit incidents;
  late CriticalAlarmCubit cubit;
  late Map<String, Incident> served;
  late int answerReads;

  /// Builds the cubit with [use] as the saved answer.
  void build(SetupUse? use, {SetupUse? Function()? reader}) {
    answerReads = 0;
    cubit = CriticalAlarmCubit(
      getIncident,
      getIncidents,
      ack,
      close,
      incidents,
      alarm.host,
      const Duration(seconds: 1),
      null,
      null,
      null,
      () => ring.incidentIds,
      () => true,
      null,
      ring,
      null,
      reader ??
          () {
            answerReads++;
            return use;
          },
    );
  }

  setUpAll(() async {
    registerFallbackValue(const GetIncidentsParams());
    await loadTestTranslations();
  });

  setUp(() {
    getIncident = _MockGetIncident();
    getIncidents = _MockGetIncidents();
    ack = _MockAck();
    close = _MockClose();
    alarm = FakeAlarmHost();
    ring = FakeSetupTestRing([testId]);
    served = {
      testId: incident(testId),
      realId: incident(realId),
    };
    when(() => getIncidents(any())).thenAnswer(
      (_) async => <Incident>[].toSuccess(),
    );
    incidents = IncidentsCubit(getIncidents);
    when(() => getIncident(any())).thenAnswer(
      (i) async => served[i.positionalArguments[0] as String]!.toSuccess(),
    );
    when(() => ack(any())).thenAnswer((i) async {
      final id = i.positionalArguments[0] as String;
      return served[id]!.copyWith(state: IncidentStates.acked).toSuccess();
    });
  });

  tearDown(() async {
    await cubit.close();
    await incidents.close();
    alarm.dispose();
  });

  const samples = {
    SetupUse.servers: 'Replication lag 14 min',
    SetupUse.homelab: 'Nextcloud is down',
    SetupUse.jobs: 'Nightly backup missed its check-in',
    SetupUse.home: 'Freezer is above -10 C',
  };

  group('the setup test', () {
    for (final MapEntry(key: use, value: sample) in samples.entries) {
      test('shows the ${use.name} sample while ringing and once '
          'acknowledged', () async {
        build(use);

        await cubit.load(incidentId: testId);

        expect(cubit.state.status, CriticalAlarmStatus.ringing);
        expect(cubit.state.title, sample);
        expect(cubit.state.body, sampleBody);
        // The topic is the one the user made.
        expect(cubit.state.topic, 'prod-db');
        expect(cubit.state.incident?.topic, 'prod-db');

        await cubit.acknowledge();

        expect(cubit.state.status, CriticalAlarmStatus.acknowledged);
        expect(cubit.state.title, sample);
        expect(cubit.state.body, sampleBody);
        expect(cubit.state.topic, 'prod-db');
      });
    }

    test('shows the sample when the alarm is opened already '
        'acknowledged or closed', () async {
      build(SetupUse.jobs);
      served[testId] = incident(testId, state: IncidentStates.acked);

      await cubit.load(incidentId: testId);

      expect(cubit.state.status, CriticalAlarmStatus.acknowledged);
      expect(cubit.state.title, samples[SetupUse.jobs]);
      expect(cubit.state.body, sampleBody);

      served[testId] = incident(testId, state: IncidentStates.closed);
      await cubit.load(incidentId: testId);

      expect(cubit.state.status, CriticalAlarmStatus.closed);
      expect(cubit.state.title, samples[SetupUse.jobs]);
    });

    test('never shows the server text on any state on the way', () async {
      build(SetupUse.servers);
      final seen = <String>[];
      final sub = cubit.stream.listen((s) => seen.add(s.title));

      await cubit.load(incidentId: testId);
      await cubit.acknowledge();
      await sub.cancel();

      expect(seen, isNotEmpty);
      expect(seen, isNot(contains(serverTitle)));
      expect(seen.where((t) => t.isNotEmpty).toSet(), {
        samples[SetupUse.servers],
      });
    });

    test(
      'the extension cache gets the title and body the server sent',
      () async {
        build(SetupUse.servers);

        await cubit.load(incidentId: testId);

        final cached = alarm.argsOnce('cacheIncidentContent');
        expect(cached['incident_id'], testId);
        expect(cached['title'], serverTitle);
        expect(cached['body'], serverBody);
      },
    );

    test('the card handed to the native side keeps the server text', () async {
      build(SetupUse.servers);
      await cubit.load(incidentId: testId);

      await cubit.acknowledge();

      final cancelled = alarm.argsOnce('cancelAlarm');
      expect(cancelled['incident_id'], testId);
      expect(cancelled['title'], serverTitle);
      expect(cancelled['body'], serverBody);
    });

    test('something else, no answer and an unreadable answer keep the '
        'server text', () async {
      for (final use in [SetupUse.other, null]) {
        build(use);
        await cubit.load(incidentId: testId);
        expect(cubit.state.title, serverTitle, reason: '$use');
        expect(cubit.state.body, serverBody, reason: '$use');
        await cubit.close();
      }

      build(null, reader: () => throw StateError('prefs unreadable'));
      await cubit.load(incidentId: testId);
      expect(cubit.state.title, serverTitle);
      expect(cubit.state.body, serverBody);
    });

    test('a test with no first message gets the sample too, and none '
        'for something else', () async {
      served[testId] = incident(testId, hasMessage: false);

      build(SetupUse.home);
      await cubit.load(incidentId: testId);
      expect(cubit.state.title, samples[SetupUse.home]);
      expect(cubit.state.body, sampleBody);
      // Nothing came from the server, so nothing is cached.
      expect(alarm.callsTo('cacheIncidentContent'), isEmpty);
      await cubit.close();

      build(SetupUse.other);
      await cubit.load(incidentId: testId);
      expect(cubit.state.title, contains('prod-db'));
      expect(cubit.state.title, isNot(samples[SetupUse.home]));
    });
  });

  group('every other incident', () {
    test('keeps the server text even with the same words, for every '
        'answer', () async {
      for (final use in SetupUse.values) {
        // A real incident that happens to read like the test, and the id is
        // not in the saved set.
        build(use);
        await cubit.load(incidentId: realId);

        expect(cubit.state.status, CriticalAlarmStatus.ringing, reason: '$use');
        expect(cubit.state.title, serverTitle, reason: '$use');
        expect(cubit.state.body, serverBody, reason: '$use');
        await cubit.close();
      }
    });

    test('a real incident with its own words is shown as sent', () async {
      build(SetupUse.servers);
      served[realId] = incident(
        realId,
        title: 'Primary database down',
        message: 'Connection pool exhausted',
      );

      await cubit.load(incidentId: realId);
      expect(cubit.state.title, 'Primary database down');
      expect(cubit.state.body, 'Connection pool exhausted');

      await cubit.acknowledge();
      expect(cubit.state.title, 'Primary database down');
      expect(cubit.state.body, 'Connection pool exhausted');
      final cancelled = alarm.argsOnce('cancelAlarm');
      expect(cancelled['title'], 'Primary database down');
      expect(cancelled['body'], 'Connection pool exhausted');
    });

    test('the answer is not read for them', () async {
      build(SetupUse.servers);

      await cubit.load(incidentId: realId);

      expect(answerReads, 0);
    });

    test('the first tool alarm is unchanged', () async {
      await ring.holdFirstMessage('inc_first');
      served['inc_first'] = incident('inc_first');
      build(SetupUse.servers);

      await cubit.load(incidentId: 'inc_first');

      expect(cubit.state.title, serverTitle);
      expect(cubit.state.body, serverBody);
      expect(answerReads, 0);
    });

    test('the phone-only demo is unchanged', () async {
      build(SetupUse.servers);

      await cubit.load(incidentId: 'inc_demo');

      expect(cubit.state.incident?.id, 'inc_demo');
      expect(cubit.state.title, isNot(samples[SetupUse.servers]));
      expect(cubit.state.body, isNot(sampleBody));
      expect(answerReads, 0);
    });

    test('a test run after setup, with no saved id, is unchanged', () async {
      ring = FakeSetupTestRing();
      build(SetupUse.homelab);

      await cubit.load(incidentId: testId);

      expect(cubit.state.title, serverTitle);
      expect(cubit.state.body, serverBody);
      expect(answerReads, 0);
    });

    test('a real alarm that takes the screen from the test shows its own '
        'words', () async {
      build(SetupUse.servers);
      await cubit.load(incidentId: testId);
      expect(cubit.state.title, samples[SetupUse.servers]);

      incidents.applyIncident(
        incident(
          realId,
          title: 'Disk full',
          message: 'No space left on /var',
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.incident?.id, realId);
      expect(cubit.state.title, 'Disk full');
      expect(cubit.state.body, 'No space left on /var');
    });
  });
}
