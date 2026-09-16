import 'dart:async';

import 'package:critalarm/app/state/incidents_cubit.dart';
import 'package:critalarm/core/failures/failure.dart';
import 'package:critalarm/features/incidents/domain/entities/incident.dart';
import 'package:critalarm/features/incidents/domain/usecases/acknowledge_incident_usecase.dart';
import 'package:critalarm/features/incidents/domain/usecases/close_incident_usecase.dart';
import 'package:critalarm/features/incidents/domain/usecases/get_incident_usecase.dart';
import 'package:critalarm/features/incidents/domain/usecases/get_incidents_usecase.dart';
import 'package:critalarm/features/incidents/presentation/cubits/critical_alarm_cubit.dart';
import 'package:critalarm/features/incidents/presentation/cubits/critical_alarm_state.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/scripted_incident_repository.dart';

Incident _open(String id) => Incident(
  id: id,
  topic: 'prod-db',
  openedAt: DateTime.now().subtract(const Duration(minutes: 2)),
);

void main() {
  late ScriptedIncidentRepository repository;
  late IncidentsCubit incidents;
  late CriticalAlarmCubit alarm;

  Future<void> build() async {
    incidents = IncidentsCubit(GetIncidentsUsecase(repository));
    addTearDown(incidents.close);
    await incidents.ensureLoaded();

    alarm = CriticalAlarmCubit(
      GetIncidentUsecase(repository),
      GetIncidentsUsecase(repository),
      AcknowledgeIncidentUsecase(repository),
      CloseIncidentUsecase(repository),
      incidents,
    );
    addTearDown(alarm.close);
    await alarm.load(incidentId: 'inc_1');
  }

  setUp(() {
    repository = ScriptedIncidentRepository([_open('inc_1')]);
  });

  test('the shared list is acknowledged before the server answers', () async {
    await build();
    repository.gate = Completer<void>();

    final acking = alarm.acknowledge();
    await pumpEventQueue();

    expect(
      incidents.state.incidents.single.isAcked,
      isTrue,
      reason: 'Home, History and search read this list',
    );
    expect(alarm.state.isAcknowledged, isTrue);
    expect(alarm.state.isAcknowledging, isFalse);
    expect(alarm.state.status, CriticalAlarmStatus.acknowledged);
    expect(
      repository.sent,
      ['inc_1'],
      reason: 'the request is still in flight',
    );

    repository.gate!.complete();
    await acking;

    expect(incidents.state.incidents.single.isAcked, isTrue);
  });

  test('a refused acknowledge rolls back and says so', () async {
    repository.refuse['inc_1'] = const Failure.api(statusCode: 500);
    await build();

    await alarm.acknowledge();

    expect(incidents.state.incidents.single.isOpen, isTrue);
    expect(alarm.state.status, CriticalAlarmStatus.ringing);
    expect(alarm.state.isAcknowledged, isFalse);
    expect(alarm.state.isLive, isTrue);
    expect(alarm.state.errorMessage, isNotNull);
  });

  test('a 409 still counts as an acknowledge', () async {
    repository.refuse['inc_1'] = const Failure.api(statusCode: 409);
    await build();

    await alarm.acknowledge();

    expect(
      incidents.state.incidents.single.isAcked,
      isTrue,
      reason: 'it was acknowledged somewhere else, so the guess was right',
    );
    expect(alarm.state.isAcknowledged, isTrue);
    expect(alarm.state.status, CriticalAlarmStatus.acknowledged);
    expect(alarm.state.errorMessage, isNull);
  });

  test('a rollback does not undo a push that landed in between', () async {
    repository.refuse['inc_1'] = const Failure.api(statusCode: 500);
    await build();
    repository.gate = Completer<void>();

    final acking = alarm.acknowledge();
    await pumpEventQueue();

    // A push closes the incident while the acknowledge is on the wire.
    incidents.applyIncident(
      incidents.state.incidents.single.copyWith(state: IncidentStates.closed),
    );

    repository.gate!.complete();
    await acking;

    expect(incidents.state.incidents.single.isClosed, isTrue);
  });
}
