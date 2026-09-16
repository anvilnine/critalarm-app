import 'dart:async';

import 'package:critalarm/app/state/incidents_cubit.dart';
import 'package:critalarm/core/result/result.dart';
import 'package:critalarm/features/incidents/domain/entities/incident.dart';
import 'package:critalarm/features/incidents/domain/repositories/incident_repository.dart';
import 'package:critalarm/features/incidents/domain/usecases/get_incidents_usecase.dart';
import 'package:flutter_test/flutter_test.dart';

/// Hands out a list read the test finishes by hand, so a slow answer can land
/// after the app has already moved on.
class _ScriptedIncidents implements IncidentRepository {
  final pending = <Completer<AppResult<List<Incident>>>>[];

  @override
  Future<AppResult<List<Incident>>> getIncidents({
    required int limit,
    String? state,
    String? topic,
  }) {
    final completer = Completer<AppResult<List<Incident>>>();
    pending.add(completer);
    return completer.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

Incident _incident(String id, {String state = 'open'}) => Incident(
  id: id,
  topic: 'prod-db',
  state: state,
  openedAt: DateTime.utc(2026, 9, 17, 8),
);

void main() {
  group('a guess goes in before the server answers', () {
    test('acknowledgeNow marks the incident acknowledged straight away',
        () async {
      final scripted = _ScriptedIncidents();
      final cubit = IncidentsCubit(GetIncidentsUsecase(scripted));
      addTearDown(cubit.close);

      final loaded = cubit.ensureLoaded();
      scripted.pending[0].complete([_incident('inc_1')].toSuccess());
      await loaded;

      cubit.acknowledgeNow(cubit.state.incidents.single);

      expect(cubit.state.incidents.single.isAcked, isTrue);
      expect(cubit.state.openIncidents, isEmpty);
    });

    test('an incident the list has never seen is added, then put back open',
        () async {
      final scripted = _ScriptedIncidents();
      final cubit = IncidentsCubit(GetIncidentsUsecase(scripted));
      addTearDown(cubit.close);

      final loaded = cubit.ensureLoaded();
      scripted.pending[0].complete(<Incident>[].toSuccess());
      await loaded;

      final ack = cubit.acknowledgeNow(_incident('inc_9'));
      expect(cubit.state.incidents.single.isAcked, isTrue);

      cubit.revert(ack);
      expect(cubit.state.incidents.single.isOpen, isTrue);
    });
  });

  group('a rollback against the stale-write guard', () {
    test('puts the old value back when nothing else touched it', () async {
      final scripted = _ScriptedIncidents();
      final cubit = IncidentsCubit(GetIncidentsUsecase(scripted));
      addTearDown(cubit.close);

      final loaded = cubit.ensureLoaded();
      scripted.pending[0].complete([_incident('inc_1')].toSuccess());
      await loaded;

      final ack = cubit.acknowledgeNow(cubit.state.incidents.single);
      cubit.revert(ack);

      expect(cubit.state.incidents.single.isOpen, isTrue);
    });

    test('is dropped when a newer update landed while the ack was in the air',
        () async {
      final scripted = _ScriptedIncidents();
      final cubit = IncidentsCubit(GetIncidentsUsecase(scripted));
      addTearDown(cubit.close);

      final loaded = cubit.ensureLoaded();
      scripted.pending[0].complete([_incident('inc_1')].toSuccess());
      await loaded;

      final ack = cubit.acknowledgeNow(cubit.state.incidents.single);
      cubit
        // A push lands while the acknowledge is still on the wire.
        ..applyIncident(_incident('inc_1', state: 'closed'))
        ..revert(ack);

      expect(
        cubit.state.incidents.single.state,
        'closed',
        reason: 'the rollback carries an older value than the push',
      );
    });

    test('a list read asked for before the rollback still cannot undo it',
        () async {
      final scripted = _ScriptedIncidents();
      var clock = DateTime(2026, 9, 17, 10);
      final cubit = IncidentsCubit(
        GetIncidentsUsecase(scripted),
        now: () => clock,
      );
      addTearDown(cubit.close);

      final loaded = cubit.ensureLoaded();
      scripted.pending[0].complete([_incident('inc_1')].toSuccess());
      await loaded;

      clock = DateTime(2026, 9, 17, 10, 0, 1);
      final ack = cubit.acknowledgeNow(cubit.state.incidents.single);

      // A slow list read goes out while the acknowledge is on the wire.
      clock = DateTime(2026, 9, 17, 10, 0, 2);
      final slow = cubit.refresh();

      // The server refuses the acknowledge, so the guess comes back out.
      clock = DateTime(2026, 9, 17, 10, 0, 3);
      cubit.revert(ack);

      // That read was asked for before the rollback and still says acked.
      scripted.pending[1].complete(
        [_incident('inc_1', state: 'acked')].toSuccess(),
      );
      await slow;

      expect(
        cubit.state.incidents.single.isOpen,
        isTrue,
        reason: 'the guard drops an answer older than the rollback',
      );
    });
  });
}
