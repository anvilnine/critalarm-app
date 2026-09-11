import 'package:bloc_test/bloc_test.dart';
import 'package:critalarm/core/api/mock_api_client.dart';
import 'package:critalarm/core/api/mock_server.dart';
import 'package:critalarm/design/components/chips.dart';
import 'package:critalarm/features/settings/presentation/cubits/settings_cubit.dart';
import 'package:critalarm/features/settings/presentation/cubits/settings_state.dart';
import 'package:critalarm/features/topics/data/repositories/in_memory_topic_repository.dart';
import 'package:critalarm/features/topics/domain/repositories/topic_repository.dart';
import 'package:critalarm/features/topics/domain/usecases/get_topics_usecase.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late MockServer server;
  late MockApiClient apiClient;
  late TopicRepository topicRepo;
  late GetTopicsUsecase getTopicsUsecase;

  setUp(() {
    server = MockServer();
    apiClient = MockApiClient(server);
    topicRepo = InMemoryTopicRepository(apiClient);
    getTopicsUsecase = GetTopicsUsecase(topicRepo);
  });

  group('SettingsCubit', () {
    test('initial state matches design specs and mockup defaults', () {
      final cubit = SettingsCubit(getTopicsUsecase);

      expect(cubit.state.status, SettingsStatus.initial);
      expect(cubit.state.quietHoursEnabled, isTrue);
      expect(cubit.state.criticalRingsQuietHours, isTrue);
      expect(cubit.state.escalationCallEnabled, isFalse);
      expect(cubit.state.serverUrl, 'api.critalarm.app');
      expect(cubit.state.topics.length, 4);

      final topicMap = {
        for (final item in cubit.state.topics) item.name: item.priority,
      };
      expect(topicMap['prod-db'], PriorityLevel.critical);
      expect(topicMap['nas-backup'], PriorityLevel.high);
      expect(topicMap['uptime-kuma'], PriorityLevel.defaultPriority);
      expect(topicMap['home-ha'], PriorityLevel.low);
    });

    blocTest<SettingsCubit, SettingsState>(
      'loads topics from repository when seeded with calm fixture',
      setUp: () => server.seedCalm(),
      build: () => SettingsCubit(getTopicsUsecase),
      act: (cubit) => cubit.load(),
      expect: () => [
        const SettingsState(status: SettingsStatus.loading),
        isA<SettingsState>()
            .having((s) => s.status, 'status', SettingsStatus.success)
            .having((s) => s.topics.length, 'topics length', 4)
            .having(
              (s) => s.topics.firstWhere((t) => t.name == 'prod-db').priority,
              'prod-db critical',
              PriorityLevel.critical,
            )
            .having(
              (s) =>
                  s.topics.firstWhere((t) => t.name == 'nas-backup').priority,
              'nas-backup high',
              PriorityLevel.high,
            )
            .having(
              (s) =>
                  s.topics.firstWhere((t) => t.name == 'uptime-kuma').priority,
              'uptime-kuma defaultPriority',
              PriorityLevel.defaultPriority,
            )
            .having(
              (s) => s.topics.firstWhere((t) => t.name == 'home-ha').priority,
              'home-ha low',
              PriorityLevel.low,
            ),
      ],
    );

    blocTest<SettingsCubit, SettingsState>(
      'empty repository preserves default mockup topics',
      setUp: () => server.seedWatching(),
      build: () => SettingsCubit(getTopicsUsecase),
      act: (cubit) => cubit.load(),
      expect: () => [
        const SettingsState(status: SettingsStatus.loading),
        isA<SettingsState>()
            .having((s) => s.status, 'status', SettingsStatus.success)
            .having((s) => s.topics.length, 'topics count', 4),
      ],
    );

    blocTest<SettingsCubit, SettingsState>(
      'toggleQuietHours updates quietHoursEnabled',
      build: () => SettingsCubit(getTopicsUsecase),
      act: (cubit) => cubit.toggleQuietHours(isEnabled: false),
      expect: () => [
        isA<SettingsState>().having(
          (s) => s.quietHoursEnabled,
          'quietHoursEnabled',
          isFalse,
        ),
      ],
    );

    blocTest<SettingsCubit, SettingsState>(
      'toggleCriticalRingsQuietHours updates criticalRingsQuietHours',
      build: () => SettingsCubit(getTopicsUsecase),
      act: (cubit) => cubit.toggleCriticalRingsQuietHours(isEnabled: false),
      expect: () => [
        isA<SettingsState>().having(
          (s) => s.criticalRingsQuietHours,
          'criticalRingsQuietHours',
          isFalse,
        ),
      ],
    );

    blocTest<SettingsCubit, SettingsState>(
      'toggleEscalationCall updates escalationCallEnabled',
      build: () => SettingsCubit(getTopicsUsecase),
      act: (cubit) => cubit.toggleEscalationCall(isEnabled: true),
      expect: () => [
        isA<SettingsState>().having(
          (s) => s.escalationCallEnabled,
          'escalationCallEnabled',
          isTrue,
        ),
      ],
    );

    blocTest<SettingsCubit, SettingsState>(
      'setServerUrl updates serverUrl',
      build: () => SettingsCubit(getTopicsUsecase),
      act: (cubit) => cubit.setServerUrl('custom.alerts.io'),
      expect: () => [
        isA<SettingsState>().having(
          (s) => s.serverUrl,
          'serverUrl',
          'custom.alerts.io',
        ),
      ],
    );
  });
}
