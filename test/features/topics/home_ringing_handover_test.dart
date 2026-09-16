import 'package:critalarm/app/state/incidents_cubit.dart';
import 'package:critalarm/app/state/topics_cubit.dart';
import 'package:critalarm/core/api/mock_api_client.dart';
import 'package:critalarm/core/api/mock_server.dart';
import 'package:critalarm/design/tokens/colors.dart';
import 'package:critalarm/features/incidents/data/repositories/in_memory_incident_repository.dart';
import 'package:critalarm/features/incidents/domain/usecases/get_incidents_usecase.dart';
import 'package:critalarm/features/topics/data/repositories/in_memory_topic_repository.dart';
import 'package:critalarm/features/topics/domain/usecases/get_topics_usecase.dart';
import 'package:critalarm/features/topics/presentation/cubits/home_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late MockServer server;
  late HomeCubit cubit;

  HomeCubit build() {
    final api = MockApiClient(server);
    final incidentRepo = InMemoryIncidentRepository(api);
    return HomeCubit(
      IncidentsCubit(GetIncidentsUsecase(incidentRepo)),
      TopicsCubit(GetTopicsUsecase(InMemoryTopicRepository(api))),
      incidentRepo,
    );
  }

  setUp(() => server = MockServer());

  group('the list hands over while something is ringing', () {
    test('a ringing incident is named on the state', () async {
      server.seedAlarmed();
      cubit = build();

      await cubit.load();

      expect(cubit.state.severity, SeverityMode.crit);
      expect(cubit.state.ringingIncidentId, isNotNull);
      expect(cubit.state.ringingIncidentId, startsWith('inc_'));
    });

    test('nothing ringing leaves it null', () async {
      server.seedCalm();
      cubit = build();

      await cubit.load();

      expect(cubit.state.severity, SeverityMode.none);
      expect(cubit.state.ringingIncidentId, isNull);
    });

    test('a warning is not a ring', () async {
      server.seedWorried();
      cubit = build();

      await cubit.load();

      expect(cubit.state.severity, SeverityMode.high);
      expect(
        cubit.state.ringingIncidentId,
        isNull,
        reason: 'only a critical page takes over the screen',
      );
    });

    test('the id clears once the ring is over', () async {
      server.seedAlarmed();
      cubit = build();
      await cubit.load();
      expect(cubit.state.ringingIncidentId, isNotNull);

      server.seedCalm();
      await cubit.refresh();

      expect(cubit.state.ringingIncidentId, isNull);
    });
  });
}
