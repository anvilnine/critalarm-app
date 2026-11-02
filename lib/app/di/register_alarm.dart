import 'package:critalarm/app/state/incidents_cubit.dart';
import 'package:critalarm/core/ack/ack_queue.dart';
import 'package:critalarm/core/alarm/alarm_host.dart';
import 'package:critalarm/core/alarm/alarm_signal_store.dart';
import 'package:critalarm/core/alarm/incident_alarm_controller.dart';
import 'package:critalarm/core/alarm/live_activity_token_registry.dart';
import 'package:critalarm/core/alarm/quiet_hours_store.dart';
import 'package:critalarm/core/alarm/ring_screen_host.dart';
import 'package:critalarm/core/api/api_client.dart';
import 'package:critalarm/core/net/launch_call_log.dart';
import 'package:critalarm/core/platform/off_platform_channel.dart';
import 'package:critalarm/core/platform/platform_capabilities.dart';
import 'package:critalarm/core/push/push_token_provider.dart';
import 'package:critalarm/core/push/relay_confirmation_store.dart';
import 'package:critalarm/core/storage/api_session_store.dart';
import 'package:critalarm/core/storage/device_identity_store.dart';
import 'package:critalarm/core/telemetry/analytics_events.dart';
import 'package:critalarm/core/version/app_version.dart';
import 'package:critalarm/features/onboarding/domain/usecases/device_token_registry.dart';
import 'package:critalarm/features/onboarding/domain/usecases/register_device_usecase.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The alarm host, its stores and the controller that rings from the shared
/// list.
void registerAlarmPath(GetIt getIt) {
  getIt
    ..registerLazySingleton<LaunchCallLog>(LaunchCallLog.new)
    ..registerLazySingleton(
      () => DeviceTokenRegistry(
        prefs: getIt<SharedPreferences>(),
        register: getIt<RegisterDeviceUsecase>(),
        tokens: getIt<PushTokenProvider>(),
        appVersion: appVersion,
        callLog: getIt<LaunchCallLog>(),
        confirmations: getIt<RelayConfirmationStore>(),
        // What a confirmation is about: this device, the relay of the saved
        // server and the token. No saved server, nothing to name.
        scopeFor: (token) async {
          final session = await getIt<ApiSessionStore>().read();
          if (session == null) return null;
          final identity = await getIt<DeviceIdentityStore>().readOrCreate();
          return RelayConfirmationScope.of(
            deviceId: identity.deviceId,
            relay: session.relayUri.toString(),
            token: token,
          );
        },
      ),
    )
    // AlarmKit and the Live Activity card on the iPhone, the alarm service on
    // Android. The Mac rings nothing yet, so it sends none of these calls.
    ..registerLazySingleton<AlarmHost>(
      () => AlarmHost(
        getIt<PlatformCapabilities>().hasSystemAlarmHost
            ? null
            : const OffPlatformChannel(AlarmHost.channelName),
      ),
    )
    // Off iOS it calls nothing, so the Mac and Android never reach it.
    ..registerLazySingleton<RingScreenHost>(
      () => RingScreenHost(isIos: getIt<PlatformCapabilities>().isIos),
    )
    ..registerLazySingleton<AlarmSignalStore>(
      () => AlarmSignalStore(getIt<SharedPreferences>()),
    )
    ..registerLazySingleton(
      () => LiveActivityTokenRegistry(
        prefs: getIt<SharedPreferences>(),
        api: getIt<ApiClient>(),
        identity: getIt<DeviceIdentityStore>(),
        host: getIt<AlarmHost>(),
        callLog: getIt<LaunchCallLog>(),
      ),
    )
    ..registerLazySingleton(
      () => QuietHoursStore(
        getIt<SharedPreferences>(),
        host: getIt<AlarmHost>(),
      ),
    )
    ..registerLazySingleton(
      () => IncidentAlarmController(
        host: getIt<AlarmHost>(),
        api: getIt<ApiClient>(),
        tokens: getIt<LiveActivityTokenRegistry>(),
        quietHours: getIt<QuietHoursStore>(),
        callLog: getIt<LaunchCallLog>(),
        applyIncident: getIt<IncidentsCubit>().applyIncident,
      ),
    );
}

/// The queue that sends acknowledgements.
void registerAckQueue(GetIt getIt) {
  getIt.registerLazySingleton(
    () => AckQueue(
      getIt<SharedPreferences>(),
      getIt<ApiClient>(),
      analytics: getIt<PushAnalytics>(),
      alarms: getIt<AlarmHost>(),
      // An acknowledge that only lands minutes later still has to move the
      // badge and every open screen, so the shared list catches up.
      onSent: () => getIt<IncidentsCubit>().refresh(),
    ),
  );
}
