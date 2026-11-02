import 'dart:async';
import 'package:critalarm/app/di/di_reads.dart';
import 'package:critalarm/core/access/app_feature.dart';
import 'package:critalarm/core/access/feature_access.dart';
import 'package:critalarm/core/api/weekly_check_api.dart';
import 'package:critalarm/core/storage/device_identity_store.dart';
import 'package:critalarm/core/version/app_version.dart';
import 'package:critalarm/features/onboarding/domain/usecases/register_device_usecase.dart';
import 'package:critalarm/features/reliability/domain/proof/proof_log.dart';
import 'package:critalarm/features/weekly_check/data/shared_prefs_weekly_check_store.dart';
import 'package:critalarm/features/weekly_check/domain/weekly_check_monitor.dart';
import 'package:critalarm/features/weekly_check/domain/weekly_check_store.dart';
import 'package:critalarm/features/weekly_check/presentation/cubits/weekly_check_cubit.dart';
import 'package:critalarm/features/weekly_check/presentation/cubits/weekly_check_rounds_cubit.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The weekly check store, monitor and cubits.
void registerWeeklyCheck(GetIt getIt) {
  getIt
    ..registerLazySingleton<WeeklyCheckStore>(
      () => SharedPrefsWeeklyCheckStore(getIt<SharedPreferences>()),
    )
    ..registerLazySingleton<WeeklyCheckMonitor>(() {
      final monitor = WeeklyCheckMonitor(
        api: getIt<WeeklyCheckApi>(),
        store: getIt<WeeklyCheckStore>(),
        readDeviceId: () async =>
            (await getIt<DeviceIdentityStore>().readOrCreate()).deviceId,
        readAccess: weeklyCheckAccessReader(getIt),
        proofLog: getIt<ProofLog>(),
        // The relay says the account is not on Hosted. A registration
        // brings the tier the relay holds now, and the Hosted source reads
        // it from the saved identity.
        onTierRefused: () async {
          await getIt<RegisterDeviceUsecase>()(appVersion: appVersion);
        },
      );
      // Hosted bought, lapsed or back, or another kind of server: each
      // changes what the relay sends this phone, so the check is read
      // again at once. On a server of the user's own this is also what
      // tells the relay to stop. Nothing waits on it.
      getIt<FeatureAccess>().changes
          .where((feature) => feature == AppFeature.weeklyCheck)
          .listen((_) => unawaited(monitor.accessChanged()));
      return monitor;
    })
    ..registerLazySingleton<WeeklyCheckCubit>(
      () => WeeklyCheckCubit(monitor: getIt<WeeklyCheckMonitor>()),
    )
    ..registerFactory(() => WeeklyCheckRoundsCubit(getIt<WeeklyCheckApi>()));
}
