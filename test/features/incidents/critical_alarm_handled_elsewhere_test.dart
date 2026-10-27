import 'dart:async';

import 'package:critalarm/app/state/incidents_cubit.dart';
import 'package:critalarm/core/failures/failure.dart';
import 'package:critalarm/core/result/result.dart';
import 'package:critalarm/features/incidents/domain/entities/incident.dart';
import 'package:critalarm/features/incidents/domain/repositories/incident_repository.dart';
import 'package:critalarm/features/incidents/domain/usecases/acknowledge_incident_usecase.dart';
import 'package:critalarm/features/incidents/domain/usecases/close_incident_usecase.dart';
import 'package:critalarm/features/incidents/domain/usecases/get_incident_usecase.dart';
import 'package:critalarm/features/incidents/domain/usecases/get_incidents_usecase.dart';
import 'package:critalarm/features/incidents/presentation/cubits/critical_alarm_cubit.dart';
import 'package:critalarm/features/incidents/presentation/cubits/critical_alarm_state.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../core/alarm/fake_alarm_host.dart';

final _openedAt = DateTime.utc(2026, 10, 17, 3);

/// Marks "send the opened_at of the ringing stage" in a native message.
const Object _sameStage = Object();

Incident _incident(String id, {String state = IncidentStates.open}) => Incident(
  id: id,
  topic: 'prod-db',
  state: state,
  openedAt: _openedAt,
  updatedAt: _openedAt,
);

/// A server whose answers a test sets one at a time. The list read and the
/// single read both answer from [store]; [checkFails] makes the single read
/// fail, and [checkGate] holds it.
class _Server implements IncidentRepository {
  _Server(List<Incident> incidents)
    : store = {for (final incident in incidents) incident.id: incident};

  final Map<String, Incident> store;

  /// What an acknowledge answers per id. Anything not listed succeeds.
  final Map<String, Failure> refuseAck = {};

  bool checkFails = false;
  Completer<void>? checkGate;
  int checks = 0;

  /// What the single read answers instead of [store], once. A stale answer:
  /// what the server said before something changed.
  Incident? staleAnswer;

  @override
  Future<AppResult<List<Incident>>> getIncidents({
    required int limit,
    String? state,
    String? topic,
    DateTime? since,
    bool fullRefresh = false,
  }) async => store.values
      .where((i) => state == null || i.state == state)
      .toList()
      .toSuccess();

  @override
  Future<AppResult<Incident>> getIncident(String id) async {
    checks++;
    await checkGate?.future;
    if (checkFails) {
      return const Failure.unexpected(message: 'no route').toFailure();
    }
    final stale = staleAnswer;
    if (stale != null) {
      staleAnswer = null;
      return stale.toSuccess();
    }
    final incident = store[id];
    return incident == null
        ? const Failure.notFound().toFailure()
        : incident.toSuccess();
  }

