import 'package:critalarm/app/initial_route_resolver.dart';
import 'package:critalarm/app/shell/shell_cubit.dart';
import 'package:critalarm/app/state/incidents_cubit.dart';
import 'package:critalarm/app/state/topics_cubit.dart';
import 'package:critalarm/core/account/account_identity_changes.dart';
import 'package:critalarm/core/ack/ack_queue.dart';
import 'package:critalarm/core/alarm/alarm_build_mode.dart';
import 'package:critalarm/core/alarm/alarm_host.dart';
import 'package:critalarm/core/alarm/incident_alarm_controller.dart';
import 'package:critalarm/core/alarm/live_activity_token_registry.dart';
import 'package:critalarm/core/alarm/quiet_hours_store.dart';
import 'package:critalarm/core/api/api_build_mode.dart';
import 'package:critalarm/core/api/api_client.dart';
import 'package:critalarm/core/api/http_api_client.dart';
import 'package:critalarm/core/api/mock_api_client.dart';
import 'package:critalarm/core/api/mock_server.dart';
import 'package:critalarm/core/env/env.dart';
import 'package:critalarm/core/notifications/app_badge.dart';
import 'package:critalarm/core/paywall/dev_pro_switch.dart';
import 'package:critalarm/core/paywall/paywall_build_mode.dart';
import 'package:critalarm/core/paywall/pro_override.dart';
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
import 'package:critalarm/features/account/data/repositories/api_account_repository.dart';
import 'package:critalarm/features/account/data/repositories/http_identity_repository.dart';
import 'package:critalarm/features/account/data/services/provider_sign_in.dart';
import 'package:critalarm/features/account/domain/repositories/account_repository.dart';
import 'package:critalarm/features/account/domain/repositories/identity_repository.dart';
import 'package:critalarm/features/account/presentation/cubits/account_cubit.dart';
import 'package:critalarm/features/history/presentation/cubits/history_cubit.dart';
import 'package:critalarm/features/incidents/data/repositories/in_memory_incident_repository.dart';
import 'package:critalarm/features/incidents/domain/repositories/incident_repository.dart';
import 'package:critalarm/features/incidents/domain/usecases/acknowledge_incident_usecase.dart';
import 'package:critalarm/features/incidents/domain/usecases/close_incident_usecase.dart';
import 'package:critalarm/features/incidents/domain/usecases/get_incident_usecase.dart';
import 'package:critalarm/features/incidents/domain/usecases/get_incidents_usecase.dart';
import 'package:critalarm/features/incidents/domain/usecases/trigger_test_alarm_usecase.dart';
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
import 'package:critalarm/features/onboarding/domain/usecases/check_notification_permission_usecase.dart';
import 'package:critalarm/features/onboarding/domain/usecases/clear_connection_usecase.dart';
import 'package:critalarm/features/onboarding/domain/usecases/complete_onboarding_usecase.dart';
import 'package:critalarm/features/onboarding/domain/usecases/device_token_registry.dart';
import 'package:critalarm/features/onboarding/domain/usecases/establish_api_session_usecase.dart';
import 'package:critalarm/features/onboarding/domain/usecases/get_connection_usecase.dart';
import 'package:critalarm/features/onboarding/domain/usecases/get_onboarding_completed_usecase.dart';
import 'package:critalarm/features/onboarding/domain/usecases/get_server_info_usecase.dart';
import 'package:critalarm/features/onboarding/domain/usecases/onboarding_draft_usecases.dart';
import 'package:critalarm/features/onboarding/domain/usecases/open_notification_settings_usecase.dart';
import 'package:critalarm/features/onboarding/domain/usecases/register_device_usecase.dart';
import 'package:critalarm/features/onboarding/domain/usecases/request_notification_permission_usecase.dart';
import 'package:critalarm/features/onboarding/domain/usecases/save_connection_usecase.dart';
import 'package:critalarm/features/onboarding/presentation/cubits/notification_permissions_cubit.dart';
import 'package:critalarm/features/onboarding/presentation/cubits/notification_permissions_state.dart';
import 'package:critalarm/features/onboarding/presentation/cubits/onboarding_connect_cubit.dart';
import 'package:critalarm/features/onboarding/presentation/cubits/onboarding_permissions_cubit.dart';
import 'package:critalarm/features/onboarding/presentation/cubits/onboarding_welcome_cubit.dart';
import 'package:critalarm/features/paywall/data/repositories/dev_subscription_repository.dart';
import 'package:critalarm/features/paywall/data/repositories/revenuecat_subscription_repository.dart';
import 'package:critalarm/features/paywall/data/services/revenuecat_service.dart';
import 'package:critalarm/features/paywall/domain/repositories/subscription_repository.dart';
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
import 'package:critalarm/features/prompts/data/repositories/shared_prefs_home_prompt_repository.dart';
import 'package:critalarm/features/prompts/domain/pro_prompt_rules.dart';
import 'package:critalarm/features/prompts/domain/repositories/home_prompt_repository.dart';
import 'package:critalarm/features/prompts/presentation/cubits/home_prompt_cubit.dart';
import 'package:critalarm/features/search/data/repositories/asset_docs_index_repository.dart';
import 'package:critalarm/features/search/data/repositories/shared_prefs_recent_searches_repository.dart';
import 'package:critalarm/features/search/domain/repositories/docs_index_repository.dart';
import 'package:critalarm/features/search/domain/repositories/recent_searches_repository.dart';
import 'package:critalarm/features/search/domain/usecases/add_recent_search_usecase.dart';
import 'package:critalarm/features/search/domain/usecases/clear_recent_searches_usecase.dart';
import 'package:critalarm/features/search/domain/usecases/get_docs_index_usecase.dart';
import 'package:critalarm/features/search/domain/usecases/get_recent_searches_usecase.dart';
import 'package:critalarm/features/search/presentation/cubits/search_cubit.dart';
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
import 'package:critalarm/features/topics/domain/usecases/get_topics_usecase.dart';
import 'package:critalarm/features/topics/domain/usecases/topic_token_usecases.dart';
import 'package:critalarm/features/topics/domain/usecases/update_topic_usecase.dart';
import 'package:critalarm/features/topics/presentation/cubits/create_topic_cubit.dart';
import 'package:critalarm/features/topics/presentation/cubits/home_cubit.dart';
import 'package:critalarm/features/topics/presentation/cubits/topic_detail_cubit.dart';
import 'package:critalarm/features/topics/presentation/cubits/topic_tokens_cubit.dart';
import 'package:critalarm/features/tour/data/repositories/shared_prefs_tour_repository.dart';
import 'package:critalarm/features/tour/domain/repositories/tour_repository.dart';
import 'package:critalarm/features/tour/presentation/cubits/tour_cubit.dart';
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

  // The alarm service runs with no Dart engine, so it reads this flag out of
  // the same preferences file rather than asking the app. Written on every
  // launch so a store build, where the constant is false, always clears it.
  await prefs.setBool('quiet_alarm', buildUsesQuietAlarm);

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

  if (buildSkipsPaywall) {
    if (!getIt.isRegistered<DevProSwitch>()) {
      getIt.registerSingleton<DevProSwitch>(DevProSwitch(prefs));
    }
    // The only place the switch is handed to the rest of the app. In a store
    // build appProOverride is a NoProOverride and this call does nothing.
    appProOverride.watch(getIt<DevProSwitch>());
  }

  final identityStore = DeviceIdentityStore.forPlatform(prefs);

  if (!getIt.isRegistered<RevenueCatService>()) {
    final revenueCatService = RevenueCatService();
    // RevenueCat issues a public SDK key per store and the SDK rejects the
    // other store's key, so the platform picks which one is passed.
    final sellsThroughAppStore =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
    final revenueCatKey = sellsThroughAppStore
        ? Env.revenueCatIosApiKey
        : Env.revenueCatAndroidApiKey;
    // Thrown above the catch below on purpose. A build that cannot sell has to
    // stop here, not be swallowed and look like a build nobody bought from.
    if (releaseBuildCannotSell(
      isRelease: kReleaseMode,
      skipsPaywall: buildSkipsPaywall,
      apiKey: revenueCatKey,
    )) {
      final varName = sellsThroughAppStore
          ? 'REVENUECAT_IOS_API_KEY'
          : 'REVENUECAT_ANDROID_API_KEY';
      throw StateError(
        'This release build has no RevenueCat key, so it cannot sell '
        'anything. Put $varName in .env. The key comes from RevenueCat, '
        'Project settings > API keys. Build with '
        '--dart-define=SKIP_PAYWALL=true if you meant to leave the paywall '
        'out.',
      );
    }
    try {
      if (!buildSkipsPaywall && revenueCatKey.isNotEmpty) {
        await revenueCatService.initialize(
          apiKey: revenueCatKey,
          appUserId: (await identityStore.readOrCreate()).accountId,
        );
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
      () => identityStore,
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
              // A 401 on this phone's own credential means somebody deleted
              // the account from another handset (api.md §3.7). Resolved
              // inside the closure, because the repository needs this client.
              onDeadCredential: () =>
                  getIt<AccountRepository>().recoverFromDeadCredential(),
            ),
    )
    ..registerLazySingleton<ThemePreferenceRepository>(
      () => SharedPrefsThemePreferenceRepository(getIt<SharedPreferences>()),
    )
    ..registerLazySingleton<TopicRepository>(
      () => InMemoryTopicRepository(
        getIt<ApiClient>(),
        sessions: getIt<ApiSessionStore>(),
        identity: getIt<DeviceIdentityStore>(),
        prefs: getIt<SharedPreferences>(),
      ),
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
      () => PlatformDevicePermissionsRepository(alarm: getIt<AlarmHost>()),
    )
    ..registerLazySingleton<SubscriptionRepository>(
      () => buildSkipsPaywall
          ? DevSubscriptionRepository(getIt<DevProSwitch>())
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
      () => CheckNotificationPermissionUsecase(
        getIt<NotificationPermissionRepository>(),
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
        identifyAccount: getIt<RevenueCatService>().identifyAccount,
      ),
    )
    ..registerLazySingleton(
      () => EstablishApiSessionUsecase(
        getIt<ApiSessionStore>(),
        getIt<RegisterDeviceUsecase>(),
        getIt<DeviceIdentityStore>(),
      ),
    )
    ..registerLazySingleton<ProviderSignIn>(NativeProviderSignIn.new)
    ..registerLazySingleton<IdentityRepository>(
      () => HttpIdentityRepository(
        httpClient: httpClient ?? http.Client(),
        sessions: getIt<ApiSessionStore>(),
        prefs: getIt<SharedPreferences>(),
        providers: getIt<ProviderSignIn>(),
        identityChanges: appAccountIdentityChanges,
      ),
    )
    ..registerLazySingleton<AccountRepository>(
      () => ApiAccountRepository(
        api: getIt<ApiClient>(),
        sessions: getIt<ApiSessionStore>(),
        devices: getIt<DeviceIdentityStore>(),
        register: getIt<RegisterDeviceUsecase>(),
        identities: getIt<IdentityRepository>(),
        connections: getIt<ConnectionRepository>(),
        acks: getIt<AckQueue>(),
        messageCursors: getIt<MessageSyncService>(),
        recentSearches: getIt<RecentSearchesRepository>(),
        signOutBilling: buildSkipsPaywall
            ? null
            : () => getIt<RevenueCatService>().logOut(),
        stopAlarm: getIt<AlarmHost>().stopRinging,
      ),
    )
    ..registerLazySingleton<HomePromptRepository>(
      () => SharedPrefsHomePromptRepository(getIt<SharedPreferences>()),
    )
    ..registerLazySingleton<ProPromptRules>(
      () => ProPromptRules(
        homePromptRepository: getIt<HomePromptRepository>(),
        accountRepository: getIt<AccountRepository>(),
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
        // An acknowledge that only lands minutes later still has to move the
        // badge and every open screen, so the shared list catches up.
        onSent: () => getIt<IncidentsCubit>().refresh(),
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
      () => ReadOnboardingDraftUsecase(getIt<OnboardingProgressRepository>()),
    )
    ..registerLazySingleton(
      () => SaveOnboardingDraftUsecase(getIt<OnboardingProgressRepository>()),
    )
    ..registerLazySingleton(
      () => ClearOnboardingDraftUsecase(getIt<OnboardingProgressRepository>()),
    )
    ..registerLazySingleton(
      () => InitialRouteResolver(
        getIt<GetOnboardingCompletedUsecase>(),
        getIt<ReadOnboardingDraftUsecase>(),
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
      () => GetIncidentUsecase(getIt<IncidentRepository>()),
    )
    // The two app-level cubits. Singletons, not factories: every screen has
    // to read and listen to the same instance or there is no shared state.
    ..registerLazySingleton(
      () => IncidentsCubit(
        getIt<GetIncidentsUsecase>(),
        badge: getIt<AppBadge>(),
      ),
    )
    ..registerLazySingleton(
      () => TopicsCubit(
        getIt<GetTopicsUsecase>(),
        deleteTopic: getIt<DeleteTopicUsecase>(),
        incidents: getIt<IncidentsCubit>(),
      ),
    )
    ..registerLazySingleton(
      () => AcknowledgeIncidentUsecase(getIt<IncidentRepository>()),
    )
    ..registerLazySingleton(
      () => CloseIncidentUsecase(getIt<IncidentRepository>()),
    )
    ..registerLazySingleton<RecentSearchesRepository>(
      () => SharedPrefsRecentSearchesRepository(getIt<SharedPreferences>()),
    )
    ..registerLazySingleton<DocsIndexRepository>(
      AssetDocsIndexRepository.new,
    )
    ..registerLazySingleton<TourRepository>(
      () => SharedPrefsTourRepository(getIt<SharedPreferences>()),
    )
    // One for the whole app: the tour walks across screens.
    ..registerLazySingleton(() => TourCubit(getIt<TourRepository>()))
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
    )
    ..registerLazySingleton(
      () => GetTopicsUsecase(getIt<TopicRepository>()),
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
      () => GetTopicTokensUsecase(getIt<TopicRepository>()),
    )
    ..registerLazySingleton(
      () => CreateTopicTokenUsecase(getIt<TopicRepository>()),
    )
    ..registerLazySingleton(
      () => RevokeTopicTokenUsecase(getIt<TopicRepository>()),
    )
    ..registerLazySingleton(
      () => RenameTopicTokenUsecase(getIt<TopicRepository>()),
    )
    ..registerFactory(
      () => TopicTokensCubit(
        getIt<GetTopicTokensUsecase>(),
        getIt<CreateTopicTokenUsecase>(),
        getIt<RevokeTopicTokenUsecase>(),
        getIt<RenameTopicTokenUsecase>(),
      ),
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
      bool?
    >(
      (initialStep, replayForDemo) => NotificationPermissionsCubit(
        getIt<RequestNotificationPermissionUsecase>(),
        getIt<OpenNotificationSettingsUsecase>(),
        alarm: getIt<AlarmHost>(),
        checkPermission: getIt<CheckNotificationPermissionUsecase>(),
        getDevicePermissions: getIt<GetDevicePermissionsUsecase>(),
        openPermissionSettings: getIt<OpenPermissionSettingsUsecase>(),
        replayForDemo: replayForDemo ?? false,
        initialStep: initialStep ?? NotificationPermissionStep.initial,
      ),
    )
    ..registerFactoryParam<OnboardingConnectCubit, bool?, void>(
      (initialConnected, _) => OnboardingConnectCubit(
        getIt<GetServerInfoUsecase>(),
        getIt<SaveConnectionUsecase>(),
        getIt<TriggerTestAlarmUsecase>(),
        completeOnboarding: getIt<CompleteOnboardingUsecase>(),
        establishSession: getIt<EstablishApiSessionUsecase>(),
        getConnection: getIt<GetConnectionUsecase>(),
        getTopics: getIt<GetTopicsUsecase>(),
        alarmHost: getIt<AlarmHost>(),
        readDraft: getIt<ReadOnboardingDraftUsecase>(),
        saveDraft: getIt<SaveOnboardingDraftUsecase>(),
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
        getTopics: getIt<GetTopicsUsecase>(),
      ),
    )
    ..registerFactory(
      () => HomeCubit(
        getIt<IncidentsCubit>(),
        getIt<TopicsCubit>(),
        getIt<IncidentRepository>(),
        getIt<MessageSyncService>(),
        getIt<GetConnectionUsecase>(),
      ),
    )
    ..registerFactory(
      () => SearchCubit(
        topics: getIt<TopicsCubit>(),
        incidents: getIt<IncidentsCubit>(),
        getDocsIndex: getIt<GetDocsIndexUsecase>(),
        getRecentSearches: getIt<GetRecentSearchesUsecase>(),
        addRecentSearch: getIt<AddRecentSearchUsecase>(),
        clearRecentSearches: getIt<ClearRecentSearchesUsecase>(),
        // A release build never offers the developer screen, so search must
        // never find it either.
        includeDevOnlySettings: buildSkipsPaywall,
      ),
    )
    ..registerFactory(
      () => ShellCubit(
        getIt<GetDevicePermissionsUsecase>(),
      ),
    )
    ..registerFactory(
      () => HistoryCubit(
        getIt<IncidentsCubit>(),
        identityStore: getIt<DeviceIdentityStore>(),
      ),
    )
    ..registerFactory(
      () => TopicDetailCubit(
        getIt<IncidentsCubit>(),
        getIt<TopicsCubit>(),
        getIt<UpdateTopicUsecase>(),
        getIt<IncidentRepository>(),
        alarm: getIt<AlarmHost>(),
      ),
    )
    ..registerFactory(
      () => CreateTopicCubit(
        getIt<CreateTopicUsecase>(),
        getIt<GetConnectionUsecase>(),
        getIt<DeviceIdentityStore>(),
        getIt<GetTopicsUsecase>(),
      ),
    )
    ..registerFactory(
      () => CriticalAlarmCubit(
        getIt<GetIncidentUsecase>(),
        getIt<GetIncidentsUsecase>(),
        getIt<AcknowledgeIncidentUsecase>(),
        getIt<CloseIncidentUsecase>(),
        getIt<IncidentsCubit>(),
        getIt<AlarmHost>(),
        // The two defaults, spelled out so the onboarding flag after them can
        // be passed at all. Only a test overrides either.
        const Duration(seconds: 1),
        null,
        getIt<GetOnboardingCompletedUsecase>(),
      ),
    )
    ..registerFactory(
      () => LockScreenCubit(
        getIt<GetIncidentsUsecase>(),
      ),
    )
    ..registerFactory(
      () => AccountCubit(
        identities: getIt<IdentityRepository>(),
        account: getIt<AccountRepository>(),
      ),
    )
    ..registerFactory(
      () => SettingsCubit(
        identityStore: getIt<DeviceIdentityStore>(),
        apiSessions: getIt<ApiSessionStore>(),
        getServerInfo: getIt<GetServerInfoUsecase>(),
        establishSession: getIt<EstablishApiSessionUsecase>(),
        getTopics: getIt<GetTopicsUsecase>(),
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
        quietHoursStore: getIt<QuietHoursStore>(),
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
        identityStore: getIt<DeviceIdentityStore>(),
        telemetryGate: getIt.isRegistered<TelemetryGate>()
            ? getIt<TelemetryGate>()
            : null,
        getOfferingsUsecase: getIt<GetOfferingsUsecase>(),
        purchasePackageUsecase: getIt<PurchasePackageUsecase>(),
        restorePurchasesUsecase: getIt<RestorePurchasesUsecase>(),
        getCustomerInfoUsecase: getIt<GetCustomerInfoUsecase>(),
        subscriptionRepository: getIt<SubscriptionRepository>(),
        refreshRegistration: () async {
          if (!buildSkipsPaywall) {
            await getIt<RevenueCatService>().invalidateCustomerInfoCache();
          }
          await getIt<RegisterDeviceUsecase>()(appVersion: appVersion);
        },
      ),
    )
    ..registerFactoryParam<HomePromptCubit, ShellCubit?, void>(
      (shellCubit, _) => HomePromptCubit(
        getConnectionUsecase: getIt<GetConnectionUsecase>(),
        shellCubit: shellCubit ?? getIt<ShellCubit>(),
        identityRepository: getIt<IdentityRepository>(),
        accountRepository: getIt<AccountRepository>(),
        homePromptRepository: getIt<HomePromptRepository>(),
        identityChanges: appAccountIdentityChanges,
      ),
    );
}
