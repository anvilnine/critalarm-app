import 'package:critalarm/core/api/mock_api_client.dart';
import 'package:critalarm/core/api/mock_server.dart';
import 'package:critalarm/core/failures/failure.dart';
import 'package:critalarm/core/usecase/usecase.dart';
import 'package:critalarm/features/incidents/data/repositories/in_memory_incident_repository.dart';
import 'package:critalarm/features/incidents/domain/repositories/incident_repository.dart';
import 'package:critalarm/features/incidents/domain/usecases/trigger_test_alarm_usecase.dart';
import 'package:critalarm/features/onboarding/data/repositories/in_memory_server_repository.dart';
import 'package:critalarm/features/onboarding/domain/repositories/server_repository.dart';
import 'package:critalarm/features/onboarding/domain/usecases/get_server_info_usecase.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late MockServer server;
  late MockApiClient apiClient;
  late ServerRepository serverRepo;
  late IncidentRepository incidentRepo;
  late GetServerInfoUsecase getServerInfoUsecase;
  late TriggerTestAlarmUsecase triggerTestAlarmUsecase;

  setUp(() {
    server = MockServer()..seedCalm();
    apiClient = MockApiClient(server);
    serverRepo = InMemoryServerRepository(apiClient);
    incidentRepo = InMemoryIncidentRepository(apiClient);
    getServerInfoUsecase = GetServerInfoUsecase(serverRepo);
    triggerTestAlarmUsecase = TriggerTestAlarmUsecase(incidentRepo);
  });

  group('GetServerInfoUsecase', () {
    test('returns ServerInfo on success', () async {
      final result = await getServerInfoUsecase(const NoParams());

      expect(result.isSuccess(), isTrue);
      final info = result.getOrNull()!;
      expect(info.name, 'critalarm');
      expect(info.version, '0.1.0');
    });
  });

  group('TriggerTestAlarmUsecase', () {
    test('successfully triggers test alarm on critical topic', () async {
      final result = await triggerTestAlarmUsecase('prod-db');

      expect(result.isSuccess(), isTrue);
      final incidentId = result.getOrNull()!;
      expect(incidentId, startsWith('inc_'));
    });

    test('returns 409 failure when topic is not critical', () async {
      final result = await triggerTestAlarmUsecase('nas-backup');

      expect(result.isError(), isTrue);
      final failure = result.exceptionOrNull()!;
      expect(failure, isA<ApiFailure>());
      expect((failure as ApiFailure).statusCode, 409);
    });
  });
}
