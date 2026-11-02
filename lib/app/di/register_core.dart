import 'package:critalarm/app/access/observed_api_session_store.dart';
import 'package:critalarm/app/held_account_scope.dart';
import 'package:critalarm/core/api/api_client.dart';
import 'package:critalarm/core/api/cancel_reason_api.dart';
import 'package:critalarm/core/api/http_api_client.dart';
import 'package:critalarm/core/api/mock_api_client.dart';
import 'package:critalarm/core/api/mock_server.dart';
import 'package:critalarm/core/api/packs_api.dart';
import 'package:critalarm/core/api/scoped_api_client.dart';
import 'package:critalarm/core/api/weekly_check_api.dart';
import 'package:critalarm/core/app_icon/app_icon_host.dart';
import 'package:critalarm/core/backup/backup_host.dart';
import 'package:critalarm/core/device/device_form.dart';
import 'package:critalarm/core/links/connect_link_holder.dart';
import 'package:critalarm/core/motion/motion_sensor.dart';
import 'package:critalarm/core/notifications/app_badge.dart';
import 'package:critalarm/core/platform/platform_capabilities.dart';
import 'package:critalarm/core/platform/store_kind.dart';
import 'package:critalarm/core/push/apns_push_token_provider.dart';
import 'package:critalarm/core/push/firebase_push_token_provider.dart';
import 'package:critalarm/core/push/push_host.dart';
import 'package:critalarm/core/push/push_token_provider.dart';
import 'package:critalarm/core/storage/api_session_store.dart';
import 'package:critalarm/core/storage/device_identity_store.dart';
import 'package:critalarm/core/storage/nse_credential_store.dart';
import 'package:critalarm/core/storage/shared_prefs_api_session_store.dart';
import 'package:critalarm/core/sync/message_sync_service.dart';
import 'package:critalarm/core/widgets/widget_host.dart';
import 'package:critalarm/features/account/domain/repositories/account_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// The platform values read once at launch and shared as they are.
void registerPlatformSingletons(
  GetIt getIt, {
  required SharedPreferences prefs,
  required PlatformCapabilities capabilities,
  required StoreKind store,
  required DeviceForm deviceForm,
}) {
  getIt
    ..registerSingleton<PlatformCapabilities>(capabilities)
    ..registerSingleton<StoreKind>(store)
    ..registerSingleton<SharedPreferences>(prefs)
    ..registerSingleton<DeviceForm>(deviceForm);
}

/// Native hosts, the session and identity stores, the backup host and the
/// push token provider.
void registerAppHosts(
  GetIt getIt, {
  required DeviceIdentityStore identityStore,
}) {
  // A connect link the user tapped waits here, in memory only, until a
  // screen takes it.
  getIt
    ..registerLazySingleton<ConnectLinkHolder>(ConnectLinkHolder.new)
    ..registerLazySingleton<PushHost>(
      () => PushHost(null, getIt<ConnectLinkHolder>()),
    )
    ..registerLazySingleton<NseCredentialStore>(NseCredentialStore.new)
    ..registerLazySingleton<WidgetHost>(WidgetHost.new)
    ..registerLazySingleton<AppIconHost>(AppIconHost.new)
    // The accelerometer, for the shake challenge. On the web and in a test
    // the channel has no native side, the stream says so, and the
    // challenge offers taps.
    ..registerLazySingleton<MotionSensor>(MotionSensorHost.new)
    ..registerLazySingleton<AppBadge>(() => AppBadge(getIt<PushHost>()))
    // The same store as before, wrapped so feature access hears the server
    // mode of every session that is read or written.
    ..registerLazySingleton<ObservedApiSessionStore>(
      () => ObservedApiSessionStore(
        SharedPrefsApiSessionStore(getIt<SharedPreferences>()),
      ),
    )
    ..registerLazySingleton<ApiSessionStore>(
      getIt.get<ObservedApiSessionStore>,
    )
    ..registerLazySingleton<DeviceIdentityStore>(
      () => identityStore,
    )
    // What the phone's backups do with this app. Only an iPhone restores
    // anything, so only an iPhone has something to ask.
    ..registerLazySingleton<BackupHost>(
      () => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS
          ? const ChannelBackupHost()
          : const NoBackupHost(),
    )
    // api.md §5.1 has the relay pushing to APNs itself, so iOS registers the
    // raw APNs token. Android registers the FCM one (§5.2).
    ..registerLazySingleton<PushTokenProvider>(
      () => defaultTargetPlatform == TargetPlatform.iOS
          ? ApnsPushTokenProvider(getIt<PushHost>())
          : FirebasePushTokenProvider(),
    );
}

/// The mock server, the mock client and the client every screen talks to,
/// plus the weekly check routes that live on it.
void registerApiClient(
  GetIt getIt, {
  required HeldAccountScope heldScope,
  required bool useMockApi,
  required http.Client? httpClient,
}) {
  getIt
    ..registerLazySingleton<MockServer>(() => MockServer()..seedCalm())
    ..registerLazySingleton<MockApiClient>(
      () => MockApiClient(getIt<MockServer>()),
    )
    // Every answer that carries incidents or messages is checked against the
    // account that asked: if the phone moved to another account while the
    // request was out, the call throws instead of handing it back.
    ..registerLazySingleton<ApiClient>(
      () => useMockApi
          ? getIt<MockApiClient>()
          : ScopedApiClient(
              HttpApiClient(
                httpClient ?? http.Client(),
                getIt<ApiSessionStore>(),
                // A 401 on this phone's own credential means somebody deleted
                // the account from another handset (api.md §3.7). Resolved
                // inside the closure, because the repository needs this
                // client.
                onDeadCredential: () =>
                    getIt<AccountRepository>().recoverFromDeadCredential(),
                readDeviceToken: () async =>
                    (await getIt<DeviceIdentityStore>().readOrCreate())
                        .deviceToken,
                readDeviceId: () async =>
                    (await getIt<DeviceIdentityStore>().readOrCreate())
                        .deviceId,
              ),
              readScope: heldScope.call,
            ),
    )
    // The weekly check routes live on the same client too.
    ..registerLazySingleton<WeeklyCheckApi>(() {
      final Object api = getIt<ApiClient>();
      return api is WeeklyCheckApi ? api : const NoWeeklyCheckApi();
    });
}

/// The pack and cancel reason routes that live on the same client as the rest.
void registerApiRoutes(GetIt getIt) {
  // The pack routes live on the same client. A client swapped in by a test
  // that does not speak them gets the one that always fails.
  getIt
    ..registerLazySingleton<PacksApi>(() {
      final Object api = getIt<ApiClient>();
      return api is PacksApi ? api : const NoPacksApi();
    })
    // The cancel reason route lives on the same client too.
    ..registerLazySingleton<CancelReasonApi>(() {
      final Object api = getIt<ApiClient>();
      return api is CancelReasonApi ? api : const NoCancelReasonApi();
    });
}

/// The message cursors.
void registerMessageSync(GetIt getIt) {
  getIt.registerLazySingleton(
    () => MessageSyncService(getIt<SharedPreferences>(), getIt<ApiClient>()),
  );
}
