import 'package:critalarm/app/state/incidents_cubit.dart';
import 'package:critalarm/core/access/feature_decision.dart';
import 'package:critalarm/core/access/holding.dart';
import 'package:critalarm/core/failures/failure.dart';
import 'package:critalarm/core/models/send_result.dart';
import 'package:critalarm/core/result/result.dart';
import 'package:critalarm/features/challenges/data/shared_prefs_challenge_choices.dart';
import 'package:critalarm/features/challenges/domain/challenge_gate.dart';
import 'package:critalarm/features/challenges/domain/challenge_incident.dart';
import 'package:critalarm/features/challenges/domain/challenge_kind.dart';
import 'package:critalarm/features/challenges/domain/challenge_rule.dart';
import 'package:critalarm/features/incidents/domain/close_without_server.dart';
import 'package:critalarm/features/incidents/domain/entities/incident.dart';
import 'package:critalarm/features/incidents/domain/entities/message.dart';
import 'package:critalarm/features/incidents/domain/repositories/incident_repository.dart';
import 'package:critalarm/features/incidents/domain/usecases/acknowledge_incident_usecase.dart';
import 'package:critalarm/features/incidents/domain/usecases/close_incident_usecase.dart';
import 'package:critalarm/features/incidents/domain/usecases/get_incident_usecase.dart';
import 'package:critalarm/features/incidents/domain/usecases/get_incidents_usecase.dart';
import 'package:critalarm/features/incidents/presentation/cubits/critical_alarm_cubit.dart';
import 'package:critalarm/features/incidents/presentation/cubits/critical_alarm_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/alarm/fake_alarm_host.dart';

// What a person can still do on the alarm screen when the server does not
// answer. The Done button on a card opens the app while its topic owes a
// wake-up challenge, so the app must never be a place with no "At my
// desk".

const _offline = Failure.unexpected(message: 'SocketException');

Failure _status(int code) => Failure.api(statusCode: code);

final _acked = Incident(
  id: 'inc_1',
  topic: 'prod-db',
  state: IncidentStates.acked,
  openedAt: DateTime.utc(2026, 10, 8, 3),
  ackedAt: DateTime.utc(2026, 10, 8, 3, 2),
);

/// A server that answers what the test tells it to.
class _Server implements IncidentRepository {
  /// What `GET /v1/incidents/{id}` answers. Null hands the incident over.
  Failure? getFails;

  /// What the close answers. Null closes it.
  Failure? closeFails;

  /// What the list answers with.
  List<Incident> listed = const [];

  final List<String> closes = [];

  @override
  Future<AppResult<Incident>> getIncident(String id) async =>
      getFails?.toFailure() ?? _acked.toSuccess();

  @override
  Future<AppResult<Incident>> closeIncident(String id) async {
    closes.add(id);
    return closeFails?.toFailure() ??
        _acked.copyWith(state: IncidentStates.closed).toSuccess();
  }

  @override
  Future<AppResult<List<Incident>>> getIncidents({
    required int limit,
    String? state,
    String? topic,
    DateTime? since,
    bool fullRefresh = false,
  }) async => listed.toSuccess();

  @override
  Future<AppResult<Incident>> ackIncident(String id) async =>
      _acked.toSuccess();

  @override
  Future<void> saveIncident(Incident incident) async {}

  @override
  Future<AppResult<String>> triggerTest({required String topic}) async =>
      throw UnimplementedError();

  @override
  Future<AppResult<SendResult>> publishMessage(
    String topic, {
    required String message,
    String? title,
    int priority = 3,
    List<String>? tags,
  }) async => throw UnimplementedError();

  @override
  Future<AppResult<List<Message>>> pollMessages(
    String topic, {
    required int poll,
    String? since,
  }) async => throw UnimplementedError();
}

