import 'dart:async';
import 'dart:convert';

import 'package:critalarm/app/initial_route_resolver.dart';
import 'package:critalarm/app/shell/shell_cubit.dart';
import 'package:critalarm/app/state/incidents_cubit.dart';
import 'package:critalarm/app/state/topics_cubit.dart';
import 'package:critalarm/app/widget_sync.dart';
import 'package:critalarm/core/account/account_identity_changes.dart';
import 'package:critalarm/core/account/plan_changes.dart';
import 'package:critalarm/core/ack/ack_queue.dart';
import 'package:critalarm/core/alarm/alarm_build_mode.dart';
import 'package:critalarm/core/alarm/alarm_debug_snapshot.dart';
import 'package:critalarm/core/alarm/alarm_focus.dart';
import 'package:critalarm/core/alarm/alarm_host.dart';
import 'package:critalarm/core/alarm/incident_alarm_controller.dart';
import 'package:critalarm/core/alarm/live_activity_token_registry.dart';
import 'package:critalarm/core/alarm/quiet_hours_store.dart';
import 'package:critalarm/core/api/api_build_mode.dart';
import 'package:critalarm/core/api/api_client.dart';
import 'package:critalarm/core/api/api_session.dart';
import 'package:critalarm/core/api/http_api_client.dart';
import 'package:critalarm/core/api/mock_api_client.dart';
import 'package:critalarm/core/api/mock_server.dart';
import 'package:critalarm/core/device/dev_edge_effect_switch.dart';
import 'package:critalarm/core/device/device_form.dart';
import 'package:critalarm/core/env/env.dart';
import 'package:critalarm/core/net/launch_call_log.dart';
import 'package:critalarm/core/notifications/app_badge.dart';
import 'package:critalarm/core/paywall/dev_paywall_variant_switch.dart';
import 'package:critalarm/core/paywall/dev_pro_switch.dart';
import 'package:critalarm/core/paywall/paywall_build_mode.dart';
import 'package:critalarm/core/paywall/paywall_variant.dart';
import 'package:critalarm/core/paywall/pro_override.dart';
import 'package:critalarm/core/push/apns_push_token_provider.dart';
import 'package:critalarm/core/push/firebase_push_token_provider.dart';
import 'package:critalarm/core/push/push_event_drain.dart';
import 'package:critalarm/core/push/push_host.dart';
import 'package:critalarm/core/push/push_token_provider.dart';
import 'package:critalarm/core/sound/incoming_audio.dart';
import 'package:critalarm/core/sound/sound_host.dart';
import 'package:critalarm/core/sound/sound_import.dart';
import 'package:critalarm/core/sound/sound_peaks_cache.dart';
import 'package:critalarm/core/sound/sound_recorder.dart';
import 'package:critalarm/core/storage/api_session_store.dart';
import 'package:critalarm/core/storage/device_identity_store.dart';
import 'package:critalarm/core/storage/nse_credential_store.dart';
import 'package:critalarm/core/storage/shared_prefs_api_session_store.dart';
import 'package:critalarm/core/store/local_store.dart';
import 'package:critalarm/core/sync/message_sync_service.dart';
import 'package:critalarm/core/telemetry/analytics_events.dart';
import 'package:critalarm/core/telemetry/firebase_telemetry_gate.dart';
import 'package:critalarm/core/telemetry/paywall_analytics.dart';
import 'package:critalarm/core/telemetry/reminder_analytics.dart';
import 'package:critalarm/core/telemetry/telemetry_gate.dart';
import 'package:critalarm/core/usecase/usecase.dart';
import 'package:critalarm/core/version/app_version.dart';
import 'package:critalarm/core/widgets/widget_host.dart';
import 'package:critalarm/design_system/edge_effect.dart';
import 'package:critalarm/features/account/data/repositories/api_account_repository.dart';
import 'package:critalarm/features/account/data/repositories/http_identity_repository.dart';
import 'package:critalarm/features/account/data/services/provider_sign_in.dart';
import 'package:critalarm/features/account/domain/repositories/account_repository.dart';
import 'package:critalarm/features/account/domain/repositories/identity_repository.dart';
import 'package:critalarm/features/account/presentation/cubits/account_cubit.dart';
import 'package:critalarm/features/feedback/data/platform_device_report_repository.dart';
import 'package:critalarm/features/feedback/domain/repositories/device_report_repository.dart';
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
import 'package:critalarm/features/paywall/domain/entities/subscription_tier.dart';
import 'package:critalarm/features/paywall/domain/repositories/subscription_repository.dart';
import 'package:critalarm/features/paywall/domain/usecases/get_customer_info_usecase.dart';
import 'package:critalarm/features/paywall/domain/usecases/get_offerings_usecase.dart';
import 'package:critalarm/features/paywall/domain/usecases/purchase_package_usecase.dart';
import 'package:critalarm/features/paywall/domain/usecases/restore_purchases_usecase.dart';
import 'package:critalarm/features/paywall/presentation/cubits/paywall_cubit.dart';
import 'package:critalarm/features/paywall/presentation/cubits/pro_status_cubit.dart';
import 'package:critalarm/features/permissions/data/repositories/platform_device_permissions_repository.dart';
import 'package:critalarm/features/permissions/domain/repositories/device_permissions_repository.dart';
import 'package:critalarm/features/permissions/domain/usecases/get_device_permissions_usecase.dart';
import 'package:critalarm/features/permissions/domain/usecases/open_permission_settings_usecase.dart';
import 'package:critalarm/features/permissions/presentation/cubits/device_permissions_cubit.dart';
import 'package:critalarm/features/prompts/data/repositories/shared_prefs_home_prompt_repository.dart';
import 'package:critalarm/features/prompts/domain/home_ask_rules.dart';
import 'package:critalarm/features/prompts/domain/pro_ending.dart';
import 'package:critalarm/features/prompts/domain/pro_prompt_rules.dart';
import 'package:critalarm/features/prompts/domain/repositories/home_prompt_repository.dart';
import 'package:critalarm/features/prompts/domain/setup_gate.dart';
import 'package:critalarm/features/prompts/presentation/cubits/home_prompt_cubit.dart';
import 'package:critalarm/features/reminders/data/native_reminder_scheduler.dart';
import 'package:critalarm/features/reminders/data/noop_reminder_scheduler.dart';
import 'package:critalarm/features/reminders/data/revenuecat_plan_status_source.dart';
import 'package:critalarm/features/reminders/data/shared_prefs_reminder_store.dart';
import 'package:critalarm/features/reminders/domain/plan_status_source.dart';
import 'package:critalarm/features/reminders/domain/reminder_copy.dart';
import 'package:critalarm/features/reminders/domain/reminder_inputs_reader.dart';
import 'package:critalarm/features/reminders/domain/reminder_plan_pass.dart';
import 'package:critalarm/features/reminders/domain/reminder_plan_trigger.dart';
import 'package:critalarm/features/reminders/domain/reminder_scheduler.dart';
import 'package:critalarm/features/reminders/domain/reminder_server_support.dart';
import 'package:critalarm/features/reminders/domain/reminder_settler.dart';
import 'package:critalarm/features/reminders/domain/reminder_store.dart';
import 'package:critalarm/features/reminders/presentation/cubits/confirm_ring_cubit.dart';
import 'package:critalarm/features/reminders/presentation/cubits/reminder_lab_cubit.dart';
import 'package:critalarm/features/reminders/presentation/cubits/reminder_settings_cubit.dart';
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
import 'package:critalarm/features/settings/data/repositories/shared_prefs_storage_settings_repository.dart';
import 'package:critalarm/features/settings/data/repositories/shared_prefs_theme_preference_repository.dart';
import 'package:critalarm/features/settings/data/services/sound_file_picker.dart';
import 'package:critalarm/features/settings/domain/repositories/alarm_sound_repository.dart';
import 'package:critalarm/features/settings/domain/repositories/privacy_repository.dart';
import 'package:critalarm/features/settings/domain/repositories/sound_file_picker.dart';
import 'package:critalarm/features/settings/domain/repositories/storage_settings_repository.dart';
import 'package:critalarm/features/settings/domain/repositories/theme_preference_repository.dart';
import 'package:critalarm/features/settings/domain/usecases/auto_delete_history_usecase.dart';
import 'package:critalarm/features/settings/domain/usecases/delete_user_sound_usecase.dart';
import 'package:critalarm/features/settings/domain/usecases/get_privacy_settings_usecase.dart';
import 'package:critalarm/features/settings/domain/usecases/get_theme_mode_usecase.dart';
import 'package:critalarm/features/settings/domain/usecases/import_sound_usecase.dart';
import 'package:critalarm/features/settings/domain/usecases/set_analytics_enabled_usecase.dart';
import 'package:critalarm/features/settings/domain/usecases/set_crash_reporting_enabled_usecase.dart';
import 'package:critalarm/features/settings/domain/usecases/set_theme_mode_usecase.dart';
import 'package:critalarm/features/settings/presentation/cubits/alarm_debug_cubit.dart';
import 'package:critalarm/features/settings/presentation/cubits/recorder_cubit.dart';
import 'package:critalarm/features/settings/presentation/cubits/settings_cubit.dart';
import 'package:critalarm/features/settings/presentation/cubits/sound_crop_cubit.dart';
import 'package:critalarm/features/settings/presentation/cubits/sound_picker_cubit.dart';
import 'package:critalarm/features/settings/presentation/cubits/theme_cubit.dart';
import 'package:critalarm/features/topics/data/repositories/in_memory_topic_repository.dart';
import 'package:critalarm/features/topics/data/repositories/shared_prefs_topic_list_prefs_repository.dart';
import 'package:critalarm/features/topics/domain/repositories/topic_list_prefs_repository.dart';
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
import 'package:purchases_flutter/purchases_flutter.dart' show CustomerInfo;
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

  // The phone's own copy of every incident and message (api.md §4.2, where
  // `history_days` became retention). Web has no sqflite, so the dashboard
  // build keeps reading the server live and every store call is skipped.
  LocalStore? localStore;
  if (!kIsWeb) {
    try {
      localStore = await LocalStore.open();
    } on Object catch (error, stack) {
      // A database that will not open must not stop the app from ringing.
      debugPrint('local_store_open_failed error=$error');
      debugPrintStack(stackTrace: stack);
    }
  }

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

  if (buildHasPaywallLab) {
    if (!getIt.isRegistered<DevPaywallVariantSwitch>()) {
      getIt.registerSingleton<DevPaywallVariantSwitch>(
        DevPaywallVariantSwitch(prefs),
      );
    }
    // Same shape as the Force Pro switch. A store build compiles
    // appPaywallVariantOverride as a NoPaywallVariantOverride, so this call
    // does nothing and Remote Config stays in charge.
    appPaywallVariantOverride.watch(getIt<DevPaywallVariantSwitch>());
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
        // The store knows about a purchase before our server does. Mirror its
        // Pro entitlement so the app turns Pro the moment the buyer pays.
        revenueCatService.customerInfoStream.listen(_mirrorStorePro);
        unawaited(
          revenueCatService.getCustomerInfo().then(
            _mirrorStorePro,
            onError: (Object _) {},
          ),
        );
      }
    } on Object catch (_) {
      // Ignored for tests or unsupported environments
    }
    getIt.registerSingleton<RevenueCatService>(revenueCatService);
  }

  final deviceForm = await DeviceForm.read();
  final autoEffect = autoEdgeEffect(
    platform: defaultTargetPlatform,
    shaderSupported: await loadEdgeBlurShader(),
    isLowRamDevice: deviceForm.isLowRamDevice,
  );
  appEdgeEffect.value = autoEffect;
  if (buildSkipsPaywall) {
    if (!getIt.isRegistered<DevEdgeEffectSwitch>()) {
      getIt.registerSingleton<DevEdgeEffectSwitch>(
        DevEdgeEffectSwitch(prefs, auto: autoEffect),
      );
    }
    final edgeSwitch = getIt<DevEdgeEffectSwitch>();
    void applyEdgeOverride() => appEdgeEffect.value = edgeSwitch.effective;
    edgeSwitch.addListener(applyEdgeOverride);
    applyEdgeOverride();
  }

  getIt
    ..registerSingleton<SharedPreferences>(prefs)
    ..registerSingleton<DeviceForm>(deviceForm)
    ..registerLazySingleton<TopicListPrefsRepository>(
      () => SharedPrefsTopicListPrefsRepository(getIt<SharedPreferences>()),
    )
    ..registerLazySingleton<PushHost>(PushHost.new)
    ..registerLazySingleton<NseCredentialStore>(NseCredentialStore.new)
    ..registerLazySingleton<WidgetHost>(WidgetHost.new)
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
      () => InMemoryIncidentRepository(getIt<ApiClient>(), store: localStore),
    )
    ..registerLazySingleton<StorageSettingsRepository>(
      () => SharedPrefsStorageSettingsRepository(getIt<SharedPreferences>()),
    )
    ..registerLazySingleton<AutoDeleteHistoryUsecase>(
      () => AutoDeleteHistoryUsecase(
        localStore,
        () => getIt<StorageSettingsRepository>().read(),
      ),
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
        widgets: getIt<WidgetHost>(),
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
    ..registerLazySingleton<SoundPeaksCache>(
      () => SoundPeaksCache(getIt<SoundHost>()),
    )
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
    ..registerLazySingleton<ReminderStore>(
      () => SharedPrefsReminderStore(getIt<SharedPreferences>()),
    )
    ..registerLazySingleton(
      () => ReminderSettler(
        store: getIt<ReminderStore>(),
        prompts: getIt<HomePromptRepository>(),
      ),
    )
    // Web has no local notifications, so the dashboard gets the no-op.
    ..registerLazySingleton<ReminderScheduler>(
      () => kIsWeb ? const NoopReminderScheduler() : NativeReminderScheduler(),
    )
    ..registerLazySingleton<PlanStatusSource>(
      () => RevenueCatPlanStatusSource(getIt<SubscriptionRepository>()),
    )
    ..registerLazySingleton(
      () => ReminderInputsReader(
        store: getIt<ReminderStore>(),
        prompts: getIt<HomePromptRepository>(),
        quietHours: getIt<QuietHoursStore>(),
        scheduler: getIt<ReminderScheduler>(),
        planStatus: getIt<PlanStatusSource>(),
        privacy: getIt<PrivacyRepository>(),
        readTopics: () async =>
            (await getIt<GetTopicsUsecase>()(const NoParams())).getOrNull(),
        readIncidents: () async => (await getIt<GetIncidentsUsecase>()(
          const GetIncidentsParams(limit: 50),
        )).getOrNull(),
        // A failed poll counts as "has messages": better to miss a nudge
        // than to nag about a topic that may be working.
        topicHasMessages: (topic) async =>
            (await getIt<IncidentRepository>().pollMessages(
              topic,
              poll: 1,
              since: 'all',
            )).fold((messages) => messages.isNotEmpty, (_) => true),
        readServerMode: () => getIt<AccountRepository>().readServerMode(),
        readIsPaid: () async =>
            (await getIt<AccountRepository>().readIsPaid()) ||
            appProOverride.isForcingPro,
        readIsSignedIn: () async =>
            (await getIt<IdentityRepository>().readIdentity()) != null,
        proShouldAsk: () => getIt<ProPromptRules>().shouldAsk(),
        isSetupDone: () => getIt<SetupGate>().isDone(),
        isWeb: kIsWeb,
        isIos: !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS,
      ),
    )
    ..registerLazySingleton(
      () => ReminderPlanPass(
        store: getIt<ReminderStore>(),
        scheduler: getIt<ReminderScheduler>(),
        settler: getIt<ReminderSettler>(),
        readInputs: () => getIt<ReminderInputsReader>().read(),
        copy: ReminderCopy(
          isIos: !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS,
        ),
      ),
    )
    // Web plans nothing.
    ..registerLazySingleton<ReminderPlanTrigger>(
      () =>
          kIsWeb ? const NoopReminderPlanTrigger() : getIt<ReminderPlanPass>(),
    )
    ..registerLazySingleton<SetupGate>(
      () => SetupGate(
        isOnboardingDone: () async {
          final done = await getIt<GetOnboardingCompletedUsecase>()(
            const NoParams(),
          );
          return done.getOrNull() ?? false;
        },
        hasSeenTour: () => getIt<TourRepository>().hasSeenTour(),
      ),
    )
    ..registerLazySingleton<ProPromptRules>(
      () => ProPromptRules(
        homePromptRepository: getIt<HomePromptRepository>(),
        accountRepository: getIt<AccountRepository>(),
        offersOn: () => getIt<ReminderStore>().readSwitches().offers,
        isSetupDone: () => getIt<SetupGate>().isDone(),
      ),
    )
    ..registerLazySingleton<HomeAskRules>(
      () => HomeAskRules(
        homePromptRepository: getIt<HomePromptRepository>(),
        privacyRepository: getIt<PrivacyRepository>(),
        settle: () => getIt<ReminderSettler>().settleAsks(now: DateTime.now()),
        isSetupDone: () => getIt<SetupGate>().isDone(),
        // An ack made on another device counts too, and only the shared list
        // carries it. The review popup skips the whole day of one.
        newestAckedAt: () => getIt<IncidentsCubit>().state.newestAckedAt,
      ),
    )
    ..registerLazySingleton<DeviceReportRepository>(
      () => PlatformDeviceReportRepository(
        accountRepository: getIt<AccountRepository>(),
      ),
    )
    ..registerLazySingleton<LaunchCallLog>(LaunchCallLog.new)
    ..registerLazySingleton(
      () => DeviceTokenRegistry(
        prefs: getIt<SharedPreferences>(),
        register: getIt<RegisterDeviceUsecase>(),
        tokens: getIt<PushTokenProvider>(),
        appVersion: appVersion,
        callLog: getIt<LaunchCallLog>(),
      ),
    )
    ..registerLazySingleton<AlarmHost>(AlarmHost.new)
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
    )
    ..registerLazySingleton(() => PushAnalytics(getIt<TelemetryGate>()))
    ..registerLazySingleton(() => ReminderAnalytics(getIt<TelemetryGate>()))
    ..registerLazySingleton(
      () => PushEventDrain(getIt<SharedPreferences>(), getIt<TelemetryGate>()),
    )
    ..registerLazySingleton(
      () => AckQueue(
        getIt<SharedPreferences>(),
        getIt<ApiClient>(),
        analytics: getIt<PushAnalytics>(),
        alarms: getIt<AlarmHost>(),
        // An acknowledge that only lands minutes later still has to move the
        // badge and every open screen, so the shared list catches up.
        onSent: () => getIt<IncidentsCubit>().refresh(),
      ),
    )
    ..registerFactory<AlarmDebugCubit>(
      () => AlarmDebugCubit(
        readNative: getIt<AlarmHost>().debugSnapshot,
        readEnvironment: _readAlarmDebugEnvironment,
        readDartAckQueue: getIt<AckQueue>().entries,
        readPushEvents: getIt<PushEventDrain>().recent,
        readLaunchCalls: () {
          final calls = getIt<LaunchCallLog>();
          return [
            ...calls.recentFailures(),
            for (final entry in calls.lastSuccessByName.entries)
              DebugLaunchCall(name: entry.key, at: entry.value),
          ];
        },
        readStoreStats: () async =>
            localStore == null ? DebugStoreStats.empty : localStore.stats(),
        flushNow: getIt<AckQueue>().flushNow,
        cancelAllRearms: getIt<AlarmHost>().cancelAllRearms,
        clearContentCache: getIt<AlarmHost>().clearContentCache,
        clearAckedSet: getIt<AlarmHost>().clearAckedSet,
        reconcileNow: getIt<IncidentAlarmController>().reconcile,
        recordDebugAction: getIt<PushEventDrain>().recordDebugAction,
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
      () =>
          RememberOnboardingStepUsecase(getIt<OnboardingProgressRepository>()),
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
      () => TriggerTestAlarmUsecase(
        getIt<IncidentRepository>(),
        reminderStore: getIt<ReminderStore>(),
        // Fire and forget: a slow or failed re-plan never blocks or fails
        // the test ring.
        onTested: (_) => unawaited(getIt<ReminderPlanTrigger>().run()),
      ),
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
        saveIncident: getIt<IncidentRepository>().saveIncident,
      ),
    )
    ..registerLazySingleton(
      () => TopicsCubit(
        getIt<GetTopicsUsecase>(),
        deleteTopic: getIt<DeleteTopicUsecase>(),
        incidents: getIt<IncidentsCubit>(),
      ),
    )
    // "Is an alarm under way on this phone", read off the shared list. Every
    // guard that keeps sheets, banners and navigation away from an alarm
    // asks this one object.
    ..registerLazySingleton(
      () => AlarmFocus(
        incidents: getIt<IncidentsCubit>().stream.map((s) => s.incidents),
        current: () => getIt<IncidentsCubit>().state.incidents,
        maxRingSeconds: (topic) =>
            getIt<TopicsCubit>().state.named(topic)?.maxRingS,
        host: getIt<AlarmHost>(),
      ),
    )
    // The home and lock screen widgets read a snapshot of the two lists
    // above. This writes it whenever either list changes.
    ..registerLazySingleton(
      () => WidgetSync(
        topics: getIt<TopicsCubit>(),
        incidents: getIt<IncidentsCubit>(),
        host: getIt<WidgetHost>(),
        isConnected: () async =>
            (await getIt<ConnectionRepository>().getConnection()).isSuccess(),
        // Widgets are part of Pro on the hosted plan. A self-hosted server
        // has no plans, so it never locks.
        isLocked: () async {
          final account = getIt<AccountRepository>();
          return await account.readServerMode() == ServerMode.hosted &&
              !await account.readIsPaid();
        },
      ),
    )
    // "Share to Crit Alarm". Holds a shared file until onboarding is done and
    // no alarm is going off.
    ..registerLazySingleton(
      () => IncomingAudio(
        canImportSounds: () async =>
            (await getIt<SoundHost>().capabilities()).canImportSounds,
        isOnboardingDone: () async =>
            (await getIt<GetOnboardingCompletedUsecase>()(
              const NoParams(),
            )).getOrNull() ??
            false,
        isRinging: getIt<AlarmHost>().isRinging,
        discard: getIt<SoundFilePicker>().discard,
        platform: defaultTargetPlatform,
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
      () => CreateTopicUsecase(
        getIt<TopicRepository>(),
        // Recording the topic is awaited (it is a plain preference write);
        // the plan pass is fire and forget, so a slow or failed re-plan
        // never blocks or fails topic creation.
        onCreated: (topic) async {
          await getIt<ReminderStore>().recordTopicCreatedHere(
            topic.name,
            DateTime.now(),
          );
          unawaited(getIt<ReminderPlanTrigger>().run());
        },
      ),
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
        null,
        const Duration(seconds: 5),
        getIt<TopicListPrefsRepository>(),
      ),
    )
    ..registerFactory(
      () => SearchCubit(
        identityStore: getIt<DeviceIdentityStore>(),
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
        sessionStore: getIt<ApiSessionStore>(),
        store: localStore,
      ),
    )
    ..registerFactory(
      () => TopicDetailCubit(
        getIt<IncidentsCubit>(),
        getIt<TopicsCubit>(),
        getIt<UpdateTopicUsecase>(),
        getIt<IncidentRepository>(),
        alarm: getIt<AlarmHost>(),
        identityStore: getIt<DeviceIdentityStore>(),
        sessionStore: getIt<ApiSessionStore>(),
      ),
    )
    ..registerFactory(
      () =>
          CreateTopicCubit(
              getIt<CreateTopicUsecase>(),
              getIt<GetConnectionUsecase>(),
              getIt<DeviceIdentityStore>(),
              getIt<GetTopicsUsecase>(),
            )
            ..alarm = getIt<AlarmHost>()
            ..sessionStore = getIt<ApiSessionStore>(),
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
        alarm: getIt<AlarmHost>(),
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
        storageSettings: getIt<StorageSettingsRepository>(),
        // Turning auto-delete on should not wait for the next launch.
        onAutoDeleteChanged: () async =>
            unawaited(getIt<AutoDeleteHistoryUsecase>()()),
        // Fire and forget: a slow or failed re-plan never blocks or fails
        // saving or dropping the server connection.
        onConnectionChanged: () async =>
            unawaited(getIt<ReminderPlanTrigger>().run()),
      ),
    )
    ..registerFactory(
      () => ReminderSettingsCubit(
        store: getIt<ReminderStore>(),
        scheduler: getIt<ReminderScheduler>(),
        readServerMode: () => getIt<AccountRepository>().readServerMode(),
        readIsPaid: () => getIt<AccountRepository>().readIsPaid(),
        trigger: getIt<ReminderPlanTrigger>(),
        analytics: getIt<ReminderAnalytics>(),
      ),
    )
    ..registerFactory(
      () => ConfirmRingCubit(
        readTopics: () async =>
            (await getIt<GetTopicsUsecase>()(const NoParams())).getOrNull(),
        readIncidents: () async => (await getIt<GetIncidentsUsecase>()(
          const GetIncidentsParams(limit: 50),
        )).getOrNull(),
        triggerTest: getIt<TriggerTestAlarmUsecase>().call,
        store: getIt<ReminderStore>(),
        canTestNormalTopics: ReminderServerSupport.testsNormalTopics,
        analytics: getIt<ReminderAnalytics>(),
      ),
    )
    ..registerFactory(
      () => ReminderLabCubit(
        store: getIt<ReminderStore>(),
        prompts: getIt<HomePromptRepository>(),
        scheduler: getIt<ReminderScheduler>(),
        copy: ReminderCopy(
          isIos: !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS,
        ),
        trigger: getIt<ReminderPlanTrigger>(),
        readServerMode: () => getIt<AccountRepository>().readServerMode(),
      ),
    )
    ..registerFactory(
      () => SoundCropCubit(
        getIt<SoundHost>(),
        getIt<ImportSoundUsecase>(),
        getIt<SoundFilePicker>(),
      ),
    )
    // One microphone per recorder screen. The cubit disposes it on close.
    ..registerFactory<SoundRecorder>(RecordSoundRecorder.new)
    ..registerFactory(
      () => RecorderCubit(
        getIt<SoundRecorder>(),
        maxDuration: SoundImportLimits.maxClipDuration(defaultTargetPlatform),
        isRinging: getIt<AlarmHost>().isRinging,
        stopPreview: () => getIt<SoundHost>().stopPreview(),
      ),
    )
    ..registerFactory(
      () => SoundPickerCubit(
        getIt<AlarmSoundRepository>(),
        getIt<SoundHost>(),
        getIt<DeleteUserSoundUsecase>(),
        getIt<SoundFilePicker>(),
        getIt<SoundPeaksCache>(),
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
        analytics: getIt.isRegistered<TelemetryGate>()
            ? PaywallAnalytics(getIt<TelemetryGate>())
            : null,
        refreshRegistration: () async {
          if (!buildSkipsPaywall) {
            await getIt<RevenueCatService>().invalidateCustomerInfoCache();
          }
          await getIt<RegisterDeviceUsecase>()(appVersion: appVersion);
          getIt<WidgetSync>().rewrite();
        },
      ),
    )
    ..registerFactory(
      () => ProStatusCubit(
        readIsPaid: () => getIt<AccountRepository>().readIsPaid(),
      ),
    )
    ..registerLazySingleton(
      () => ProEnding(
        prompts: getIt<HomePromptRepository>(),
        plan: getIt<PlanStatusSource>(),
        readIdentity: () => getIt<DeviceIdentityStore>().readOrCreate(),
        readServerMode: () => getIt<AccountRepository>().readServerMode(),
        refreshRegistration: () async {
          if (!buildSkipsPaywall) {
            await getIt<RevenueCatService>().invalidateCustomerInfoCache();
          }
          await getIt<RegisterDeviceUsecase>()(appVersion: appVersion);
        },
        onPaidChanged: () => getIt<WidgetSync>().rewrite(),
      ),
    )
    ..registerFactoryParam<HomePromptCubit, ShellCubit?, void>(
      (shellCubit, _) => HomePromptCubit(
        getConnectionUsecase: getIt<GetConnectionUsecase>(),
        shellCubit: shellCubit ?? getIt<ShellCubit>(),
        identityRepository: getIt<IdentityRepository>(),
        accountRepository: getIt<AccountRepository>(),
        homePromptRepository: getIt<HomePromptRepository>(),
        proEnding: getIt<ProEnding>(),
        identityChanges: appAccountIdentityChanges,
      ),
    );
}

