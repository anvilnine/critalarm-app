import 'package:critalarm/core/api/mock_api_client.dart';
import 'package:critalarm/core/api/mock_server.dart';
import 'package:critalarm/core/failures/failure.dart';
import 'package:critalarm/core/result/result.dart';
import 'package:critalarm/core/usecase/usecase.dart';
import 'package:critalarm/features/incidents/data/repositories/in_memory_incident_repository.dart';
import 'package:critalarm/features/incidents/domain/repositories/incident_repository.dart';
import 'package:critalarm/features/incidents/domain/usecases/trigger_test_alarm_usecase.dart';
import 'package:critalarm/features/onboarding/data/repositories/in_memory_server_repository.dart';
import 'package:critalarm/features/onboarding/data/repositories/shared_prefs_connection_repository.dart';
import 'package:critalarm/features/onboarding/domain/entities/notification_permission_status.dart';
import 'package:critalarm/features/onboarding/domain/entities/server_connection.dart';
import 'package:critalarm/features/onboarding/domain/repositories/connection_repository.dart';
import 'package:critalarm/features/onboarding/domain/repositories/notification_permission_repository.dart';
import 'package:critalarm/features/onboarding/domain/repositories/server_repository.dart';
import 'package:critalarm/features/onboarding/domain/usecases/get_connection_usecase.dart';
import 'package:critalarm/features/onboarding/domain/usecases/get_server_info_usecase.dart';
import 'package:critalarm/features/onboarding/domain/usecases/open_notification_settings_usecase.dart';
import 'package:critalarm/features/onboarding/domain/usecases/request_notification_permission_usecase.dart';
import 'package:critalarm/features/onboarding/domain/usecases/save_connection_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockNotificationPermissionRepository extends Mock
    implements NotificationPermissionRepository {}

class MockConnectionRepository extends Mock implements ConnectionRepository {}

void main() {
  group('Onboarding Section B Usecases', () {
    late MockNotificationPermissionRepository mockNotifRepo;
    late MockConnectionRepository mockConnRepo;

    setUp(() {
      mockNotifRepo = MockNotificationPermissionRepository();
      mockConnRepo = MockConnectionRepository();
    });

    test(
      'RequestNotificationPermissionUsecase delegates to repository',
      () async {
        when(() => mockNotifRepo.requestPermission()).thenAnswer(
          (_) async => NotificationPermissionStatus.granted.toSuccess(),
        );

        final usecase = RequestNotificationPermissionUsecase(mockNotifRepo);
        final result = await usecase(const NoParams());

        expect(result.isSuccess(), isTrue);
        expect(result.getOrNull(), NotificationPermissionStatus.granted);
        verify(() => mockNotifRepo.requestPermission()).called(1);
      },
    );

    test('OpenNotificationSettingsUsecase delegates to repository', () async {
      when(
        () => mockNotifRepo.openSettings(),
      ).thenAnswer((_) async => true.toSuccess());

      final usecase = OpenNotificationSettingsUsecase(mockNotifRepo);
      final result = await usecase(const NoParams());

      expect(result.isSuccess(), isTrue);
      expect(result.getOrNull(), isTrue);
      verify(() => mockNotifRepo.openSettings()).called(1);
    });

    test('SaveConnectionUsecase delegates to repository', () async {
      const conn = ServerConnection(
        serverUrl: 'https://api.critalarm.app',
        adminToken: 'ad_tok',
      );
      when(
        () => mockConnRepo.saveConnection(conn),
      ).thenAnswer((_) async => unit.toSuccess());

      final usecase = SaveConnectionUsecase(mockConnRepo);
      final result = await usecase(conn);

      expect(result.isSuccess(), isTrue);
      verify(() => mockConnRepo.saveConnection(conn)).called(1);
    });

    test('GetConnectionUsecase delegates to repository', () async {
      const conn = ServerConnection(
        serverUrl: 'https://api.critalarm.app',
        adminToken: 'ad_tok',
      );
      when(
        () => mockConnRepo.getConnection(),
      ).thenAnswer((_) async => conn.toSuccess());

      final usecase = GetConnectionUsecase(mockConnRepo);
      final result = await usecase(const NoParams());

      expect(result.isSuccess(), isTrue);
      expect(result.getOrNull(), conn);
      verify(() => mockConnRepo.getConnection()).called(1);
    });
  });

  group('SharedPrefsConnectionRepository', () {
    test('saveConnection and getConnection roundtrip successfully', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = SharedPrefsConnectionRepository(prefs);

      // Initially empty -> NotFoundFailure
      final emptyResult = await repo.getConnection();
      expect(emptyResult.isError(), isTrue);
      expect(emptyResult.exceptionOrNull(), isA<NotFoundFailure>());

      // Save
      const conn = ServerConnection(
        serverUrl: 'https://my.server.net',
        adminToken: 'ad_secret_key_123',
      );
      final saveResult = await repo.saveConnection(conn);
      expect(saveResult.isSuccess(), isTrue);

      // Fetch
      final getResult = await repo.getConnection();
      expect(getResult.isSuccess(), isTrue);
      expect(getResult.getOrNull(), conn);

      // Clear
      final clearResult = await repo.clearConnection();
      expect(clearResult.isSuccess(), isTrue);

      // Fetch again -> NotFoundFailure
      final afterClearResult = await repo.getConnection();
      expect(afterClearResult.isError(), isTrue);
    });
  });

  group('GetServerInfoUsecase and TriggerTestAlarmUsecase', () {
    late MockServer server;
    late MockApiClient apiClient;
    late InMemoryServerRepository serverRepo;
    late InMemoryIncidentRepository incidentRepo;
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

    test('GetServerInfoUsecase returns ServerInfo on success', () async {
      final result = await getServerInfoUsecase(const NoParams());

      expect(result.isSuccess(), isTrue);
      final info = result.getOrNull()!;
      expect(info.name, 'critalarm');
      expect(info.version, '0.1.0');
    });

    test('TriggerTestAlarmUsecase successfully triggers test alarm on critical topic', () async {
      final result = await triggerTestAlarmUsecase('prod-db');

      expect(result.isSuccess(), isTrue);
      final incidentId = result.getOrNull()!;
      expect(incidentId, startsWith('inc_'));
    });

    test('TriggerTestAlarmUsecase returns 409 failure when topic is not critical', () async {
      final result = await triggerTestAlarmUsecase('nas-backup');

      expect(result.isError(), isTrue);
      final failure = result.exceptionOrNull()!;
      expect(failure, isA<ApiFailure>());
      expect((failure as ApiFailure).statusCode, 409);
    });
  });
}