void main() {
  late _Server server;
  late FakeAlarmHost alarm;
  late List<String> queued;

  Future<CriticalAlarmCubit> build({bool holdsIncident = false}) async {
    IncidentsCubit? incidents;
    if (holdsIncident) {
      server.listed = [_acked];
      incidents = IncidentsCubit(GetIncidentsUsecase(server));
      addTearDown(incidents.close);
      await incidents.ensureLoaded();
    }
    final cubit = CriticalAlarmCubit(
      GetIncidentUsecase(server),
      GetIncidentsUsecase(server),
      AcknowledgeIncidentUsecase(server),
      CloseIncidentUsecase(server),
      incidents,
      alarm.host,
    )..queueClose = (id) async => queued.add(id);
    addTearDown(cubit.close);
    return cubit;
  }

  /// The card for the incident was taken down, with nothing left in its
  /// place.
  bool cardCleared() => alarm
      .argsTo('cancelAlarm')
      .any(
        (args) =>
            args['incident_id'] == 'inc_1' &&
            args['hand_over_to_status_card'] == false,
      );

  setUp(() {
    server = _Server();
    alarm = FakeAlarmHost();
    queued = [];
  });

  tearDown(() => alarm.dispose());

  group('serverRefusalFor', () {
    test('404, 409 and 410 are settled', () {
      for (final code in [404, 409, 410]) {
        expect(serverRefusalFor(_status(code)), ServerRefusal.settled);
      }
      expect(
        serverRefusalFor(const Failure.notFound()),
        ServerRefusal.settled,
      );
      expect(
        serverRefusalFor(const Failure.conflict()),
        ServerRefusal.settled,
      );
    });

    test('no answer, 408, 429 and 5xx are queued', () {
      expect(serverRefusalFor(_offline), ServerRefusal.queue);
      for (final code in [408, 429, 500, 502, 503]) {
        expect(serverRefusalFor(_status(code)), ServerRefusal.queue);
      }
    });

    test('a no that a retry will not change is refused', () {
      for (final code in [400, 401, 403]) {
        expect(serverRefusalFor(_status(code)), ServerRefusal.refused);
      }
      expect(
        serverRefusalFor(const Failure.unauthorized()),
        ServerRefusal.refused,
      );
    });
  });

  group('the load fails and the app does not hold the incident', () {
    test('offline: "At my desk" is offered on the failed screen', () async {
      server.getFails = _offline;
      final cubit = await build();
      await cubit.load(incidentId: 'inc_1');

      expect(cubit.state.status, CriticalAlarmStatus.failure);
      expect(cubit.state.errorMessage, isNotNull);
      expect(cubit.state.unloadedIncidentId, 'inc_1');
      // Nothing was sent or cleared by the load alone.
      expect(queued, isEmpty);
      expect(cardCleared(), isFalse);
    });

    test('offline: one tap queues the close and clears the card', () async {
      server.getFails = _offline;
      final cubit = await build();
      await cubit.load(incidentId: 'inc_1');

      await cubit.closeUnloaded();

      expect(queued, ['inc_1']);
      expect(cardCleared(), isTrue);
      expect(cubit.state.isCloseQueued, isTrue);
      expect(cubit.state.unloadedIncidentId, isNull);
      expect(cubit.state.errorMessage, isNull);
    });

    test('offline: a second tap queues nothing more', () async {
      server.getFails = _offline;
      final cubit = await build();
      await cubit.load(incidentId: 'inc_1');
      await cubit.closeUnloaded();
      await cubit.closeUnloaded();
      expect(queued, ['inc_1']);
    });

    test('a 5xx is offered the same', () async {
      server.getFails = _status(503);
      final cubit = await build();
      await cubit.load(incidentId: 'inc_1');
      expect(cubit.state.unloadedIncidentId, 'inc_1');
    });

    for (final code in [404, 409, 410]) {
      test('$code: nothing to close, the card goes, nothing is '
          'queued', () async {
        server.getFails = _status(code);
        final cubit = await build();
        await cubit.load(incidentId: 'inc_1');

        expect(cardCleared(), isTrue);
        expect(queued, isEmpty);
        // The plain "nothing is ringing" screen.
        expect(cubit.state.status, CriticalAlarmStatus.initial);
        expect(cubit.state.errorMessage, isNull);
        expect(cubit.state.unloadedIncidentId, isNull);
      });
    }

    test('a session that ended keeps the failed screen as it was', () async {
      server.getFails = _status(401);
      final cubit = await build();
      await cubit.load(incidentId: 'inc_1');

      expect(cubit.state.status, CriticalAlarmStatus.failure);
      expect(cubit.state.unloadedIncidentId, isNull);
      expect(cardCleared(), isFalse);
    });

    test('a phone that is ringing keeps the failed screen as it was: '
        'nothing here stands in for "I\'m up"', () async {
      server.getFails = _offline;
      alarm.answers['isRinging'] = true;
      final cubit = await build();
      await cubit.load(incidentId: 'inc_1');

      expect(cubit.state.status, CriticalAlarmStatus.failure);
      expect(cubit.state.unloadedIncidentId, isNull);
      await cubit.closeUnloaded();
      expect(queued, isEmpty);
      expect(cardCleared(), isFalse);
    });

    test('a load with no incident named offers nothing to close', () async {
      final cubit = await build();
      await cubit.load();
      expect(cubit.state.unloadedIncidentId, isNull);
    });
  });

  group('the load fails and the app holds the incident as acknowledged', () {
    test('offline: the acknowledged screen is drawn from that '
        'copy', () async {
      final cubit = await build(holdsIncident: true);
      server.getFails = _offline;
      await cubit.load(incidentId: 'inc_1');

      expect(cubit.state.status, CriticalAlarmStatus.acknowledged);
      expect(cubit.state.isAcknowledged, isTrue);
      expect(cubit.state.topic, 'prod-db');
      expect(cubit.state.unloadedIncidentId, isNull);
    });

    test('offline: "At my desk" queues the close and shows closed', () async {
      final cubit = await build(holdsIncident: true);
      server
        ..getFails = _offline
        ..closeFails = _offline;
      await cubit.load(incidentId: 'inc_1');

      await cubit.closeIncident();

      expect(server.closes, ['inc_1']);
      expect(queued, ['inc_1']);
      expect(cardCleared(), isTrue);
      expect(cubit.state.status, CriticalAlarmStatus.closed);
      expect(cubit.state.isCloseQueued, isTrue);
    });

    for (final code in [404, 409, 410]) {
      test('$code on the close: closed, nothing queued', () async {
        final cubit = await build(holdsIncident: true);
        server
          ..getFails = _offline
          ..closeFails = _status(code);
        await cubit.load(incidentId: 'inc_1');

        await cubit.closeIncident();

        expect(queued, isEmpty);
        expect(cardCleared(), isTrue);
        expect(cubit.state.status, CriticalAlarmStatus.closed);
        expect(cubit.state.isCloseQueued, isFalse);
      });
    }

    test('a 401 on the close queues nothing and stays '
        'acknowledged', () async {
      final cubit = await build(holdsIncident: true);
      server
        ..getFails = _offline
        ..closeFails = _status(401);
      await cubit.load(incidentId: 'inc_1');

      await cubit.closeIncident();

      expect(queued, isEmpty);
      expect(cubit.state.status, CriticalAlarmStatus.acknowledged);
    });

    test('the server answers the load after all: nothing changes for a '
        'close that works', () async {
      final cubit = await build(holdsIncident: true);
      await cubit.load(incidentId: 'inc_1');
      await cubit.closeIncident();

      expect(queued, isEmpty);
      expect(cubit.state.status, CriticalAlarmStatus.closed);
      expect(cubit.state.isCloseQueued, isFalse);
    });
  });

  group('a close with no queue behind it', () {
    test('reports the failure, as it always did', () async {
      final cubit = CriticalAlarmCubit(
        GetIncidentUsecase(server),
        GetIncidentsUsecase(server),
        AcknowledgeIncidentUsecase(server),
        CloseIncidentUsecase(server),
        null,
        alarm.host,
      );
      addTearDown(cubit.close);
      await cubit.load(incidentId: 'inc_1');
      server.closeFails = _offline;

      await cubit.closeIncident();

      expect(cubit.state.status, CriticalAlarmStatus.acknowledged);
      expect(cubit.state.errorMessage, 'SocketException');
    });
  });

  // What "At my desk" owes on the acknowledged screen the held copy draws.
  // The screen asks the gate with the topic that copy names, so offline is
  // no different from online.
  group('the challenge with no server', () {
    late SharedPrefsChallengeChoices choices;

    Future<ChallengeDue> dueOffline({
      required bool hasChoice,
      required FeatureDecision decision,
    }) async {
      SharedPreferences.setMockInitialValues({
        if (hasChoice) 'topic_challenge.prod-db': 'type_topic_name',
        if (hasChoice && decision is! FeatureLocked)
          'topic_challenge_owed.prod-db': true,
      });
      choices = SharedPrefsChallengeChoices(
        await SharedPreferences.getInstance(),
      );
      addTearDown(choices.dispose);
      final cubit = await build(holdsIncident: true);
      server.getFails = _offline;
      await cubit.load(incidentId: 'inc_1');
      final gate = ChallengeGate(
        choices: choices,
        decide: () => decision,
        canRun: (_, incident) => incident.topic.isNotEmpty,
        planRead: Future<void>.value(),
      );
      await Future<void>.delayed(Duration.zero);
      return gate.dueFor(
        incident: ChallengeIncident(topic: cubit.state.topic),
        isScreenReaderOn: false,
      );
    }

    test('owed: asked from the topic the phone already holds', () async {
      expect(
        await dueOffline(
          hasChoice: true,
          decision: const FeatureDecision.open(),
        ),
        const ChallengeOwed(
          ChallengeKind.typeTopicName,
          wayOut: ChallengeWayOut.hold,
        ),
      );
    });

    test('owed while the plan cannot be read, from the flag', () async {
      expect(
        await dueOffline(
          hasChoice: true,
          decision: const FeatureDecision.unread(Holding.pro),
        ),
        isA<ChallengeOwed>(),
      );
    });

    test('not owed with no challenge set', () async {
      expect(
        await dueOffline(
          hasChoice: false,
          decision: const FeatureDecision.open(),
        ),
        isA<ChallengeNotOwed>(),
      );
    });

    test('not owed without Pro', () async {
      expect(
        await dueOffline(
          hasChoice: true,
          decision: const FeatureDecision.locked(Holding.pro),
        ),
        isA<ChallengeNotOwed>(),
      );
    });
  });
}
