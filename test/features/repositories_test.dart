import 'package:critalarm/app/di.dart';
import 'package:critalarm/core/api/api_client.dart';
import 'package:critalarm/core/api/mock_api_client.dart';
import 'package:critalarm/core/api/mock_server.dart';
import 'package:critalarm/core/failures/failure.dart';
import 'package:critalarm/core/models/device_registration.dart';
import 'package:critalarm/core/models/incident.dart';
import 'package:critalarm/features/incidents/data/repositories/in_memory_incident_repository.dart';
import 'package:critalarm/features/incidents/domain/repositories/incident_repository.dart';
import 'package:critalarm/features/incidents/domain/usecases/trigger_test_alarm_usecase.dart';
import 'package:critalarm/features/onboarding/data/repositories/in_memory_server_repository.dart';
import 'package:critalarm/features/onboarding/domain/repositories/server_repository.dart';
import 'package:critalarm/features/onboarding/domain/usecases/get_server_info_usecase.dart';
import 'package:critalarm/features/onboarding/presentation/cubits/onboarding_permissions_cubit.dart';
import 'package:critalarm/features/onboarding/presentation/cubits/onboarding_welcome_cubit.dart';
import 'package:critalarm/features/topics/data/repositories/in_memory_topic_repository.dart';
import 'package:critalarm/features/topics/domain/repositories/topic_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late MockServer server;
  late MockApiClient apiClient;
  late TopicRepository topicRepo;
  late IncidentRepository incidentRepo;
  late ServerRepository serverRepo;

  setUp(() {
    server = MockServer();
    apiClient = MockApiClient(server);
    topicRepo = InMemoryTopicRepository(apiClient);
    incidentRepo = InMemoryIncidentRepository(apiClient);
    serverRepo = InMemoryServerRepository(apiClient);
  });

  group('InMemoryTopicRepository', () {
    test('createTopic returns Success with Topic and token', () async {
      final result = await topicRepo.createTopic(name: 'prod-db');

      expect(result.isSuccess(), isTrue);
      final topic = result.getOrNull()!;
      expect(topic.name, 'prod-db');
      expect(topic.critical, isFalse);
      expect(topic.token, isNotNull);
    });

    test('getTopics returns Success with list', () async {
      await topicRepo.createTopic(name: 'nas');
      final result = await topicRepo.getTopics();

      expect(result.isSuccess(), isTrue);
      final list = result.getOrNull()!;
      expect(list, hasLength(1));
      expect(list.first.token, isNull);
    });

    test('updateTopic returns Success with updated fields', () async {
      await topicRepo.createTopic(name: 'kuma');
      final result = await topicRepo.updateTopic('kuma', critical: true);

      expect(result.isSuccess(), isTrue);
      expect(result.getOrNull()!.critical, isTrue);
    });

    test('deleteTopic returns Success with Unit', () async {
      await topicRepo.createTopic(name: 'temp');
      final delResult = await topicRepo.deleteTopic('temp');
      expect(delResult.isSuccess(), isTrue);

      final listResult = await topicRepo.getTopics();
      expect(listResult.getOrNull(), isEmpty);
    });

    test(
      'createTopic with invalid name returns Failure.api(statusCode: 400)',
      () async {
        final result = await topicRepo.createTopic(name: 'invalid name!');

        expect(result.isError(), isTrue);
        final failure = result.exceptionOrNull()!;
        expect(failure, isA<ApiFailure>());
        expect((failure as ApiFailure).statusCode, 400);
      },
    );
  });

  group('InMemoryIncidentRepository', () {
    test('publishMessage and lifecycle transitions return Success', () async {
      await topicRepo.createTopic(name: 'alerts', critical: true);

      final pubResult = await incidentRepo.publishMessage(
        'alerts',
        title: 'Alarm test',
        priority: 5,
      );
      expect(pubResult.isSuccess(), isTrue);
      final incidentId = pubResult.getOrNull()!.incidentId!;

      // Ack
      final ackResult = await incidentRepo.ackIncident(incidentId);
      expect(ackResult.isSuccess(), isTrue);
      expect(ackResult.getOrNull()!.state, IncidentStates.acked);

      // Close
      final closeResult = await incidentRepo.closeIncident(incidentId);
      expect(closeResult.isSuccess(), isTrue);
      expect(closeResult.getOrNull()!.state, IncidentStates.closed);
    });

    test(
      'invalid ack transition returns Failure.api(statusCode: 409)',
      () async {
        await topicRepo.createTopic(name: 'alerts', critical: true);
        final pubResult = await incidentRepo.publishMessage(
          'alerts',
          priority: 5,
        );
        final incidentId = pubResult.getOrNull()!.incidentId!;

        // Ack first time
        await incidentRepo.ackIncident(incidentId);

        // Ack second time -> 409
        final invalidAck = await incidentRepo.ackIncident(incidentId);
        expect(invalidAck.isError(), isTrue);
        final failure = invalidAck.exceptionOrNull()!;
        expect(failure, isA<ApiFailure>());
        expect((failure as ApiFailure).statusCode, 409);
      },
    );

    test(
      'triggerTest on non-critical topic returns Failure.api(409)',
      () async {
        await topicRepo.createTopic(name: 'not-crit');

        final result = await incidentRepo.triggerTest(topic: 'not-crit');
        expect(result.isError(), isTrue);
        final failure = result.exceptionOrNull()!;
        expect(failure, isA<ApiFailure>());
        expect((failure as ApiFailure).statusCode, 409);
      },
    );
  });

  group('InMemoryServerRepository', () {
    test('getServerInfo returns Success with ServerInfo', () async {
      final result = await serverRepo.getServerInfo();

      expect(result.isSuccess(), isTrue);
      final info = result.getOrNull()!;
      expect(info.name, 'critalarm');
      expect(info.version, '0.1.0');
    });

    test(
      'registerDevice returns Success with DeviceRegistrationResponse',
      () async {
        const reg = DeviceRegistration(
          deviceId: 'dev_repo_test',
          platform: 'ios',
          pushToken: 'token_abc',
          appVersion: '1.0.0',
        );

        final result = await serverRepo.registerDevice(reg);

        expect(result.isSuccess(), isTrue);
        final response = result.getOrNull()!;
        expect(response.accountId, isNotEmpty);
        expect(response.deviceToken, isNotEmpty);
      },
    );
  });

  group('DI Configuration (di.dart)', () {
    test('registers all repositories and services cleanly', () async {
      SharedPreferences.setMockInitialValues({});
      await getIt.reset();
      await configureDependencies();

      expect(getIt.isRegistered<MockServer>(), isTrue);
      expect(getIt.isRegistered<MockApiClient>(), isTrue);
      expect(getIt.isRegistered<ApiClient>(), isTrue);
      expect(getIt.isRegistered<TopicRepository>(), isTrue);
      expect(getIt.isRegistered<IncidentRepository>(), isTrue);
      expect(getIt.isRegistered<ServerRepository>(), isTrue);
      expect(getIt.isRegistered<GetServerInfoUsecase>(), isTrue);
      expect(getIt.isRegistered<TriggerTestAlarmUsecase>(), isTrue);
      expect(getIt.isRegistered<OnboardingWelcomeCubit>(), isTrue);
      expect(getIt.isRegistered<OnboardingPermissionsCubit>(), isTrue);

      final client = getIt<ApiClient>();
      expect(client, isA<MockApiClient>());

      final topics = await getIt<TopicRepository>().getTopics();
      expect(topics.isSuccess(), isTrue);
    });
  });
}
