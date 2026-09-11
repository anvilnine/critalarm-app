import 'package:critalarm/core/api/mock_api_client.dart';
import 'package:critalarm/core/api/mock_server.dart';
import 'package:critalarm/core/failures/failure.dart';
import 'package:critalarm/core/models/incident.dart';
import 'package:critalarm/features/incidents/data/repositories/in_memory_incident_repository.dart';
import 'package:critalarm/features/incidents/domain/repositories/incident_repository.dart';
import 'package:critalarm/features/incidents/domain/usecases/acknowledge_incident_usecase.dart';
import 'package:critalarm/features/incidents/domain/usecases/close_incident_usecase.dart';
import 'package:critalarm/features/incidents/domain/usecases/get_incident_usecase.dart';
import 'package:critalarm/features/incidents/domain/usecases/get_incidents_usecase.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late MockServer server;
  late MockApiClient apiClient;
  late IncidentRepository repository;
  late GetIncidentsUsecase getIncidentsUsecase;
  late GetIncidentUsecase getIncidentUsecase;
  late AcknowledgeIncidentUsecase acknowledgeIncidentUsecase;
  late CloseIncidentUsecase closeIncidentUsecase;

  setUp(() {
    server = MockServer()..seedAlarmed();
    apiClient = MockApiClient(server);
    repository = InMemoryIncidentRepository(apiClient);
    getIncidentsUsecase = GetIncidentsUsecase(repository);
    getIncidentUsecase = GetIncidentUsecase(repository);
    acknowledgeIncidentUsecase = AcknowledgeIncidentUsecase(repository);
    closeIncidentUsecase = CloseIncidentUsecase(repository);
  });

  group('GetIncidentsUsecase', () {
    test('returns all seeded incidents', () async {
      final result = await getIncidentsUsecase();

      expect(result.isSuccess(), isTrue);
      final incidents = result.getOrNull()!;
      expect(incidents.isNotEmpty, isTrue);
      expect(incidents.first.topic, 'prod-db');
    });

    test('filters incidents by state', () async {
      final result = await getIncidentsUsecase(
        const GetIncidentsParams(state: 'open'),
      );

      expect(result.isSuccess(), isTrue);
      final incidents = result.getOrNull()!;
      expect(incidents.every((i) => i.isOpen), isTrue);
    });

    test('filters incidents by topic', () async {
      final result = await getIncidentsUsecase(
        const GetIncidentsParams(topic: 'prod-db'),
      );

      expect(result.isSuccess(), isTrue);
      final incidents = result.getOrNull()!;
      expect(incidents.every((i) => i.topic == 'prod-db'), isTrue);
    });
  });

  group('GetIncidentUsecase', () {
    test('returns single incident by id', () async {
      final result = await getIncidentUsecase('inc_alarmed_proddb');

      expect(result.isSuccess(), isTrue);
      final incident = result.getOrNull()!;
      expect(incident.id, 'inc_alarmed_proddb');
      expect(incident.topic, 'prod-db');
      expect(incident.isOpen, isTrue);
    });

    test('returns failure when incident does not exist', () async {
      final result = await getIncidentUsecase('non_existent_inc');

      expect(result.isError(), isTrue);
      final failure = result.exceptionOrNull()!;
      expect(failure, isA<ApiFailure>());
      expect((failure as ApiFailure).statusCode, 404);
    });
  });

  group('AcknowledgeIncidentUsecase', () {
    test('acknowledges open incident and transitions state to acked', () async {
      final result = await acknowledgeIncidentUsecase('inc_alarmed_proddb');

      expect(result.isSuccess(), isTrue);
      final incident = result.getOrNull()!;
      expect(incident.state, IncidentStates.acked);
      expect(incident.ackedAt, isNotNull);
      expect(incident.deskTimerFiresAt, isNotNull);
    });

    test('returns 409 conflict when acknowledging non-open incident', () async {
      // First ack
      await acknowledgeIncidentUsecase('inc_alarmed_proddb');

      // Second ack should fail with 409
      final result = await acknowledgeIncidentUsecase('inc_alarmed_proddb');

      expect(result.isError(), isTrue);
      final failure = result.exceptionOrNull()!;
      expect(failure, isA<ApiFailure>());
      expect((failure as ApiFailure).statusCode, 409);
    });
  });

  group('CloseIncidentUsecase', () {
    test(
      'closes acknowledged incident and transitions state to closed',
      () async {
        // Transition open -> acked
        await acknowledgeIncidentUsecase('inc_alarmed_proddb');

        // Transition acked -> closed
        final result = await closeIncidentUsecase('inc_alarmed_proddb');

        expect(result.isSuccess(), isTrue);
        final incident = result.getOrNull()!;
        expect(incident.state, IncidentStates.closed);
        expect(incident.closedAt, isNotNull);
      },
    );

    test(
      'returns 409 conflict when closing an unacknowledged incident',
      () async {
        final result = await closeIncidentUsecase('inc_alarmed_proddb');

        expect(result.isError(), isTrue);
        final failure = result.exceptionOrNull()!;
        expect(failure, isA<ApiFailure>());
        expect((failure as ApiFailure).statusCode, 409);
      },
    );
  });
}
