import 'package:critalarm/features/feature_guides/data/repositories/shared_prefs_feature_guide_repository.dart';
import 'package:critalarm/features/feature_guides/domain/repositories/feature_guide_repository.dart';
import 'package:critalarm/features/feature_guides/presentation/cubits/feature_guide_cubit.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The Feature Guide repository and its app-wide cubit.
void registerFeatureGuides(GetIt getIt) {
  getIt
    ..registerLazySingleton<FeatureGuideRepository>(
      () => SharedPrefsFeatureGuideRepository(getIt<SharedPreferences>()),
    )
    // One for the whole app: the full Feature Guides replay walks across
    // screens.
    ..registerLazySingleton(
      () => FeatureGuideCubit(getIt<FeatureGuideRepository>()),
    );
}
