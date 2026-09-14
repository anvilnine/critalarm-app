import 'package:critalarm/app/initial_route_resolver.dart';
import 'package:critalarm/app/shell/shell_cubit.dart';
import 'package:critalarm/core/ack/ack_queue.dart';
import 'package:critalarm/core/alarm/alarm_host.dart';
import 'package:critalarm/core/alarm/incident_alarm_controller.dart';
import 'package:critalarm/core/alarm/live_activity_token_registry.dart';
import 'package:critalarm/core/api/api_build_mode.dart';
import 'package:critalarm/core/api/api_client.dart';
import 'package:critalarm/core/api/http_api_client.dart';
import 'package:critalarm/core/api/mock_api_client.dart';
import 'package:critalarm/core/api/mock_server.dart';
import 'package:critalarm/core/env/env.dart';
import 'package:critalarm/core/notifications/app_badge.dart';
import 'package:critalarm/core/paywall/paywall_build_mode.dart';
import 'package:critalarm/core/push/apns_push_token_provider.dart';
import 'package:critalarm/core/push/firebase_push_token_provider.dart';
import 'package:critalarm/core/push/push_event_drain.dart';
import 'package:critalarm/core/push/push_host.dart';
import 'package:critalarm/core/push/push_token_provider.dart';
import 'package:critalarm/core/sound/sound_host.dart';
import 'package:critalarm/core/storage/api_session_store.dart';
import 'package:critalarm/core/storage/device_identity_store.dart';
import 'package:critalarm/core/storage/nse_credential_store.dart';
import 'package:critalarm/core/storage/shared_prefs_api_session_store.dart';
import 'package:critalarm/core/sync/message_sync_service.dart';
import 'package:critalarm/core/telemetry/analytics_events.dart';
import 'package:critalarm/core/telemetry/firebase_telemetry_gate.dart';
import 'package:critalarm/core/telemetry/telemetry_gate.dart';
import 'package:critalarm/core/version/app_version.dart';
import 'package:critalarm/features/history/presentation/cubits/history_cubit.dart';
import 'package:critalarm/features/incidents/data/repositories/in_memory_incident_repository.dart';
import 'package:critalarm/features/incidents/domain/repositories/incident_repository.dart';
import 'package:critalarm/features/incidents/domain/usecases/acknowledge_incident_usecase.dart';
import 'package:critalarm/features/incidents/domain/usecases/close_incident_usecase.dart';
import 'package:critalarm/features/incidents/domain/usecases/get_incident_usecase.dart';
import 'package:critalarm/features/incidents/domain/usecases/get_incidents_usecase.dart';
import 'package:critalarm/features/incidents/domain/usecases/trigger_test_alarm_usecase.dart';
import 'package:critalarm/features/incidents/domain/usecases/update_incident_badge_usecase.dart';
import 'package:critalarm/features/incidents/presentation/cubits/critical_alarm_cubit.dart';
import 'package:critalarm/features/incidents/presentation/cubits/lock_screen_cubit.dart';
import 'package:critalarm/features/onboarding/data/repositories/in_memory_server_repository.dart';
import 'package:critalarm/features/onboarding/data/repositories/keychain_mirror_connection_repository.dart';
import 'package:critalarm/features/onboarding/data/repositories/platform_notification_permission_repository.dart';
import 'package:critalarm/features/onboarding/data/repositories/shared_prefs_connection_repository.dart';
import 'package:critalarm/features/onboarding/data/repositories/shared_prefs_onboarding_progress_repository.dart';
import 'package:critalarm/features/onboarding/domain/repositories/connection_repository.dart';
import 'package:critalarm/features/onboarding/domain/repositories/notification_permission_repository.dart';
import 'package:critalarm/features/onboarding/domain/repositories/onboarding_progress_repository.dart';
import 'package:critalarm/features/onboarding/domain/repositories/server_repository.dart';
import 'package:critalarm/features/onboarding/domain/usecases/clear_connection_usecase.dart';
import 'package:critalarm/features/onboarding/domain/usecases/complete_onboarding_usecase.dart';
import 'package:critalarm/features/onboarding/domain/usecases/device_token_registry.dart';
import 'package:critalarm/features/onboarding/domain/usecases/get_connection_usecase.dart';
import 'package:critalarm/features/onboarding/domain/usecases/get_onboarding_completed_usecase.dart';
import 'package:critalarm/features/onboarding/domain/usecases/get_server_info_usecase.dart';
import 'package:critalarm/features/onboarding/domain/usecases/open_notification_settings_usecase.dart';
import 'package:critalarm/features/onboarding/domain/usecases/register_device_usecase.dart';
import 'package:critalarm/features/onboarding/domain/usecases/request_notification_permission_usecase.dart';
import 'package:critalarm/features/onboarding/domain/usecases/save_connection_usecase.dart';
import 'package:critalarm/features/onboarding/presentation/cubits/notification_permissions_cubit.dart';
import 'package:critalarm/features/onboarding/presentation/cubits/notification_permissions_state.dart';
import 'package:critalarm/features/onboarding/presentation/cubits/onboarding_connect_cubit.dart';
import 'package:critalarm/features/onboarding/presentation/cubits/onboarding_permissions_cubit.dart';
import 'package:critalarm/features/onboarding/presentation/cubits/onboarding_welcome_cubit.dart';
import 'package:critalarm/features/paywall/data/repositories/in_memory_subscription_repository.dart';
import 'package:critalarm/features/paywall/data/repositories/revenuecat_subscription_repository.dart';
import 'package:critalarm/features/paywall/data/services/revenuecat_service.dart';
import 'package:critalarm/features/paywall/domain/repositories/subscription_repository.dart';
import 'package:critalarm/features/paywall/domain/usecases/check_pro_entitlement_usecase.dart';
import 'package:critalarm/features/paywall/domain/usecases/get_customer_info_usecase.dart';
import 'package:critalarm/features/paywall/domain/usecases/get_offerings_usecase.dart';
import 'package:critalarm/features/paywall/domain/usecases/purchase_package_usecase.dart';
import 'package:critalarm/features/paywall/domain/usecases/restore_purchases_usecase.dart';
import 'package:critalarm/features/paywall/presentation/cubits/paywall_cubit.dart';
import 'package:critalarm/features/permissions/data/repositories/platform_device_permissions_repository.dart';
import 'package:critalarm/features/permissions/domain/repositories/device_permissions_repository.dart';
import 'package:critalarm/features/permissions/domain/usecases/get_device_permissions_usecase.dart';
import 'package:critalarm/features/permissions/domain/usecases/open_permission_settings_usecase.dart';
import 'package:critalarm/features/permissions/presentation/cubits/device_permissions_cubit.dart';
import 'package:critalarm/features/settings/data/repositories/shared_prefs_alarm_sound_repository.dart';
import 'package:critalarm/features/settings/data/repositories/shared_prefs_privacy_repository.dart';
import 'package:critalarm/features/settings/data/repositories/shared_prefs_theme_preference_repository.dart';
import 'package:critalarm/features/settings/data/services/sound_file_picker.dart';
import 'package:critalarm/features/settings/domain/repositories/alarm_sound_repository.dart';
import 'package:critalarm/features/settings/domain/repositories/privacy_repository.dart';
import 'package:critalarm/features/settings/domain/repositories/sound_file_picker.dart';
import 'package:critalarm/features/settings/domain/repositories/theme_preference_repository.dart';
import 'package:critalarm/features/settings/domain/usecases/delete_user_sound_usecase.dart';
import 'package:critalarm/features/settings/domain/usecases/get_privacy_settings_usecase.dart';
import 'package:critalarm/features/settings/domain/usecases/get_theme_mode_usecase.dart';
import 'package:critalarm/features/settings/domain/usecases/import_sound_usecase.dart';
import 'package:critalarm/features/settings/domain/usecases/set_analytics_enabled_usecase.dart';
import 'package:critalarm/features/settings/domain/usecases/set_crash_reporting_enabled_usecase.dart';
import 'package:critalarm/features/settings/domain/usecases/set_theme_mode_usecase.dart';
import 'package:critalarm/features/settings/presentation/cubits/settings_cubit.dart';
import 'package:critalarm/features/settings/presentation/cubits/sound_picker_cubit.dart';
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
import 'package:critalarm/firebase_options.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

