import 'package:critalarm/core/account/account_identity_changes.dart';
import 'package:critalarm/core/account/plan_changes.dart';
import 'package:critalarm/core/api/packs_api.dart';
import 'package:critalarm/core/paywall/paywall_build_mode.dart';
import 'package:critalarm/core/storage/api_session_store.dart';
import 'package:critalarm/core/storage/device_identity_store.dart';
import 'package:critalarm/features/paywall/data/services/revenuecat_service.dart';
import 'package:critalarm/features/pro_pack/data/revenuecat_pro_pack_shop.dart';
import 'package:critalarm/features/pro_pack/data/shared_prefs_pro_pack_store.dart';
import 'package:critalarm/features/pro_pack/domain/pro_pack_access.dart';
import 'package:critalarm/features/pro_pack/domain/pro_pack_shop.dart';
import 'package:critalarm/features/pro_pack/domain/pro_pack_store.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The Pro pack store and what the phone holds of it.
void registerProPackAccess(GetIt getIt) {
  getIt
    ..registerLazySingleton<ProPackStore>(
      () => SharedPrefsProPackStore(getIt<SharedPreferences>()),
    )
    ..registerLazySingleton<ProPackAccess>(
      () => ProPackAccess(
        api: getIt<PacksApi>(),
        store: getIt<ProPackStore>(),
        readAccountId: () async =>
            (await getIt<DeviceIdentityStore>().readOrCreate()).accountId,
        // The kept list is for one account on one relay. A sign-out, a
        // sign-in or a new plan is a reason to look at who this phone is.
        readRelay: () async =>
            (await getIt<ApiSessionStore>().read())?.relayUri,
        identityChanges: [appAccountIdentityChanges, appPlanChanges],
      ),
    );
}

/// What the Pro pack is bought through.
void registerProPackShop(GetIt getIt) {
  // A build that skips the store has nothing on sale.
  getIt.registerLazySingleton<ProPackShop>(
    () => buildSkipsPaywall
        ? const ClosedProPackShop()
        : RevenueCatProPackShop(getIt<RevenueCatService>()),
  );
}