void _mirrorStorePro(CustomerInfo info) => appPlanChanges.setStoreSaysPro(
  value: info.entitlements.active.containsKey(SubscriptionTier.proEntitlement),
);

Future<DebugEnvironment> _readAlarmDebugEnvironment() async {
  final session = await getIt<ApiSessionStore>().read();
  final prefs = getIt<SharedPreferences>();
  final quietHours = getIt<QuietHoursStore>().read();
  int? historyDays;
  final caps = prefs.getString('account_caps');
  if (caps != null) {
    try {
      final decoded = jsonDecode(caps);
      if (decoded is Map && decoded['history_days'] is int) {
        historyDays = decoded['history_days'] as int;
      }
    } on FormatException {
      // A malformed optional account cache should not fail the whole report.
    }
  }
  String clockText(int minutes) =>
      '${(minutes ~/ 60).toString().padLeft(2, '0')}:'
      '${(minutes % 60).toString().padLeft(2, '0')}';
  return DebugEnvironment(
    serverMode: session?.mode.wireValue,
    baseUrl: session?.baseUri.toString(),
    tier: prefs.getString('account_tier'),
    historyDays: historyDays,
    quietHoursEnabled: quietHours.isEnabled,
    quietHoursHolding: quietHours.holdsRing(
      now: DateTime.now(),
      priority: 5,
    ),
    quietHoursStart: clockText(quietHours.startMinutes),
    quietHoursEnd: clockText(quietHours.endMinutes),
  );
}
