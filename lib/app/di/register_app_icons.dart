import 'package:critalarm/app/access/hosted_holding_source.dart';
import 'package:critalarm/app/access/sure_lock.dart';
import 'package:critalarm/core/access/app_feature.dart';
import 'package:critalarm/core/access/feature_access.dart';
import 'package:critalarm/core/app_icon/app_icon_guard.dart';
import 'package:critalarm/core/app_icon/app_icon_host.dart';
import 'package:critalarm/features/settings/presentation/cubits/app_icon_cubit.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Set once a Pro device has seen the App icon welcome. Never cleared.
const _appIconWelcomedKey = 'app_icon.welcomed';

/// The app icon cubit, the lock it asks and the guard that puts the default
/// back.
void registerAppIcons(GetIt getIt) {
  getIt
    ..registerFactory(
      () => AppIconCubit(
        readCurrent: () => getIt<AppIconHost>().current(),
        apply: (icon) => getIt<AppIconHost>().set(icon),
        readUnlocked: () =>
            getIt<FeatureAccess>().canOnceReady(AppFeature.appIcons),
        unlockChanges: getIt<FeatureAccess>().changes.where(
          (feature) => feature == AppFeature.appIcons,
        ),
        readWelcomed: () async =>
            getIt<SharedPreferences>().getBool(_appIconWelcomedKey) ?? false,
        markWelcomed: () async {
          await getIt<SharedPreferences>().setBool(_appIconWelcomedKey, true);
        },
      ),
    )
    ..registerLazySingleton(
      () => SureLock(
        access: getIt<FeatureAccess>(),
        hosted: getIt<HostedHoldingSource>(),
      ),
    )
    // Puts the default icon back once the icons are locked again. The same
    // rule the picker draws its locks from, asked through SureLock: it
    // waits for the plan to be read and asks the store as well, because a
    // wrong switch costs the user their icon.
    ..registerLazySingleton(
      () => AppIconGuard(
        readCurrent: () => getIt<AppIconHost>().current(),
        apply: (icon) => getIt<AppIconHost>().set(icon),
        readUnlocked: () async =>
            !await getIt<SureLock>().isLocked(AppFeature.appIcons),
      ),
    );
}
