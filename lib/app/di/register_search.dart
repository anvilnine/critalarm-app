import 'package:critalarm/app/state/incidents_cubit.dart';
import 'package:critalarm/app/state/topics_cubit.dart';
import 'package:critalarm/core/paywall/paywall_build_mode.dart';
import 'package:critalarm/core/storage/api_session_store.dart';
import 'package:critalarm/features/language/presentation/language_cubit.dart';
import 'package:critalarm/features/search/data/repositories/asset_docs_index_repository.dart';
import 'package:critalarm/features/search/data/repositories/shared_prefs_recent_searches_repository.dart';
import 'package:critalarm/features/search/domain/repositories/docs_index_repository.dart';
import 'package:critalarm/features/search/domain/repositories/recent_searches_repository.dart';
import 'package:critalarm/features/search/domain/usecases/add_recent_search_usecase.dart';
import 'package:critalarm/features/search/domain/usecases/clear_recent_searches_usecase.dart';
import 'package:critalarm/features/search/domain/usecases/get_docs_index_usecase.dart';
import 'package:critalarm/features/search/domain/usecases/get_recent_searches_usecase.dart';
import 'package:critalarm/features/search/presentation/cubits/search_cubit.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The recent searches and the docs index.
void registerSearchRepositories(GetIt getIt) {
  getIt
    ..registerLazySingleton<RecentSearchesRepository>(
      () => SharedPrefsRecentSearchesRepository(getIt<SharedPreferences>()),
    )
    ..registerLazySingleton<DocsIndexRepository>(
      AssetDocsIndexRepository.new,
    );
}

/// The search usecases.
void registerSearchUsecases(GetIt getIt) {
  getIt
    ..registerLazySingleton(
      () => GetRecentSearchesUsecase(getIt<RecentSearchesRepository>()),
    )
    ..registerLazySingleton(
      () => AddRecentSearchUsecase(getIt<RecentSearchesRepository>()),
    )
    ..registerLazySingleton(
      () => ClearRecentSearchesUsecase(getIt<RecentSearchesRepository>()),
    )
    ..registerLazySingleton(
      () => GetDocsIndexUsecase(getIt<DocsIndexRepository>()),
    );
}

/// The search cubit.
void registerSearchCubit(GetIt getIt) {
  getIt.registerFactory(
    () => SearchCubit(
      localeChanges: getIt<LanguageCubit>().stream.map<void>((_) {}),
      sessionStore: getIt<ApiSessionStore>(),
      topics: getIt<TopicsCubit>(),
      incidents: getIt<IncidentsCubit>(),
      getDocsIndex: getIt<GetDocsIndexUsecase>(),
      getRecentSearches: getIt<GetRecentSearchesUsecase>(),
      addRecentSearch: getIt<AddRecentSearchUsecase>(),
      clearRecentSearches: getIt<ClearRecentSearchesUsecase>(),
      // A release build never offers the developer screen, so search must
      // never find it either.
      includeDevOnlySettings: buildSkipsPaywall || buildHasPaywallLab,
    ),
  );
}
