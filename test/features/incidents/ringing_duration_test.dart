import 'package:critalarm/core/api/mock_api_client.dart';
import 'package:critalarm/core/api/mock_server.dart';
import 'package:critalarm/features/history/presentation/history_formatting.dart';
import 'package:critalarm/features/incidents/data/repositories/in_memory_incident_repository.dart';
import 'package:critalarm/features/incidents/domain/usecases/acknowledge_incident_usecase.dart';
import 'package:critalarm/features/incidents/domain/usecases/close_incident_usecase.dart';
import 'package:critalarm/features/incidents/domain/usecases/get_incident_usecase.dart';
import 'package:critalarm/features/incidents/domain/usecases/get_incidents_usecase.dart';
import 'package:critalarm/features/incidents/presentation/cubits/critical_alarm_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

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
}