  @override
  Future<AppResult<Incident>> ackIncident(String id) async {
    final failure = refuseAck[id];
    if (failure != null) return failure.toFailure();
    final acked = store[id]!.copyWith(state: IncidentStates.acked);
    store[id] = acked;
    return acked.toSuccess();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

void main() {
  late _Server server;
  late FakeAlarmHost alarm;
  late IncidentsCubit incidents;
  late CriticalAlarmCubit cubit;

  CriticalAlarmCubit build() {
    incidents = IncidentsCubit(GetIncidentsUsecase(server));
    addTearDown(incidents.close);
    final built = CriticalAlarmCubit(
      GetIncidentUsecase(server),
      GetIncidentsUsecase(server),
      AcknowledgeIncidentUsecase(server),
      CloseIncidentUsecase(server),
      incidents,
      alarm.host,
    );
    addTearDown(built.close);
    return built;
  }

  setUp(() {
    server = _Server([_incident('inc_1')]);
    alarm = FakeAlarmHost()
      ..answers['ringGeneration'] = 7
      ..answers['applyRemoteState'] = 'nothing';
  });

  tearDown(() => alarm.dispose());

  List<Map<String, Object?>> remoteStates() => alarm.argsTo('applyRemoteState');

  Future<void> ringing() async {
    cubit = build();
    await incidents.ensureLoaded();
    await cubit.load(incidentId: 'inc_1');
    expect(cubit.state.status, CriticalAlarmStatus.ringing);
    alarm.calls.clear();
  }

  group("I'm up on a phone where another device was first", () {
    setUp(() async {
      server.refuseAck['inc_1'] = const Failure.api(statusCode: 409);
      await ringing();
      server.store['inc_1'] = _incident('inc_1', state: IncidentStates.acked);
    });

    test('a 409 is a success: the ring stops and nothing re-arms', () async {
      await cubit.acknowledge();
      await pumpEventQueue();

      expect(alarm.argsOnce('cancelAlarm')['incident_id'], 'inc_1');
      expect(alarm.argsOnce('markAcked')['incident_id'], 'inc_1');
      expect(alarm.callsTo('rearmAlarm'), isEmpty);
      expect(alarm.callsTo('stopRinging'), isEmpty);
      expect(cubit.state.errorMessage, isNull);
      expect(cubit.state.isAcknowledged, isTrue);
    });

    test('the note follows a check native accepted', () async {
      await cubit.acknowledge();
      await pumpEventQueue();

      expect(remoteStates().single['generation'], 7);
      expect(cubit.state.isHandledElsewhere, isTrue);
    });

    test('no note when native refused the check', () async {
      alarm.answers['applyRemoteState'] = 'refused';

      await cubit.acknowledge();
      await pumpEventQueue();

      expect(cubit.state.isHandledElsewhere, isFalse);
    });

    test('a 409 never ends a card on its own', () async {
      server.store['inc_1'] = _incident('inc_1', state: IncidentStates.closed);

      await cubit.acknowledge();
      await pumpEventQueue();

      expect(alarm.callsTo('endActivity'), isEmpty);
    });

    test('a 409 is never counted as an acknowledge made here', () async {
      final seen = <CriticalAlarmState>[cubit.state];
      final sub = cubit.stream.listen(seen.add);
      addTearDown(sub.cancel);

      await cubit.acknowledge();
      await pumpEventQueue();

      for (var i = 1; i < seen.length; i++) {
        expect(
          countsAsConfirmedAck(previous: seen[i - 1], current: seen[i]),
          isFalse,
          reason: 'state $i',
        );
      }
    });

    test('Stop on the note goes through the guarded call only', () async {
      await cubit.acknowledge();
      await pumpEventQueue();
      alarm.calls.clear();

      final done = await cubit.stopHandledElsewhere();

      expect(done, isTrue);
      expect(remoteStates().single['generation'], 7);
      expect(alarm.callsTo('cancelAlarm'), isEmpty);
      expect(alarm.callsTo('cancelRearm'), isEmpty);
      expect(alarm.callsTo('stopRinging'), isEmpty);
    });

    test('Stop on the note that native refuses shows the ring again', () async {
      await cubit.acknowledge();
      await pumpEventQueue();
      // A reopen armed a new ring since the check.
      alarm.answers['applyRemoteState'] = 'refused';
      server.store['inc_1'] = _incident(
        'inc_1',
      ).copyWith(openedAt: _openedAt.add(const Duration(minutes: 10)));

      final done = await cubit.stopHandledElsewhere();
      await pumpEventQueue();

      expect(done, isFalse);
      expect(cubit.state.status, CriticalAlarmStatus.ringing);
      expect(cubit.state.isHandledElsewhere, isFalse);
    });
  });

  group('the shared list hears another device answered', () {
    setUp(ringing);

    test('an ack elsewhere: a fresh guarded check, then the note', () async {
      server.store['inc_1'] = _incident(
        'inc_1',
        state: IncidentStates.acked,
      ).copyWith(updatedAt: _openedAt.add(const Duration(minutes: 1)));
      final checks = server.checks;
      await incidents.refresh();
      await pumpEventQueue();

      expect(server.checks, checks + 1);
      final told = remoteStates().single;
      expect(told['state'], 'acked');
      expect(told['generation'], 7);
      expect(cubit.state.isHandledElsewhere, isTrue);
      expect(cubit.state.isLive, isFalse);
    });

    test('native refusing it keeps the ringing screen', () async {
      alarm.answers['applyRemoteState'] = 'refused';
      server.store['inc_1'] = _incident('inc_1', state: IncidentStates.closed);
      await incidents.refresh();
      await pumpEventQueue();

      expect(cubit.state.isLive, isTrue);
      expect(cubit.state.isHandledElsewhere, isFalse);
    });

    test('a fresh check that fails keeps the ringing screen', () async {
      server.store['inc_1'] = _incident('inc_1', state: IncidentStates.acked);
      server.checkFails = true;
      await incidents.refresh();
      await pumpEventQueue();

      expect(remoteStates(), isEmpty);
      expect(cubit.state.isLive, isTrue);
    });

    test(
      'an acknowledge of this phone is not taken for one elsewhere',
      () async {
        await cubit.acknowledge();
        await pumpEventQueue();

        expect(cubit.state.isHandledElsewhere, isFalse);
        expect(remoteStates(), isEmpty);
      },
    );

    test('a copy from an earlier stage does not count', () async {
      server.store['inc_1'] = _incident(
        'inc_1',
        state: IncidentStates.acked,
      ).copyWith(openedAt: _openedAt.subtract(const Duration(minutes: 20)));
      await incidents.refresh();
      await pumpEventQueue();

      expect(cubit.state.isLive, isTrue);
      expect(remoteStates(), isEmpty);
    });

    test('a state word the app does not know does not count', () async {
      server.store['inc_1'] = _incident('inc_1', state: 'snoozed');
      await incidents.refresh();
      await pumpEventQueue();

      expect(cubit.state.isLive, isTrue);
      expect(remoteStates(), isEmpty);
    });
  });

  group('Silence asks the server once', () {
    setUp(ringing);

    test('the generation is read before the question goes out', () async {
      server.store['inc_1'] = _incident('inc_1', state: IncidentStates.acked);
      server.checkGate = Completer<void>();

      final silencing = cubit.silence();
      await pumpEventQueue();
      // A push arms a new ring while the question is out.
      alarm.answers['ringGeneration'] = 8;
      server.checkGate!.complete();
      await silencing;

      expect(remoteStates().single['generation'], 7);
      expect(remoteStates().single.containsKey('checked_at'), isFalse);
    });

    test('a failed check never stops a ring', () async {
      server.checkFails = true;

      await cubit.silence();

      expect(alarm.argsOnce('rearmAlarm')['incident_id'], 'inc_1');
      expect(remoteStates(), isEmpty);
      expect(cubit.state.status, CriticalAlarmStatus.ringing);
    });

    test('a check that never answers never stops a ring', () async {
      final before = CriticalAlarmCubit.stateCheckTimeout;
      CriticalAlarmCubit.stateCheckTimeout = const Duration(milliseconds: 20);
      addTearDown(() => CriticalAlarmCubit.stateCheckTimeout = before);
      server.checkGate = Completer<void>();

      await cubit.silence();

      expect(remoteStates(), isEmpty);
      expect(cubit.state.status, CriticalAlarmStatus.ringing);
    });

    test('an open incident keeps the ring Silence set', () async {
      await cubit.silence();

      expect(remoteStates(), isEmpty);
      expect(cubit.state.isHandledElsewhere, isFalse);
    });

    test('an answer about an earlier stage does not stop the ring', () async {
      server.store['inc_1'] = _incident(
        'inc_1',
        state: IncidentStates.acked,
      ).copyWith(openedAt: _openedAt.subtract(const Duration(minutes: 20)));

      await cubit.silence();

      expect(remoteStates(), isEmpty);
      expect(cubit.state.isLive, isTrue);
    });

    test(
      'an acknowledge elsewhere that native accepts shows the note',
      () async {
        server.store['inc_1'] = _incident('inc_1', state: IncidentStates.acked);
        alarm.answers['applyRemoteState'] = 'stopped';

        await cubit.silence();

        expect(remoteStates().single['state'], 'acked');
        expect(cubit.state.isHandledElsewhere, isTrue);
      },
    );
  });

  group('the screen opens on an incident that is already over', () {
    test('a phone still ringing for it stops and shows the note', () async {
      server.store['inc_1'] = _incident('inc_1', state: IncidentStates.acked);
      alarm.answers['applyRemoteState'] = 'stopped';
      cubit = build();

      await cubit.load(incidentId: 'inc_1');

      expect(remoteStates().single['generation'], 7);
      expect(cubit.state.isHandledElsewhere, isTrue);
    });

    test(
      'a phone with nothing ringing shows the acknowledged screen',
      () async {
        server.store['inc_1'] = _incident('inc_1', state: IncidentStates.acked);
        cubit = build();

        await cubit.load(incidentId: 'inc_1');

        expect(cubit.state.isHandledElsewhere, isFalse);
        expect(cubit.state.status, CriticalAlarmStatus.acknowledged);
      },
    );

    test('a newer stage seen while the answer was out wins', () async {
      cubit = build();
      final later = _openedAt.add(const Duration(minutes: 10));
      server.store['inc_1'] = _incident(
        'inc_1',
      ).copyWith(openedAt: later, updatedAt: later);
      await incidents.ensureLoaded();
      // The answer describes the stage before the reopen.
      server.staleAnswer = _incident('inc_1', state: IncidentStates.acked);
      alarm.answers['applyRemoteState'] = 'stopped';

      await cubit.load(incidentId: 'inc_1');

      expect(remoteStates(), isEmpty);
      expect(cubit.state.status, CriticalAlarmStatus.ringing);
      expect(cubit.state.incident?.openedAt, later);
    });

    test('native refusing a stale answer loads the incident again', () async {
      server.staleAnswer = _incident('inc_1', state: IncidentStates.acked);
      alarm.answers['applyRemoteState'] = 'refused';
      cubit = build();

      await cubit.load(incidentId: 'inc_1');

      expect(server.checks, 2);
      expect(cubit.state.status, CriticalAlarmStatus.ringing);
    });

    test('an open incident asks the phone nothing', () async {
      cubit = build();

      await cubit.load(incidentId: 'inc_1');

      expect(remoteStates(), isEmpty);
      expect(cubit.state.status, CriticalAlarmStatus.ringing);
    });
  });

  group('the iPhone hears it through the Live Activity', () {
    setUp(ringing);

    Future<void> nativeSays(
      String incidentId,
      String state, {
      Object? openedAt = _sameStage,
    }) async {
      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
            'app.critalarm/alarm',
            const StandardMethodCodec().encodeMethodCall(
              MethodCall('onRemoteState', {
                'incident_id': incidentId,
                'state': state,
                if (openedAt != null)
                  'opened_at': identical(openedAt, _sameStage)
                      ? _openedAt.millisecondsSinceEpoch ~/ 1000
                      : openedAt,
              }),
            ),
            (_) {},
          );
      await pumpEventQueue();
    }

    test('the screen makes its own guarded check before the note', () async {
      server.store['inc_1'] = _incident('inc_1', state: IncidentStates.acked);
      final checks = server.checks;

      await nativeSays('inc_1', 'acked');

      expect(server.checks, greaterThan(checks));
      expect(remoteStates().first['generation'], 7);
      expect(cubit.state.isHandledElsewhere, isTrue);
    });

    test('the update alone does not end the screen', () async {
      // The server still says open: the update was about something else.
      await nativeSays('inc_1', 'acked');

      expect(cubit.state.isHandledElsewhere, isFalse);
      expect(cubit.state.isLive, isTrue);
    });

    test('an update for an earlier stage asks nothing', () async {
      server.store['inc_1'] = _incident('inc_1', state: IncidentStates.acked);
      final checks = server.checks;
      final earlier = _openedAt.subtract(const Duration(minutes: 20));

      await nativeSays(
        'inc_1',
        'acked',
        openedAt: earlier.millisecondsSinceEpoch ~/ 1000,
      );

      expect(server.checks, checks);
      expect(cubit.state.isLive, isTrue);
    });

    test('another incident leaves the screen alone', () async {
      server.store['inc_1'] = _incident('inc_1', state: IncidentStates.acked);
      await nativeSays('inc_other', 'acked');

      expect(cubit.state.isLive, isTrue);
    });
  });

  group('an acknowledge the server took', () {
    test('counts once, after the server answered', () async {
      await ringing();
      final seen = <CriticalAlarmState>[cubit.state];
      final sub = cubit.stream.listen(seen.add);
      addTearDown(sub.cancel);

      await cubit.acknowledge();
      await pumpEventQueue();

      var confirmed = 0;
      for (var i = 1; i < seen.length; i++) {
        if (countsAsConfirmedAck(previous: seen[i - 1], current: seen[i])) {
          confirmed++;
          expect(seen[i].isAckPending, isFalse);
        }
      }
      expect(confirmed, 1);
    });
  });

  group('coming back to the app with the ringing screen up', () {
    setUp(ringing);

    test('the screen checks its own incident with the generation', () async {
      server.store['inc_1'] = _incident('inc_1', state: IncidentStates.acked);

      await cubit.recheck();

      expect(remoteStates().single['generation'], 7);
      expect(cubit.state.isHandledElsewhere, isTrue);
    });

    test('an open incident keeps ringing', () async {
      await cubit.recheck();

      expect(cubit.state.isLive, isTrue);
      expect(remoteStates(), isEmpty);
    });

    test('a screen that is not ringing asks nothing', () async {
      await cubit.acknowledge();
      final checks = server.checks;

      await cubit.recheck();

      expect(server.checks, checks);
    });
  });
}
