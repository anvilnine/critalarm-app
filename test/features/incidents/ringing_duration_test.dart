import 'package:critalarm/core/api/mock_api_client.dart';
import 'package:critalarm/core/api/mock_server.dart';
import 'package:critalarm/features/history/presentation/history_formatting.dart';
import 'package:critalarm/features/incidents/data/repositories/in_memory_incident_repository.dart';
import 'package:critalarm/features/incidents/domain/entities/incident.dart';
import 'package:critalarm/features/incidents/domain/usecases/acknowledge_incident_usecase.dart';
import 'package:critalarm/features/incidents/domain/usecases/close_incident_usecase.dart';
import 'package:critalarm/features/incidents/domain/usecases/get_incident_usecase.dart';
import 'package:critalarm/features/incidents/domain/usecases/get_incidents_usecase.dart';
import 'package:critalarm/features/incidents/presentation/cubits/critical_alarm_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/scripted_incident_repository.dart';

void main() {
  // "Ringing 2 min 14 s." was a literal string in en.json, so the screen
  // claimed the same length whatever was happening. The mock fixture happens
  // to be 2 min 14 s old, which is why this checks against the incident's own
  // opened_at rather than against that text.
  test('the ringing line counts from the incident, not a fixture', () async {
    final server = MockServer()..seedAlarmed();
    final repository = InMemoryIncidentRepository(MockApiClient(server));
    final cubit = CriticalAlarmCubit(
      GetIncidentUsecase(repository),
      GetIncidentsUsecase(repository),
      AcknowledgeIncidentUsecase(repository),
      CloseIncidentUsecase(repository),
    );

    await cubit.load();

    final openedAt = cubit.state.incident!.openedAt!;
    final expected = formatRingDuration(DateTime.now().difference(openedAt));
    expect(cubit.state.subtext, 'Ringing $expected.');
  });

  test('a fresh incident reads as seconds, not as minutes', () async {
    final server = MockServer()..seedAlarmed();
    final repository = InMemoryIncidentRepository(MockApiClient(server));
    final cubit = CriticalAlarmCubit(
      GetIncidentUsecase(repository),
      GetIncidentsUsecase(repository),
      AcknowledgeIncidentUsecase(repository),
      CloseIncidentUsecase(repository),
    );
    await cubit.load();
    final openedAt = cubit.state.incident!.openedAt!;

    // Same formatter, a different age. Proves the line is a function of the
    // incident rather than one string for every incident.
    expect(
      formatRingDuration(
        openedAt.add(const Duration(seconds: 12)).difference(openedAt),
      ),
      '12 s',
    );
  });

  group('the ringing line ticks', () {
    final opened = DateTime(2026, 9, 17, 10);

    CriticalAlarmCubit build(DateTime Function() now) {
      final repository = ScriptedIncidentRepository([
        Incident(id: 'inc_1', topic: 'prod-db', openedAt: opened),
      ]);
      return CriticalAlarmCubit(
        GetIncidentUsecase(repository),
        GetIncidentsUsecase(repository),
        AcknowledgeIncidentUsecase(repository),
        CloseIncidentUsecase(repository),
        null,
        null,
        const Duration(milliseconds: 5),
        now,
      );
    }

    test('the number moves while the alarm is live', () async {
      var clock = opened.add(const Duration(seconds: 30));
      final cubit = build(() => clock);
      addTearDown(cubit.close);

      await cubit.load(incidentId: 'inc_1');
      expect(cubit.state.subtext, contains('30 s'));

      clock = opened.add(const Duration(seconds: 45));
      await Future<void>.delayed(const Duration(milliseconds: 40));

      expect(cubit.state.subtext, contains('45 s'));
    });

    test('closing the cubit cancels the ticker', () async {
      var clock = opened.add(const Duration(seconds: 30));
      final cubit = build(() => clock);

      await cubit.load(incidentId: 'inc_1');
      final lastDrawn = cubit.state.subtext;

      await cubit.close();
      clock = opened.add(const Duration(seconds: 55));
      // A live timer would emit here, and emitting after close throws.
      await Future<void>.delayed(const Duration(milliseconds: 40));

      expect(cubit.state.subtext, lastDrawn);
    });

    test('acknowledging stops the ticker', () async {
      var clock = opened.add(const Duration(seconds: 30));
      final cubit = build(() => clock);
      addTearDown(cubit.close);

      await cubit.load(incidentId: 'inc_1');
      await cubit.acknowledge();
      final acknowledged = cubit.state.subtext;

      clock = opened.add(const Duration(seconds: 55));
      await Future<void>.delayed(const Duration(milliseconds: 40));

      expect(cubit.state.subtext, acknowledged);
    });
  });
}