final GetIt getIt = GetIt.instance;

/// Composition root. Registration order is: platform singletons, then
/// repositories, then usecases, then cubits. Keep it in that order as features
/// land so a missing dependency is obvious from where the call sits.
Future<void> configureDependencies({
  bool useMockApi = buildUsesMockApi,
  http.Client? httpClient,
}) async {
  final prefs = await SharedPreferences.getInstance();

  if (!getIt.isRegistered<TelemetryGate>()) {
    final options = () {
      try {
        return DefaultFirebaseOptions.currentPlatform;
      } on Object catch (_) {
        return null;
      }
    }();
    final telemetryGate = FirebaseTelemetryGate(options: options);
    await telemetryGate.initialize();
    getIt.registerSingleton<TelemetryGate>(telemetryGate);
  }

  if (!getIt.isRegistered<RevenueCatService>()) {
    final revenueCatService = RevenueCatService();
    try {
      if (!buildSkipsPaywall && Env.revenueCatApiKey.isNotEmpty) {
        await revenueCatService.initialize(apiKey: Env.revenueCatApiKey);
      }
    } on Object catch (_) {
      // Ignored for tests or unsupported environments
    }
    getIt.registerSingleton<RevenueCatService>(revenueCatService);
  }

  getIt
    ..registerSingleton<SharedPreferences>(prefs)
    ..registerLazySingleton<PushHost>(PushHost.new)
    ..registerLazySingleton<NseCredentialStore>(NseCredentialStore.new)
    ..registerLazySingleton<AppBadge>(() => AppBadge(getIt<PushHost>()))
    ..registerLazySingleton<ApiSessionStore>(
      () => SharedPrefsApiSessionStore(getIt<SharedPreferences>()),
    )
    ..registerLazySingleton<DeviceIdentityStore>(
      () => DeviceIdentityStore(getIt<SharedPreferences>()),
    )
    // api.md §5.1 has the relay pushing to APNs itself, so iOS registers the
    // raw APNs token. Android registers the FCM one (§5.2).
    ..registerLazySingleton<PushTokenProvider>(
      () => defaultTargetPlatform == TargetPlatform.iOS
          ? ApnsPushTokenProvider(getIt<PushHost>())
          : FirebasePushTokenProvider(),
    )
    ..registerLazySingleton<MockServer>(() => MockServer()..seedCalm())
    ..registerLazySingleton<MockApiClient>(
      () => MockApiClient(getIt<MockServer>()),
    )
    ..registerLazySingleton<ApiClient>(
      () => useMockApi
          ? getIt<MockApiClient>()
          : HttpApiClient(
              httpClient ?? http.Client(),
              getIt<ApiSessionStore>(),
            ),
    )
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
    // The iOS extension reads the server and the token out of the keychain,
    // so saving a connection has to land there too.
    ..registerLazySingleton<ConnectionRepository>(
      () => KeychainMirrorConnectionRepository(
        SharedPrefsConnectionRepository(getIt<SharedPreferences>()),
        getIt<NseCredentialStore>(),
      ),
    )
    ..registerLazySingleton<OnboardingProgressRepository>(
      () => SharedPrefsOnboardingProgressRepository(getIt<SharedPreferences>()),
    )
    ..registerLazySingleton<PrivacyRepository>(
      () => SharedPrefsPrivacyRepository(getIt<SharedPreferences>()),
    )
    ..registerLazySingleton<AlarmSoundRepository>(
      () => SharedPrefsAlarmSoundRepository(getIt<SharedPreferences>()),
    )
    ..registerLazySingleton<SoundHost>(SoundHost.new)
    ..registerLazySingleton<SoundFilePicker>(PlatformSoundFilePicker.new)
    ..registerLazySingleton<NotificationPermissionRepository>(
      PlatformNotificationPermissionRepository.new,
    )
    ..registerLazySingleton<DevicePermissionsRepository>(
      PlatformDevicePermissionsRepository.new,
    )
    ..registerLazySingleton<SubscriptionRepository>(
      () => buildSkipsPaywall
          ? InMemorySubscriptionRepository()
          : RevenueCatSubscriptionRepository(getIt<RevenueCatService>()),
    )
    ..registerLazySingleton(
      () => GetDevicePermissionsUsecase(
        getIt<DevicePermissionsRepository>(),
      ),
    )
    ..registerLazySingleton(
      () => OpenPermissionSettingsUsecase(
        getIt<DevicePermissionsRepository>(),
      ),
    )
    ..registerLazySingleton(
      () => RequestNotificationPermissionUsecase(
        getIt<NotificationPermissionRepository>(),
      ),
    )
    ..registerLazySingleton(
      () => OpenNotificationSettingsUsecase(
        getIt<NotificationPermissionRepository>(),
      ),
    )
    ..registerLazySingleton(
      () => SaveConnectionUsecase(getIt<ConnectionRepository>()),
    )
    ..registerLazySingleton(
      () => RegisterDeviceUsecase(
        getIt<ApiClient>(),
        getIt<DeviceIdentityStore>(),
        getIt<PushTokenProvider>(),
      ),
    )
    ..registerLazySingleton(
      () => DeviceTokenRegistry(
        prefs: getIt<SharedPreferences>(),
        register: getIt<RegisterDeviceUsecase>(),
        tokens: getIt<PushTokenProvider>(),
        appVersion: appVersion,
      ),
    )
    ..registerLazySingleton<AlarmHost>(AlarmHost.new)
    ..registerLazySingleton(
      () => LiveActivityTokenRegistry(
        prefs: getIt<SharedPreferences>(),
        api: getIt<ApiClient>(),
        identity: getIt<DeviceIdentityStore>(),
        host: getIt<AlarmHost>(),
      ),
    )
    ..registerLazySingleton(
      () => IncidentAlarmController(
        host: getIt<AlarmHost>(),
        api: getIt<ApiClient>(),
        tokens: getIt<LiveActivityTokenRegistry>(),
      ),
    )
    ..registerLazySingleton(() => PushAnalytics(getIt<TelemetryGate>()))
    ..registerLazySingleton(
      () => PushEventDrain(getIt<SharedPreferences>(), getIt<TelemetryGate>()),
    )
    ..registerLazySingleton(
      () => AckQueue(
        getIt<SharedPreferences>(),
        getIt<ApiClient>(),
        analytics: getIt<PushAnalytics>(),
      ),
    )
    ..registerLazySingleton(
      () => MessageSyncService(getIt<SharedPreferences>(), getIt<ApiClient>()),
    )
    ..registerLazySingleton(
      () => GetConnectionUsecase(getIt<ConnectionRepository>()),
    )
    ..registerLazySingleton(
      () =>
          GetOnboardingCompletedUsecase(getIt<OnboardingProgressRepository>()),
    )
    ..registerLazySingleton(
      () => CompleteOnboardingUsecase(getIt<OnboardingProgressRepository>()),
    )
    ..registerLazySingleton(
      () => InitialRouteResolver(
        getIt<GetConnectionUsecase>(),
        getIt<GetOnboardingCompletedUsecase>(),
      ),
    )
    ..registerLazySingleton(
      () => ClearConnectionUsecase(getIt<ConnectionRepository>()),
    )
    ..registerLazySingleton(
      () => GetPrivacySettingsUsecase(getIt<PrivacyRepository>()),
    )
    ..registerLazySingleton(
      () => SetAnalyticsEnabledUsecase(getIt<PrivacyRepository>()),
    )
    ..registerLazySingleton(
      () => SetCrashReportingEnabledUsecase(getIt<PrivacyRepository>()),
    )
    ..registerLazySingleton(
      () => GetThemeModeUsecase(getIt<ThemePreferenceRepository>()),
    )
    ..registerLazySingleton(
      () => SetThemeModeUsecase(getIt<ThemePreferenceRepository>()),
    )
    ..registerLazySingleton(
      () => ImportSoundUsecase(
        getIt<AlarmSoundRepository>(),
        getIt<SoundHost>(),
      ),
    )
    ..registerLazySingleton(
      () => DeleteUserSoundUsecase(
        getIt<AlarmSoundRepository>(),
        getIt<SoundHost>(),
      ),
    )
    ..registerLazySingleton(
      () => GetServerInfoUsecase(getIt<ServerRepository>()),
    )
    ..registerLazySingleton(
      () => TriggerTestAlarmUsecase(getIt<IncidentRepository>()),
    )
    ..registerLazySingleton(
      () => GetIncidentsUsecase(getIt<IncidentRepository>()),
    )
    ..registerLazySingleton(
      () => UpdateIncidentBadgeUsecase(
        getIt<IncidentRepository>(),
        getIt<AppBadge>(),
      ),
    )
    ..registerLazySingleton(
      () => GetIncidentUsecase(getIt<IncidentRepository>()),
    )
    ..registerLazySingleton(
      () => AcknowledgeIncidentUsecase(getIt<IncidentRepository>()),
    )
    ..registerLazySingleton(
      () => CloseIncidentUsecase(getIt<IncidentRepository>()),
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
    ..registerLazySingleton(
      () => CheckProEntitlementUsecase(getIt<SubscriptionRepository>()),
    )
    ..registerLazySingleton(
      () => GetOfferingsUsecase(getIt<SubscriptionRepository>()),
    )
    ..registerLazySingleton(
      () => PurchasePackageUsecase(getIt<SubscriptionRepository>()),
    )
    ..registerLazySingleton(
      () => RestorePurchasesUsecase(getIt<SubscriptionRepository>()),
    )
    ..registerLazySingleton(
      () => GetCustomerInfoUsecase(getIt<SubscriptionRepository>()),
    )
    ..registerFactoryParam<
      NotificationPermissionsCubit,
      NotificationPermissionStep?,
      void
    >(
      (initialStep, _) => NotificationPermissionsCubit(
        getIt<RequestNotificationPermissionUsecase>(),
        getIt<OpenNotificationSettingsUsecase>(),
        alarm: getIt<AlarmHost>(),
        initialStep: initialStep ?? NotificationPermissionStep.initial,
      ),
    )
    ..registerFactoryParam<OnboardingConnectCubit, bool?, void>(
      (initialConnected, _) => OnboardingConnectCubit(
        getIt<GetServerInfoUsecase>(),
        getIt<SaveConnectionUsecase>(),
        getIt<TriggerTestAlarmUsecase>(),
        completeOnboarding: getIt<CompleteOnboardingUsecase>(),
        initialConnected: initialConnected ?? false,
      ),
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
        getIt<MessageSyncService>(),
        getIt<AppBadge>(),
      ),
    )
    ..registerFactory(
      () => ShellCubit(
        getIt<GetDevicePermissionsUsecase>(),
      ),
    )
    ..registerFactory(
      () => HistoryCubit(
        getIt<GetIncidentsUsecase>(),
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
        alarm: getIt<AlarmHost>(),
      ),
    )
    ..registerFactory(
      () => CreateTopicCubit(
        getIt<CreateTopicUsecase>(),
      ),
    )
    ..registerFactory(
      () => CriticalAlarmCubit(
        getIt<GetIncidentUsecase>(),
        getIt<GetIncidentsUsecase>(),
        getIt<AcknowledgeIncidentUsecase>(),
        getIt<CloseIncidentUsecase>(),
        getIt<UpdateIncidentBadgeUsecase>(),
      ),
    )
    ..registerFactory(
      () => LockScreenCubit(
        getIt<GetIncidentsUsecase>(),
      ),
    )
    ..registerFactory(
      () => SettingsCubit(
        getIt<GetTopicsUsecase>(),
        getConnectionUsecase: getIt<GetConnectionUsecase>(),
        clearConnectionUsecase: getIt<ClearConnectionUsecase>(),
        saveConnectionUsecase: getIt<SaveConnectionUsecase>(),
        getPrivacySettingsUsecase: getIt<GetPrivacySettingsUsecase>(),
        setAnalyticsEnabledUsecase: getIt<SetAnalyticsEnabledUsecase>(),
        setCrashReportingEnabledUsecase:
            getIt<SetCrashReportingEnabledUsecase>(),
        telemetryGate: getIt.isRegistered<TelemetryGate>()
            ? getIt<TelemetryGate>()
            : null,
      ),
    )
    ..registerFactory(
      () => SoundPickerCubit(
        getIt<AlarmSoundRepository>(),
        getIt<SoundHost>(),
        getIt<ImportSoundUsecase>(),
        getIt<DeleteUserSoundUsecase>(),
        getIt<SoundFilePicker>(),
        nameOf: (id) => 'sound_library.names.$id'.tr(),
      ),
    )
    ..registerFactory(
      () => DevicePermissionsCubit(
        getIt<GetDevicePermissionsUsecase>(),
        getIt<OpenPermissionSettingsUsecase>(),
      ),
    )
    ..registerFactory(
      () => PaywallCubit(
        telemetryGate: getIt.isRegistered<TelemetryGate>()
            ? getIt<TelemetryGate>()
            : null,
        checkProEntitlementUsecase: getIt<CheckProEntitlementUsecase>(),
        getOfferingsUsecase: getIt<GetOfferingsUsecase>(),
        purchasePackageUsecase: getIt<PurchasePackageUsecase>(),
        restorePurchasesUsecase: getIt<RestorePurchasesUsecase>(),
        getCustomerInfoUsecase: getIt<GetCustomerInfoUsecase>(),
        subscriptionRepository: getIt<SubscriptionRepository>(),
      ),
    );
}
