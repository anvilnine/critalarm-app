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
    alarm = FakeAlarmHost();
  });

  tearDown(() => alarm.dispose());

  List<Map<String, Object?>> remoteStates() => alarm.argsTo('applyRemoteState');

  group("I'm up on a phone where another device was first", () {
    setUp(() async {
      server.refuseAck['inc_1'] = const Failure.api(statusCode: 409);
      cubit = build();
      await incidents.ensureLoaded();
      // The phone loaded the incident while it was still open. Then another
      // device acknowledged it.
      await cubit.load(incidentId: 'inc_1');
      server.store['inc_1'] = _incident('inc_1', state: IncidentStates.acked);
      expect(cubit.state.status, CriticalAlarmStatus.ringing);
    });

    test('a 409 is a success: the ring stops and nothing re-arms', () async {
      alarm.calls.clear();

      await cubit.acknowledge();
      await pumpEventQueue();

      expect(alarm.argsOnce('cancelAlarm')['incident_id'], 'inc_1');
      expect(alarm.argsOnce('markAcked')['incident_id'], 'inc_1');
      expect(alarm.callsTo('rearmAlarm'), isEmpty);
      expect(alarm.callsTo('stopRinging'), isEmpty);
      expect(cubit.state.errorMessage, isNull);
      expect(cubit.state.isAcknowledged, isTrue);
      expect(cubit.state.status, CriticalAlarmStatus.acknowledged);
    });

    test('the screen says it was handled on another device', () async {
      await cubit.acknowledge();
      await pumpEventQueue();

      expect(cubit.state.isHandledElsewhere, isTrue);
      expect(cubit.state.isLive, isFalse);
    });

    test('a 409 for a closed incident leaves no acked card behind', () async {
      server.store['inc_1'] = _incident('inc_1', state: IncidentStates.closed);
      alarm.calls.clear();

      await cubit.acknowledge();
      await pumpEventQueue();

      final ended = alarm.argsOnce('endActivity');
      expect(ended['incident_id'], 'inc_1');
      expect(ended['state'], 'closed');
      expect(cubit.state.incident?.isClosed, isTrue);
      expect(cubit.state.isHandledElsewhere, isTrue);
    });

    test('Stop on the note silences this incident only', () async {
      await cubit.acknowledge();
      await pumpEventQueue();
      alarm.calls.clear();

      await cubit.stopHandledElsewhere();

      expect(alarm.argsOnce('cancelAlarm')['incident_id'], 'inc_1');
      expect(alarm.argsOnce('cancelRearm')['incident_id'], 'inc_1');
      expect(alarm.callsTo('stopRinging'), isEmpty);
    });
  });

  group('the shared list hears another device answered', () {
    setUp(() async {
      cubit = build();
      await incidents.ensureLoaded();
      await cubit.load(incidentId: 'inc_1');
      expect(cubit.state.status, CriticalAlarmStatus.ringing);
      alarm.calls.clear();
    });

    test('an ack elsewhere closes the ringing screen with the note', () async {
      // An Android state push makes the app reload the list.
      server.store['inc_1'] = _incident(
        'inc_1',
        state: IncidentStates.acked,
      ).copyWith(updatedAt: _openedAt.add(const Duration(minutes: 1)));
      await incidents.refresh();
      await pumpEventQueue();

      expect(cubit.state.isHandledElsewhere, isTrue);
      expect(cubit.state.isLive, isFalse);
      final told = remoteStates().single;
      expect(told['incident_id'], 'inc_1');
      expect(told['state'], 'acked');
      expect(alarm.callsTo('rearmAlarm'), isEmpty);
    });

    test('a close elsewhere does the same', () async {
      server.store['inc_1'] = _incident('inc_1', state: IncidentStates.closed);
      await incidents.refresh();
      await pumpEventQueue();

      expect(cubit.state.isHandledElsewhere, isTrue);
      expect(remoteStates().single['state'], 'closed');
    });

    test('an acknowledge of this phone is not taken for one elsewhere', () {
      // This phone's own I'm up moves the screen to the acknowledged state
      // before the list hears of it, so no note and no second stop.
      return cubit.acknowledge().then((_) async {
        await pumpEventQueue();
        expect(cubit.state.isHandledElsewhere, isFalse);
        expect(remoteStates(), isEmpty);
      });
    });

    test(
      'a copy from an earlier stage of the incident does not count',
      () async {
        // Acknowledged once, reopened by the desk timer, ringing again now. A
        // stale copy of the first stage carries the old opened_at.
        server.store['inc_1'] = _incident(
          'inc_1',
          state: IncidentStates.acked,
        ).copyWith(openedAt: _openedAt.subtract(const Duration(minutes: 20)));
        await incidents.refresh();
        await pumpEventQueue();

        expect(cubit.state.status, CriticalAlarmStatus.ringing);
        expect(cubit.state.isLive, isTrue);
        expect(remoteStates(), isEmpty);
      },
    );

    test('a state word the app does not know does not count', () async {
      server.store['inc_1'] = _incident('inc_1', state: 'snoozed');
      await incidents.refresh();
      await pumpEventQueue();

      expect(cubit.state.isLive, isTrue);
      expect(remoteStates(), isEmpty);
    });
  });

  group('Silence asks the server once', () {
    setUp(() async {
      cubit = build();
      await cubit.load(incidentId: 'inc_1');
      alarm.calls.clear();
    });

    test('a failed check never stops a ring', () async {
      server.checkFails = true;

      await cubit.silence();

      expect(alarm.argsOnce('rearmAlarm')['incident_id'], 'inc_1');
      expect(alarm.callsTo('cancelRearm'), isEmpty);
      expect(remoteStates(), isEmpty);
      expect(cubit.state.status, CriticalAlarmStatus.ringing);
      expect(cubit.state.isHandledElsewhere, isFalse);
    });

    test('a check that never answers never stops a ring', () async {
      final before = CriticalAlarmCubit.stateCheckTimeout;
      CriticalAlarmCubit.stateCheckTimeout = const Duration(milliseconds: 20);
      addTearDown(() => CriticalAlarmCubit.stateCheckTimeout = before);
      server.checkGate = Completer<void>();

      await cubit.silence();

      expect(alarm.callsTo('rearmAlarm'), hasLength(1));
      expect(remoteStates(), isEmpty);
      expect(cubit.state.status, CriticalAlarmStatus.ringing);
      expect(cubit.state.isHandledElsewhere, isFalse);
    });

    test('an open incident keeps the ring Silence set', () async {
      await cubit.silence();

      expect(alarm.callsTo('rearmAlarm'), hasLength(1));
      expect(remoteStates(), isEmpty);
      expect(cubit.state.isHandledElsewhere, isFalse);
    });

    test('an acknowledge elsewhere drops the ring Silence set', () async {
      server.store['inc_1'] = _incident('inc_1', state: IncidentStates.acked);

      await cubit.silence();

      expect(alarm.callsTo('rearmAlarm'), hasLength(1));
      expect(remoteStates().single['state'], 'acked');
      expect(cubit.state.isHandledElsewhere, isTrue);
    });
  });

  group('the screen opens on an incident that is already over', () {
    test('a phone still ringing for it stops and shows the note', () async {
      server.store['inc_1'] = _incident('inc_1', state: IncidentStates.acked);
      alarm.answers['applyRemoteState'] = true;
      cubit = build();

      await cubit.load(incidentId: 'inc_1');

      expect(remoteStates().single['state'], 'acked');
      expect(cubit.state.isHandledElsewhere, isTrue);
    });

    test(
      'a phone with nothing ringing shows the acknowledged screen',
      () async {
        server.store['inc_1'] = _incident('inc_1', state: IncidentStates.acked);
        alarm.answers['applyRemoteState'] = false;
        cubit = build();

        await cubit.load(incidentId: 'inc_1');

        expect(cubit.state.isHandledElsewhere, isFalse);
        expect(cubit.state.status, CriticalAlarmStatus.acknowledged);
      },
    );

    test('an open incident asks the phone nothing', () async {
      cubit = build();

      await cubit.load(incidentId: 'inc_1');

      expect(remoteStates(), isEmpty);
      expect(cubit.state.status, CriticalAlarmStatus.ringing);
    });
  });

  group('the iPhone hears it through the Live Activity', () {
    setUp(() async {
      cubit = build();
      await incidents.ensureLoaded();
      await cubit.load(incidentId: 'inc_1');
    });

    Future<void> nativeSays(String incidentId, String state) async {
      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
            'app.critalarm/alarm',
            const StandardMethodCodec().encodeMethodCall(
              MethodCall('onRemoteState', {
                'incident_id': incidentId,
                'state': state,
              }),
            ),
            (_) {},
          );
      await pumpEventQueue();
    }

    test('the ringing screen closes with the note', () async {
      await nativeSays('inc_1', 'acked');

      expect(cubit.state.isHandledElsewhere, isTrue);
      expect(cubit.state.isLive, isFalse);
    });

    test('another incident leaves the screen alone', () async {
      await nativeSays('inc_other', 'acked');

      expect(cubit.state.isHandledElsewhere, isFalse);
      expect(cubit.state.isLive, isTrue);
    });

    test('an open state leaves the screen alone', () async {
      await nativeSays('inc_1', 'open');

      expect(cubit.state.isLive, isTrue);
    });
  });
}
