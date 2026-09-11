import 'package:critalarm/core/api/api_client.dart';
import 'package:critalarm/core/api/mock_api_client.dart';
import 'package:critalarm/core/api/mock_server.dart';
import 'package:critalarm/features/incidents/data/repositories/in_memory_incident_repository.dart';
import 'package:critalarm/features/incidents/domain/repositories/incident_repository.dart';
import 'package:critalarm/features/incidents/domain/usecases/trigger_test_alarm_usecase.dart';
import 'package:critalarm/features/onboarding/data/repositories/in_memory_server_repository.dart';
import 'package:critalarm/features/onboarding/domain/repositories/server_repository.dart';
import 'package:critalarm/features/onboarding/domain/usecases/get_server_info_usecase.dart';
import 'package:critalarm/features/onboarding/presentation/cubits/onboarding_permissions_cubit.dart';
import 'package:critalarm/features/onboarding/presentation/cubits/onboarding_welcome_cubit.dart';
import 'package:critalarm/features/settings/data/repositories/shared_prefs_theme_preference_repository.dart';
import 'package:critalarm/features/settings/domain/repositories/theme_preference_repository.dart';
import 'package:critalarm/features/settings/domain/usecases/get_theme_mode_usecase.dart';
import 'package:critalarm/features/settings/domain/usecases/set_theme_mode_usecase.dart';
import 'package:critalarm/features/settings/presentation/cubits/theme_cubit.dart';
import 'package:critalarm/features/topics/data/repositories/in_memory_topic_repository.dart';
import 'package:critalarm/features/topics/domain/repositories/topic_repository.dart';
import 'package:critalarm/features/topics/domain/usecases/create_topic_usecase.dart';
import 'package:critalarm/features/topics/domain/usecases/delete_topic_usecase.dart';
import 'package:critalarm/features/topics/domain/usecases/get_topic_usecase.dart';
import 'package:critalarm/features/topics/domain/usecases/get_topics_usecase.dart';
import 'package:critalarm/features/topics/domain/usecases/update_topic_usecase.dart';
import 'package:critalarm/features/topics/presentation/cubits/create_topic_cubit.dart';
import 'package:critalarm/features/topics/presentation/cubits/home_cubit.dart';
import 'package:critalarm/features/topics/presentation/cubits/topic_detail_cubit.dart';
import 'package:critalarm/features/topics/presentation/cubits/topics_list_cubit.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

final GetIt getIt = GetIt.instance;

/// Composition root. Registration order is: platform singletons, then
/// repositories, then usecases, then cubits. Keep it in that order as features
/// land so a missing dependency is obvious from where the call sits.
Future<void> configureDependencies() async {
  final prefs = await SharedPreferences.getInstance();
  getIt
    ..registerSingleton<SharedPreferences>(prefs)
    ..registerLazySingleton<MockServer>(() => MockServer()..seedCalm())
    ..registerLazySingleton<MockApiClient>(
      () => MockApiClient(getIt<MockServer>()),
    )
    ..registerLazySingleton<ApiClient>(getIt.get<MockApiClient>)
    ..registerLazySingleton<ThemePreferenceRepository>(
      () => SharedPrefsThemePreferenceRepository(getIt<SharedPreferences>()),
    )
    ..registerLazySingleton<TopicRepository>(
      () => InMemoryTopicRepository(getIt<ApiClient>()),
    )
    ..registerLazySingleton<IncidentRepository>(
      () => InMemoryIncidentRepository(getIt<ApiClient>()),
    )
    ..registerLazySingleton<ServerRepository>(
      () => InMemoryServerRepository(getIt<ApiClient>()),
    )
    ..registerLazySingleton(
      () => GetThemeModeUsecase(getIt<ThemePreferenceRepository>()),
    )
    ..registerLazySingleton(
      () => SetThemeModeUsecase(getIt<ThemePreferenceRepository>()),
    )
    ..registerLazySingleton(
      () => GetServerInfoUsecase(getIt<ServerRepository>()),
    )
    ..registerLazySingleton(
      () => TriggerTestAlarmUsecase(getIt<IncidentRepository>()),
    )
    ..registerLazySingleton(
      () => GetTopicsUsecase(getIt<TopicRepository>()),
    )
    ..registerLazySingleton(
      () => GetTopicUsecase(getIt<TopicRepository>()),
    )
    ..registerLazySingleton(
      () => CreateTopicUsecase(getIt<TopicRepository>()),
    )
    ..registerLazySingleton(
      () => UpdateTopicUsecase(getIt<TopicRepository>()),
    )
    ..registerLazySingleton(
      () => DeleteTopicUsecase(getIt<TopicRepository>()),
    )
    ..registerFactory(
      () => ThemeCubit(
        getIt<GetThemeModeUsecase>(),
        getIt<SetThemeModeUsecase>(),
      ),
    )
    ..registerFactory(
      () => OnboardingWelcomeCubit(
        getIt<GetServerInfoUsecase>(),
      ),
    )
    ..registerFactory(
      () => OnboardingPermissionsCubit(
        getIt<TriggerTestAlarmUsecase>(),
      ),
    )
    ..registerFactory(
      () => HomeCubit(
        getIt<GetTopicsUsecase>(),
        getIt<IncidentRepository>(),
      ),
    )
    ..registerFactory(
      () => TopicsListCubit(
        getIt<GetTopicsUsecase>(),
        getIt<IncidentRepository>(),
      ),
    )
    ..registerFactory(
      () => TopicDetailCubit(
        getIt<GetTopicUsecase>(),
        getIt<UpdateTopicUsecase>(),
        getIt<IncidentRepository>(),
      ),
    )
    ..registerFactory(
      () => CreateTopicCubit(
        getIt<CreateTopicUsecase>(),
      ),
    );
}
