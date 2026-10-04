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
import 'package:critalarm/core/api/api_exception.dart';
import 'package:critalarm/core/api/api_session.dart';
import 'package:critalarm/core/api/http_api_client.dart';
import 'package:critalarm/core/api/mock_api_client.dart';
import 'package:critalarm/core/api/mock_server.dart';
import 'package:critalarm/core/app_icon/app_icon_guard.dart';
import 'package:critalarm/core/app_icon/app_icon_host.dart';
import 'package:critalarm/core/device/dev_edge_effect_switch.dart';
import 'package:critalarm/core/device/device_build_mode.dart';
import 'package:critalarm/core/device/device_form.dart';
import 'package:critalarm/core/device/device_maker.dart';
import 'package:critalarm/core/device/platform_device_maker_reader.dart';
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
import 'package:critalarm/core/sound/sound_pack_host.dart';
import 'package:critalarm/core/sound/sound_pack_repository.dart';
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
import 'package:critalarm/core/telemetry/local_reminder_analytics.dart';
import 'package:critalarm/core/telemetry/paywall_analytics.dart';
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
import 'package:critalarm/features/feature_guides/data/repositories/shared_prefs_feature_guide_repository.dart';
import 'package:critalarm/features/feature_guides/domain/repositories/feature_guide_repository.dart';
import 'package:critalarm/features/feature_guides/presentation/cubits/feature_guide_cubit.dart';
import 'package:critalarm/features/feedback/data/platform_device_report_repository.dart';
import 'package:critalarm/features/feedback/domain/repositories/device_report_repository.dart';
import 'package:critalarm/features/history/presentation/cubits/history_cubit.dart';
import 'package:critalarm/features/in_app_notices/data/repositories/shared_prefs_in_app_notice_repository.dart';
import 'package:critalarm/features/in_app_notices/domain/home_ask_rules.dart';
import 'package:critalarm/features/in_app_notices/domain/pro_ask_rules.dart';
import 'package:critalarm/features/in_app_notices/domain/pro_ending.dart';
import 'package:critalarm/features/in_app_notices/domain/repositories/in_app_notice_repository.dart';
import 'package:critalarm/features/in_app_notices/domain/setup_gate.dart';
import 'package:critalarm/features/in_app_notices/presentation/cubits/in_app_notice_cubit.dart';
import 'package:critalarm/features/incidents/data/repositories/in_memory_incident_repository.dart';
import 'package:critalarm/features/incidents/domain/real_use.dart';
import 'package:critalarm/features/incidents/domain/repositories/incident_repository.dart';
import 'package:critalarm/features/incidents/domain/usecases/acknowledge_incident_usecase.dart';
import 'package:critalarm/features/incidents/domain/usecases/close_incident_usecase.dart';
import 'package:critalarm/features/incidents/domain/usecases/get_incident_usecase.dart';
import 'package:critalarm/features/incidents/domain/usecases/get_incidents_usecase.dart';
import 'package:critalarm/features/incidents/domain/usecases/trigger_test_alarm_usecase.dart';
import 'package:critalarm/features/incidents/presentation/cubits/critical_alarm_cubit.dart';
import 'package:critalarm/features/incidents/presentation/cubits/lock_screen_cubit.dart';
import 'package:critalarm/features/local_reminders/data/native_local_reminder_scheduler.dart';
import 'package:critalarm/features/local_reminders/data/noop_local_reminder_scheduler.dart';
import 'package:critalarm/features/local_reminders/data/revenuecat_plan_status_source.dart';
import 'package:critalarm/features/local_reminders/data/shared_prefs_local_reminder_store.dart';
import 'package:critalarm/features/local_reminders/domain/incident_kinds.dart';
import 'package:critalarm/features/local_reminders/domain/local_reminder_copy.dart';
import 'package:critalarm/features/local_reminders/domain/local_reminder_inputs_reader.dart';
import 'package:critalarm/features/local_reminders/domain/local_reminder_plan_pass.dart';
import 'package:critalarm/features/local_reminders/domain/local_reminder_plan_trigger.dart';
import 'package:critalarm/features/local_reminders/domain/local_reminder_scheduler.dart';
import 'package:critalarm/features/local_reminders/domain/local_reminder_server_support.dart';
import 'package:critalarm/features/local_reminders/domain/local_reminder_settler.dart';
import 'package:critalarm/features/local_reminders/domain/local_reminder_store.dart';
import 'package:critalarm/features/local_reminders/domain/plan_status_source.dart';
import 'package:critalarm/features/local_reminders/presentation/cubits/confirm_ring_cubit.dart';
import 'package:critalarm/features/local_reminders/presentation/cubits/local_reminder_lab_cubit.dart';
import 'package:critalarm/features/local_reminders/presentation/cubits/local_reminder_settings_cubit.dart';
import 'package:critalarm/features/onboarding/data/repositories/in_memory_server_repository.dart';
import 'package:critalarm/features/onboarding/data/repositories/keychain_mirror_connection_repository.dart';
import 'package:critalarm/features/onboarding/data/repositories/platform_alarm_arrivals.dart';
import 'package:critalarm/features/onboarding/data/repositories/platform_notification_permission_repository.dart';
import 'package:critalarm/features/onboarding/data/repositories/prefs_setup_test_ring.dart';
import 'package:critalarm/features/onboarding/data/repositories/shared_prefs_connection_repository.dart';
import 'package:critalarm/features/onboarding/data/repositories/shared_prefs_developer_onboarding_overrides.dart';
import 'package:critalarm/features/onboarding/data/repositories/shared_prefs_onboarding_flow_repository.dart';
import 'package:critalarm/features/onboarding/data/repositories/shared_prefs_onboarding_progress_repository.dart';
import 'package:critalarm/features/onboarding/domain/connect/background_connect.dart';
import 'package:critalarm/features/onboarding/domain/connect/connect_intent_store.dart';
import 'package:critalarm/features/onboarding/domain/flow/developer_onboarding.dart';
import 'package:critalarm/features/onboarding/domain/flow/onboarding_flow.dart';
import 'package:critalarm/features/onboarding/domain/flow/onboarding_flow_engine.dart';
import 'package:critalarm/features/onboarding/domain/flow/onboarding_flow_source.dart';
import 'package:critalarm/features/onboarding/domain/flow/onboarding_step_catalog.dart';
import 'package:critalarm/features/onboarding/domain/flow/onboarding_step_facts.dart';
import 'package:critalarm/features/onboarding/domain/flow/remote_onboarding_flow_source.dart';
import 'package:critalarm/features/onboarding/domain/real_ring/alarm_arrivals.dart';
import 'package:critalarm/features/onboarding/domain/real_ring/setup_test_ring.dart';
import 'package:critalarm/features/onboarding/domain/repositories/connection_repository.dart';
import 'package:critalarm/features/onboarding/domain/repositories/notification_permission_repository.dart';
import 'package:critalarm/features/onboarding/domain/repositories/onboarding_flow_repository.dart';
import 'package:critalarm/features/onboarding/domain/repositories/onboarding_progress_repository.dart';
import 'package:critalarm/features/onboarding/domain/repositories/server_repository.dart';
import 'package:critalarm/features/onboarding/domain/setup_stats_consent.dart';
import 'package:critalarm/features/onboarding/domain/usecases/check_notification_permission_usecase.dart';
import 'package:critalarm/features/onboarding/domain/usecases/clear_connection_usecase.dart';
import 'package:critalarm/features/onboarding/domain/usecases/complete_onboarding_usecase.dart';
import 'package:critalarm/features/onboarding/domain/usecases/device_token_registry.dart';
import 'package:critalarm/features/onboarding/domain/usecases/end_setup_test_usecase.dart';
import 'package:critalarm/features/onboarding/domain/usecases/establish_api_session_usecase.dart';
import 'package:critalarm/features/onboarding/domain/usecases/get_connection_usecase.dart';
import 'package:critalarm/features/onboarding/domain/usecases/get_onboarding_completed_usecase.dart';
import 'package:critalarm/features/onboarding/domain/usecases/get_server_info_usecase.dart';
import 'package:critalarm/features/onboarding/domain/usecases/onboarding_draft_usecases.dart';
import 'package:critalarm/features/onboarding/domain/usecases/open_notification_settings_usecase.dart';
import 'package:critalarm/features/onboarding/domain/usecases/read_permission_setup_usecase.dart';
import 'package:critalarm/features/onboarding/domain/usecases/register_device_usecase.dart';
import 'package:critalarm/features/onboarding/domain/usecases/request_notification_permission_usecase.dart';
import 'package:critalarm/features/onboarding/domain/usecases/save_connection_usecase.dart';
import 'package:critalarm/features/onboarding/domain/usecases/set_up_later_usecase.dart';
import 'package:critalarm/features/onboarding/presentation/cubits/hook_up_cubit.dart';
import 'package:critalarm/features/onboarding/presentation/cubits/notification_permissions_cubit.dart';
import 'package:critalarm/features/onboarding/presentation/cubits/notification_permissions_state.dart';
import 'package:critalarm/features/onboarding/presentation/cubits/onboarding_connect_cubit.dart';
import 'package:critalarm/features/onboarding/presentation/cubits/onboarding_welcome_cubit.dart';
import 'package:critalarm/features/onboarding/presentation/cubits/real_ring_cubit.dart';
import 'package:critalarm/features/onboarding/presentation/flow/onboarding_step_registry.dart';
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
import 'package:critalarm/features/settings/data/repositories/shared_prefs_appearance_settings_repository.dart';
import 'package:critalarm/features/settings/data/repositories/shared_prefs_privacy_repository.dart';
import 'package:critalarm/features/settings/data/repositories/shared_prefs_storage_settings_repository.dart';
import 'package:critalarm/features/settings/data/repositories/shared_prefs_theme_preference_repository.dart';
import 'package:critalarm/features/settings/data/services/sound_file_picker.dart';
import 'package:critalarm/features/settings/domain/repositories/alarm_sound_repository.dart';
import 'package:critalarm/features/settings/domain/repositories/appearance_settings_repository.dart';
import 'package:critalarm/features/settings/domain/repositories/privacy_repository.dart';
import 'package:critalarm/features/settings/domain/repositories/sound_file_picker.dart';
import 'package:critalarm/features/settings/domain/repositories/storage_settings_repository.dart';
import 'package:critalarm/features/settings/domain/repositories/theme_preference_repository.dart';
import 'package:critalarm/features/settings/domain/usecases/auto_delete_history_usecase.dart';
import 'package:critalarm/features/settings/domain/usecases/delete_user_sound_usecase.dart';
import 'package:critalarm/features/settings/domain/usecases/get_appearance_settings_usecase.dart';
import 'package:critalarm/features/settings/domain/usecases/get_privacy_settings_usecase.dart';
import 'package:critalarm/features/settings/domain/usecases/get_theme_mode_usecase.dart';
import 'package:critalarm/features/settings/domain/usecases/import_sound_usecase.dart';
import 'package:critalarm/features/settings/domain/usecases/set_analytics_enabled_usecase.dart';
import 'package:critalarm/features/settings/domain/usecases/set_crash_reporting_enabled_usecase.dart';
import 'package:critalarm/features/settings/domain/usecases/set_haptics_enabled_usecase.dart';
import 'package:critalarm/features/settings/domain/usecases/set_reduce_motion_usecase.dart';
import 'package:critalarm/features/settings/domain/usecases/set_theme_mode_usecase.dart';
import 'package:critalarm/features/settings/presentation/cubits/alarm_debug_cubit.dart';
import 'package:critalarm/features/settings/presentation/cubits/app_icon_cubit.dart';
import 'package:critalarm/features/settings/presentation/cubits/appearance_cubit.dart';
import 'package:critalarm/features/settings/presentation/cubits/recorder_cubit.dart';
import 'package:critalarm/features/settings/presentation/cubits/settings_cubit.dart';
import 'package:critalarm/features/settings/presentation/cubits/sound_crop_cubit.dart';
import 'package:critalarm/features/settings/presentation/cubits/sound_picker_cubit.dart';
import 'package:critalarm/features/settings/presentation/cubits/theme_cubit.dart';
import 'package:critalarm/features/topics/data/api_first_message_source.dart';
import 'package:critalarm/features/topics/data/prefs_first_message_store.dart';
import 'package:critalarm/features/topics/data/prefs_first_topic_handoff.dart';
import 'package:critalarm/features/topics/data/prefs_setup_checklist_store.dart';
import 'package:critalarm/features/topics/data/repositories/in_memory_topic_repository.dart';
import 'package:critalarm/features/topics/data/repositories/shared_prefs_topic_list_prefs_repository.dart';
import 'package:critalarm/features/topics/data/shared_prefs_tool_template_store.dart';
import 'package:critalarm/features/topics/domain/first_message/first_message_store.dart';
import 'package:critalarm/features/topics/domain/first_message/first_message_watcher.dart';
import 'package:critalarm/features/topics/domain/first_topic_handoff.dart';
import 'package:critalarm/features/topics/domain/repositories/tool_template_store.dart';
import 'package:critalarm/features/topics/domain/repositories/topic_list_prefs_repository.dart';
import 'package:critalarm/features/topics/domain/repositories/topic_repository.dart';
import 'package:critalarm/features/topics/domain/setup_checklist.dart';
import 'package:critalarm/features/topics/domain/setup_checklist_store.dart';
import 'package:critalarm/features/topics/domain/usecases/create_topic_usecase.dart';
import 'package:critalarm/features/topics/domain/usecases/delete_topic_usecase.dart';
import 'package:critalarm/features/topics/domain/usecases/get_topics_usecase.dart';
import 'package:critalarm/features/topics/domain/usecases/topic_token_usecases.dart';
import 'package:critalarm/features/topics/domain/usecases/update_topic_usecase.dart';
import 'package:critalarm/features/topics/presentation/cubits/create_topic_cubit.dart';
import 'package:critalarm/features/topics/presentation/cubits/home_cubit.dart';
import 'package:critalarm/features/topics/presentation/cubits/home_setup_cubit.dart';
import 'package:critalarm/features/topics/presentation/cubits/topic_detail_cubit.dart';
import 'package:critalarm/features/topics/presentation/cubits/topic_tokens_cubit.dart';
import 'package:critalarm/firebase_options.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:http/http.dart' as http;
import 'package:purchases_flutter/purchases_flutter.dart' show CustomerInfo;
import 'package:shared_preferences/shared_preferences.dart';

final GetIt getIt = GetIt.instance;

/// Set once a Pro device has seen the App icon welcome. Never cleared.
const _appIconWelcomedKey = 'app_icon.welcomed';

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
    ..registerLazySingleton<AppIconHost>(AppIconHost.new)
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
    ..registerLazySingleton<AppearanceSettingsRepository>(
      () => SharedPrefsAppearanceSettingsRepository(getIt<SharedPreferences>()),
    )
    ..registerLazySingleton<PrivacyRepository>(
      () => SharedPrefsPrivacyRepository(getIt<SharedPreferences>()),
    )
    ..registerLazySingleton<AlarmSoundRepository>(
      () => SharedPrefsAlarmSoundRepository(getIt<SharedPreferences>()),
    )
    ..registerLazySingleton<SoundHost>(SoundHost.new)
    ..registerLazySingleton<SoundPackHost>(SoundPackHost.new)
    ..registerLazySingleton<SoundPackRepository>(
      () => SoundPackRepository(getIt<SoundPackHost>()),
    )
    ..registerLazySingleton<SoundPeaksCache>(
      () => SoundPeaksCache(getIt<SoundHost>()),
    )
    ..registerLazySingleton<SoundFilePicker>(PlatformSoundFilePicker.new)
    ..registerLazySingleton<NotificationPermissionRepository>(
      () => PlatformNotificationPermissionRepository(
        prefs: getIt<SharedPreferences>(),
      ),
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
    ..registerLazySingleton<InAppNoticeRepository>(
      () => SharedPrefsInAppNoticeRepository(getIt<SharedPreferences>()),
    )
    ..registerLazySingleton<LocalReminderStore>(
      () => SharedPrefsLocalReminderStore(getIt<SharedPreferences>()),
    )
    ..registerLazySingleton(
      () => LocalReminderSettler(
        store: getIt<LocalReminderStore>(),
        notices: getIt<InAppNoticeRepository>(),
      ),
    )
    // Web has no local notifications, so the dashboard gets the no-op.
    ..registerLazySingleton<LocalReminderScheduler>(
      () => kIsWeb
          ? const NoopLocalReminderScheduler()
          : NativeLocalReminderScheduler(),
    )
    ..registerLazySingleton<PlanStatusSource>(
      () => RevenueCatPlanStatusSource(getIt<SubscriptionRepository>()),
    )
    ..registerLazySingleton(
      () => LocalReminderInputsReader(
        store: getIt<LocalReminderStore>(),
        notices: getIt<InAppNoticeRepository>(),
        quietHours: getIt<QuietHoursStore>(),
        scheduler: getIt<LocalReminderScheduler>(),
        planStatus: getIt<PlanStatusSource>(),
        privacy: getIt<PrivacyRepository>(),
        readTopics: () async =>
            (await getIt<GetTopicsUsecase>()(const NoParams())).getOrNull(),
        readIncidents: () async => (await getIt<GetIncidentsUsecase>()(
          const GetIncidentsParams(limit: 50),
        )).getOrNull(),
        // A failed poll counts as "has messages": better to miss a reminder
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
        proShouldAsk: () => getIt<ProAskRules>().shouldAsk(),
        isSetupDone: () => getIt<SetupGate>().isDone(),
        countsAsRealUse: (incidentId) => countsAsRealUse(
          incidentId: incidentId,
          setupIncidentIds: getIt<SetupTestRing>().setupIncidentIds,
        ),
        isWeb: kIsWeb,
        isIos: !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS,
      ),
    )
    ..registerLazySingleton(
      () => LocalReminderPlanPass(
        store: getIt<LocalReminderStore>(),
        scheduler: getIt<LocalReminderScheduler>(),
        settler: getIt<LocalReminderSettler>(),
        readInputs: () => getIt<LocalReminderInputsReader>().read(),
        copy: LocalReminderCopy(
          isIos: !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS,
        ),
        // Nothing is planned during onboarding or a Feature
        // Guide. The app plans again when the guide ends.
        isPaused: () async => !await getIt<SetupGate>().isDone(),
      ),
    )
    // Web plans nothing.
    ..registerLazySingleton<LocalReminderPlanTrigger>(
      () => kIsWeb
          ? const NoopLocalReminderPlanTrigger()
          : getIt<LocalReminderPlanPass>(),
    )
    ..registerLazySingleton<SetupGate>(
      () => SetupGate(
        isOnboardingDone: () async {
          final done = await getIt<GetOnboardingCompletedUsecase>()(
            const NoParams(),
          );
          return done.getOrNull() ?? false;
        },
        hasSeenFeatureGuide: () => getIt<FeatureGuideCubit>().hasSeenFirstGuide,
        isFeatureGuideActive: () => getIt<FeatureGuideCubit>().state.isActive,
      ),
    )
    ..registerLazySingleton<ProAskRules>(
      () => ProAskRules(
        noticeRepository: getIt<InAppNoticeRepository>(),
        accountRepository: getIt<AccountRepository>(),
        offersOn: () => getIt<LocalReminderStore>().readSwitches().offers,
        isSetupDone: () => getIt<SetupGate>().isDone(),
      ),
    )
    ..registerLazySingleton<HomeAskRules>(
      () => HomeAskRules(
        noticeRepository: getIt<InAppNoticeRepository>(),
        privacyRepository: getIt<PrivacyRepository>(),
        settle: () =>
            getIt<LocalReminderSettler>().settleAsks(now: DateTime.now()),
        isSetupDone: () => getIt<SetupGate>().isDone(),
        // An ack made on another device counts too, and only the shared list
        // carries it. The review popup skips the whole day of one.
        // An alarm setup itself caused is left out: it is not real use.
        newestAckedAt: () => newestRealAckedAt(
          acks: [
            for (final incident in getIt<IncidentsCubit>().state.incidents)
              (id: incident.id, ackedAt: incident.ackedAt),
          ],
          setupIncidentIds: getIt<SetupTestRing>().setupIncidentIds,
        ),
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
    ..registerLazySingleton(
      () => LocalReminderAnalytics(getIt<TelemetryGate>()),
    )
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
      () => CompleteOnboardingUsecase(
        getIt<OnboardingProgressRepository>(),
        getIt<OnboardingFlowRepository>(),
        // Setup is over, so a connect failure shown during it is not
        // shown again on a setup screen opened later.
        () => getIt<BackgroundConnect>().dismissFailure(),
        getIt<FirstTopicHandoff>(),
        getIt<SetupTestRing>(),
      ),
    )
    // The one exit every "Set this up later" button takes.
    ..registerLazySingleton(
      () => SetUpLaterUsecase(getIt<CompleteOnboardingUsecase>()),
    )
    // The incident of the test alarm setup sent, kept for the steps after
    // the ring and cleared when setup completes.
    ..registerLazySingleton<SetupTestRing>(
      () => PrefsSetupTestRing(getIt<SharedPreferences>()),
    )
    // Ends a setup test on the server so it cannot ring again later.
    ..registerLazySingleton(
      () => EndSetupTestUsecase(
        getIt<SetupTestRing>(),
        getIt<AcknowledgeIncidentUsecase>(),
        getIt<CloseIncidentUsecase>(),
        // Told apart the way the rest of the app tells a test: the title
        // the test route gives its message.
        (incidentId) async {
          try {
            final incident = await getIt<ApiClient>().getIncident(incidentId);
            return incident.messages.any(
              (message) => message.title != IncidentKinds.testAlarmTitle,
            );
          } on ApiException catch (error) {
            // Gone from the server: nothing of the user's is in it.
            return error.statusCode == 404 ? false : null;
          }
        },
      ),
    )
    // How setup hears that an alarm reached this phone.
    ..registerLazySingleton<AlarmArrivals>(
      () => PlatformAlarmArrivals(
        push: getIt<PushHost>(),
        alarm: getIt<AlarmHost>(),
        alarmingIncidentIds: () =>
            getIt<IncidentAlarmController>().alarmingIncidentIds,
      ),
    )
    // The first topic setup made, held for the steps after it. The token stays
    // in memory and is cleared when setup completes.
    ..registerLazySingleton<FirstTopicHandoff>(
      () => PrefsFirstTopicHandoff(getIt<SharedPreferences>()),
    )
    ..registerLazySingleton<ToolTemplateStore>(
      () => SharedPrefsToolTemplateStore(getIt<SharedPreferences>()),
    )
    // "A first message arrived", set once, and where each topic's watch
    // for it starts from.
    ..registerLazySingleton<FirstMessageStore>(
      () => PrefsFirstMessageStore(getIt<SharedPreferences>()),
    )
    // One watcher per screen that waits for the first message. The screen
    // starts it, pauses it in the background and disposes it on leaving.
    ..registerFactory(
      () => FirstMessageWatcher(
        store: getIt<FirstMessageStore>(),
        source: ApiFirstMessageSource(api: getIt<ApiClient>()),
      ),
    )
    // The analytics switch on the last setup step. Setup events that are
    // held back until the user chooses hook in through `onAnswered`.
    ..registerLazySingleton(
      () => SetupStatsConsent(
        privacy: getIt<PrivacyRepository>(),
        telemetry: getIt<TelemetryGate>(),
      ),
    )
    ..registerLazySingleton<OnboardingFlowRepository>(
      () => SharedPrefsOnboardingFlowRepository(getIt<SharedPreferences>()),
    )
    // What a developer set for setup. A store build gets the one that holds
    // nothing, and ignores whatever the prefs contain.
    ..registerLazySingleton<DeveloperOnboardingOverrides>(
      () => developerOnboardingOverridesFor(getIt<SharedPreferences>()),
    )
    // Where a setup flow comes from, highest priority first. The bundled flow
    // is always there to fall back on. A store build never holds the
    // developer source.
    ..registerLazySingleton<OnboardingFlowSource>(
      () => buildHasOnboardingDeveloperTools
          ? DeveloperOnboardingFlowSource(
              overrides: getIt<DeveloperOnboardingOverrides>(),
              requires: OnboardingStepRegistry.requiresById,
            )
          : const EmptyOnboardingFlowSource(),
      instanceName: developerOnboardingFlowSource,
    )
    // Remote Config: reads what is already activated, never waits.
    ..registerLazySingleton<OnboardingFlowSource>(
      () => getIt.isRegistered<TelemetryGate>()
          ? RemoteOnboardingFlowSource(getIt<TelemetryGate>())
          : const EmptyOnboardingFlowSource(),
      instanceName: remoteOnboardingFlowSource,
    )
    // The real maker, or in a debug run the one DEVICE_MAKER names, so the
    // battery step can be looked at on an emulator.
    ..registerLazySingleton<DeviceMakerReader>(
      () => kDebugMode && buildDeviceMaker.isNotEmpty
          ? FixedDeviceMakerReader.named(buildDeviceMaker)
          : PlatformDeviceMakerReader(
              DeviceInfoPlugin(),
              platform: defaultTargetPlatform,
              isWeb: kIsWeb,
            ),
    )
    // The Android version is always the real one, whatever the maker says.
    ..registerLazySingleton<AndroidSdkReader>(
      () => PlatformDeviceMakerReader(
        DeviceInfoPlugin(),
        platform: defaultTargetPlatform,
        isWeb: kIsWeb,
      ),
    )
    // One reader for the permission steps and their statuses. The setup
    // flow and the permissions screen both ask it.
    ..registerLazySingleton(
      () => ReadPermissionSetupUsecase(
        platform: defaultTargetPlatform,
        isWeb: kIsWeb,
        checkNotifications: getIt<CheckNotificationPermissionUsecase>(),
        alarm: getIt<AlarmHost>(),
        devicePermissions: getIt<DevicePermissionsRepository>(),
        makerReader: getIt<DeviceMakerReader>(),
        sdkReader: getIt<AndroidSdkReader>(),
      ),
    )
    ..registerLazySingleton<OnboardingStepCatalog>(
      () {
        final on = OnboardingPlatform(
          platform: defaultTargetPlatform,
          isWeb: kIsWeb,
        );
        final registry = OnboardingStepRegistry(
          on: on,
          facts: DeviceOnboardingStepFacts(
            on: on,
            getConnection: getIt<GetConnectionUsecase>(),
            readPermissionSetup: getIt<ReadPermissionSetupUsecase>(),
            notices: getIt<InAppNoticeRepository>(),
            firstMessage: getIt<FirstMessageStore>(),
          ),
        );
        return buildHasOnboardingDeveloperTools
            ? ForcedUnsatisfiedStepCatalog(
                registry,
                getIt<DeveloperOnboardingOverrides>(),
              )
            : registry;
      },
    )
    ..registerLazySingleton(
      () => OnboardingFlowEngine(
        sources: [
          getIt<OnboardingFlowSource>(
            instanceName: developerOnboardingFlowSource,
          ),
          getIt<OnboardingFlowSource>(
            instanceName: remoteOnboardingFlowSource,
          ),
          const BundledOnboardingFlowSource(),
        ],
        catalog: getIt<OnboardingStepCatalog>(),
        repository: getIt<OnboardingFlowRepository>(),
        completeOnboarding: getIt<CompleteOnboardingUsecase>(),
        getOnboardingCompleted: getIt<GetOnboardingCompletedUsecase>(),
        // The permission steps are done. If a connect was waiting for this
        // phone's push token, this is the moment to try again.
        onStepEvent: (event) {
          if (event.kind == OnboardingStepEventKind.finished &&
              event.stepId == OnboardingStepId.permissions &&
              !event.isReplay) {
            unawaited(getIt<BackgroundConnect>().retryNow());
          }
        },
      ),
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
        getIt<OnboardingFlowEngine>(),
      ),
    )
    ..registerLazySingleton(
      () => ClearConnectionUsecase(
        getIt<ConnectionRepository>(),
        // Disconnecting also drops a connect that had not landed yet. It
        // goes first, so that connect cannot save a server in the gap.
        beforeClear: () => getIt<BackgroundConnect>().cancel(),
      ),
    )
    ..registerLazySingleton(
      () => ConnectIntentStore(getIt<SharedPreferences>()),
    )
    // One for the whole app run: the screen that starts a connect is gone
    // before it lands.
    ..registerLazySingleton(
      () => BackgroundConnect(
        intents: getIt<ConnectIntentStore>(),
        getServerInfo: getIt<GetServerInfoUsecase>(),
        establishSession: getIt<EstablishApiSessionUsecase>(),
        saveConnection: getIt<SaveConnectionUsecase>(),
        // Web registers no push, so its connect waits for no token.
        tokens: kIsWeb ? null : getIt<PushTokenProvider>(),
        // A Cloud connect makes this phone's account, so everything that
        // reads the account or the server loads again: topics, incidents
        // and the no-server card on Home.
        onConnected: () async => appAccountIdentityChanges.bump(),
        // A connect that gave up or was cancelled: the connect step is no
        // longer done, so a relaunch comes back to it.
        onAbandoned: () => getIt<OnboardingFlowEngine>().reopenStep(
          OnboardingStepId.connect,
        ),
        removeConnection: () async {
          await getIt<ConnectionRepository>().clearConnection();
        },
      ),
    )
    ..registerLazySingleton(
      () => GetAppearanceSettingsUsecase(
        getIt<AppearanceSettingsRepository>(),
      ),
    )
    ..registerLazySingleton(
      () => SetReduceMotionUsecase(getIt<AppearanceSettingsRepository>()),
    )
    ..registerLazySingleton(
      () => SetHapticsEnabledUsecase(getIt<AppearanceSettingsRepository>()),
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
        localReminderStore: getIt<LocalReminderStore>(),
        // Fire and forget: a slow or failed re-plan never blocks or fails
        // the test ring.
        onTested: (_) => unawaited(getIt<LocalReminderPlanTrigger>().run()),
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
    // guard that keeps sheets, notices and navigation away from an alarm
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
    ..registerLazySingleton<FeatureGuideRepository>(
      () => SharedPrefsFeatureGuideRepository(getIt<SharedPreferences>()),
    )
    // One for the whole app: the full Feature Guides replay walks across
    // screens.
    ..registerLazySingleton(
      () => FeatureGuideCubit(getIt<FeatureGuideRepository>()),
    )
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
          await getIt<LocalReminderStore>().recordTopicCreatedHere(
            topic.name,
            DateTime.now(),
          );
          // Starts the one-day wait before the backup notice. A no-op after
          // the first topic.
          await getIt<InAppNoticeRepository>().markFirstTopicOwned();
          unawaited(getIt<LocalReminderPlanTrigger>().run());
        },
      ),
    )
    ..registerLazySingleton(
      () => UpdateTopicUsecase(getIt<TopicRepository>()),
    )
    ..registerLazySingleton(
      () => DeleteTopicUsecase(
        getIt<TopicRepository>(),
        getIt<FirstMessageStore>(),
      ),
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
      ({bool replayForDemo, bool standalone})?
    >(
      (initialStep, mode) => NotificationPermissionsCubit(
        getIt<RequestNotificationPermissionUsecase>(),
        getIt<OpenNotificationSettingsUsecase>(),
        readSetup: getIt<ReadPermissionSetupUsecase>(),
        alarm: getIt<AlarmHost>(),
        devicePermissions: getIt<DevicePermissionsRepository>(),
        replayForDemo: mode?.replayForDemo ?? false,
        standalone: mode?.standalone ?? false,
        initialStep: initialStep ?? NotificationPermissionStep.initial,
      ),
    )
    ..registerFactoryParam<OnboardingConnectCubit, bool?, void>(
      (initialConnected, _) => OnboardingConnectCubit(
        getIt<GetServerInfoUsecase>(),
        getIt<SaveConnectionUsecase>(),
        setUpLater: getIt<SetUpLaterUsecase>(),
        establishSession: getIt<EstablishApiSessionUsecase>(),
        getConnection: getIt<GetConnectionUsecase>(),
        getTopics: getIt<GetTopicsUsecase>(),
        alarmHost: getIt<AlarmHost>(),
        readDraft: getIt<ReadOnboardingDraftUsecase>(),
        saveDraft: getIt<SaveOnboardingDraftUsecase>(),
        backgroundConnect: getIt<BackgroundConnect>(),
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
      () => AppearanceCubit(
        getIt<GetAppearanceSettingsUsecase>(),
        getIt<SetReduceMotionUsecase>(),
        getIt<SetHapticsEnabledUsecase>(),
      ),
    )
    ..registerFactory(
      () => AppIconCubit(
        readCurrent: () => getIt<AppIconHost>().current(),
        apply: (icon) => getIt<AppIconHost>().set(icon),
        readUnlocked: _proIconsUnlocked,
        readWelcomed: () async =>
            getIt<SharedPreferences>().getBool(_appIconWelcomedKey) ?? false,
        markWelcomed: () async {
          await getIt<SharedPreferences>().setBool(_appIconWelcomedKey, true);
        },
      ),
    )
    // Puts the default icon back once Pro has ended. Asks the store as well
    // as the server's tier before it does, because the tier can trail a
    // purchase by a few seconds and a wrong switch costs the user their icon.
    ..registerLazySingleton(
      () => AppIconGuard(
        readCurrent: () => getIt<AppIconHost>().current(),
        apply: (icon) => getIt<AppIconHost>().set(icon),
        readUnlocked: () async {
          final account = getIt<AccountRepository>();
          if (await account.readServerMode() != ServerMode.hosted) return true;
          if (await account.readIsPaid()) return true;
          if (buildSkipsPaywall) return false;
          return (await getIt<SubscriptionRepository>().isProActive())
                  .getOrNull() ??
              true;
        },
      ),
    )
    ..registerFactory(
      () => OnboardingWelcomeCubit(
        getIt<GetServerInfoUsecase>(),
      ),
    )
    ..registerFactoryParam<RealRingCubit, bool?, void>(
      (isReplay, _) => RealRingCubit(
        triggerTest: getIt<TriggerTestAlarmUsecase>(),
        updateTopic: getIt<UpdateTopicUsecase>(),
        // The app's one topic list. Loaded once if this step is the first
        // to need it, never fetched again here.
        readTopics: () async {
          final topics = getIt<TopicsCubit>();
          await topics.ensureLoaded();
          return topics.state.topics;
        },
        refreshTopics: () async {
          final topics = getIt<TopicsCubit>();
          await topics.refresh();
          return topics.state.topics;
        },
        hasConnection: () async =>
            (await getIt<GetConnectionUsecase>()(
              const NoParams(),
            )).getOrNull() !=
            null,
        connectState: () => getIt<BackgroundConnect>().state,
        connectChanges: getIt<BackgroundConnect>().stream,
        handoff: getIt<FirstTopicHandoff>(),
        ring: getIt<SetupTestRing>(),
        arrivals: getIt<AlarmArrivals>(),
        alarmHost: getIt<AlarmHost>(),
        onTopicUpdated: (topic) => getIt<TopicsCubit>().applyTopic(topic),
        isReplay: isReplay ?? false,
        on: OnboardingPlatform(platform: defaultTargetPlatform, isWeb: kIsWeb),
      ),
    )
    ..registerFactoryParam<HookUpCubit, bool?, void>(
      (isReplay, _) => HookUpCubit(
        handoff: getIt<FirstTopicHandoff>(),
        templates: getIt<ToolTemplateStore>(),
        createToken: getIt<CreateTopicTokenUsecase>(),
        readTopics: () async {
          final topics = getIt<TopicsCubit>();
          await topics.ensureLoaded();
          return topics.state.topics;
        },
        refreshTopics: () async {
          final topics = getIt<TopicsCubit>();
          await topics.refresh();
          return topics.state.topics;
        },
        readServerUrl: () async => (await getIt<GetConnectionUsecase>()(
          const NoParams(),
        )).getOrNull()?.serverUrl,
        watcher: getIt<FirstMessageWatcher>(),
        consent: getIt<SetupStatsConsent>(),
        revokeToken: getIt<RevokeTopicTokenUsecase>(),
        ring: getIt<SetupTestRing>(),
        isSetupComplete: () async =>
            (await getIt<GetOnboardingCompletedUsecase>()(
              const NoParams(),
            )).getOrNull() ??
            false,
        alarmArrivals: getIt<AlarmArrivals>().incidentIds,
        readIncidentTopic: (incidentId) async =>
            (await getIt<ApiClient>().getIncident(incidentId)).topic,
        alarmHost: getIt<AlarmHost>(),
        isReplay: isReplay ?? false,
        on: OnboardingPlatform(platform: defaultTargetPlatform, isWeb: kIsWeb),
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
    // The setup checklist and the widgets card on Home. Home content: it
    // goes through neither the notice slot nor `SetupGate`.
    ..registerLazySingleton<SetupChecklistStore>(
      () => PrefsSetupChecklistStore(getIt<SharedPreferences>()),
    )
    ..registerFactory(
      () => HomeSetupCubit(
        store: getIt<SetupChecklistStore>(),
        firstMessage: getIt<FirstMessageStore>(),
        source: ApiFirstMessageSource(api: getIt<ApiClient>()),
        newWatcher: getIt.get<FirstMessageWatcher>,
        readIncidentIds: () => [
          for (final incident in getIt<IncidentsCubit>().state.incidents)
            incident.id,
        ],
        readSetupIncidentIds: () => getIt<SetupTestRing>().setupIncidentIds,
        isGuideOfferAnswered: () =>
            getIt<FeatureGuideCubit>().hasSeenFirstGuide,
        // The same line the widgets themselves draw: locked on the hosted
        // plan without Hosted, open on a server that has no plans.
        readWidgetsPlan: () async {
          final account = getIt<AccountRepository>();
          if (await account.readServerMode() != ServerMode.hosted) {
            return HomeWidgetsPlan.selfHosted;
          }
          return await account.readIsPaid()
              ? HomeWidgetsPlan.hosted
              : HomeWidgetsPlan.needsHosted;
        },
        platform: defaultTargetPlatform,
        isWeb: kIsWeb,
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
            ..sessionStore = getIt<ApiSessionStore>()
            ..toolTemplates = getIt<ToolTemplateStore>()
            ..handoff = getIt<FirstTopicHandoff>(),
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
        () => getIt<OnboardingFlowEngine>().isStepSatisfied(
          OnboardingStepId.firstTopic,
        ),
        () => getIt<SetupTestRing>().incidentIds,
        () => getIt<OnboardingFlowEngine>().runningFlow().contains(
          OnboardingStepId.realRing,
        ),
        getIt<EndSetupTestUsecase>(),
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
            unawaited(getIt<LocalReminderPlanTrigger>().run()),
      ),
    )
    ..registerFactory(
      () => LocalReminderSettingsCubit(
        store: getIt<LocalReminderStore>(),
        scheduler: getIt<LocalReminderScheduler>(),
        readServerMode: () => getIt<AccountRepository>().readServerMode(),
        readIsPaid: () => getIt<AccountRepository>().readIsPaid(),
        trigger: getIt<LocalReminderPlanTrigger>(),
        analytics: getIt<LocalReminderAnalytics>(),
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
        store: getIt<LocalReminderStore>(),
        canTestNormalTopics: LocalReminderServerSupport.testsNormalTopics,
        analytics: getIt<LocalReminderAnalytics>(),
      ),
    )
    ..registerFactory(
      () => LocalReminderLabCubit(
        store: getIt<LocalReminderStore>(),
        notices: getIt<InAppNoticeRepository>(),
        scheduler: getIt<LocalReminderScheduler>(),
        copy: LocalReminderCopy(
          isIos: !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS,
        ),
        trigger: getIt<LocalReminderPlanTrigger>(),
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
        packs: getIt<SoundPackRepository>(),
      ),
    )
    ..registerFactory(
      () => DevicePermissionsCubit(
        getIt<GetDevicePermissionsUsecase>(),
        getIt<OpenPermissionSettingsUsecase>(),
        checkNotifications: getIt<CheckNotificationPermissionUsecase>(),
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
        notices: getIt<InAppNoticeRepository>(),
        plan: getIt<PlanStatusSource>(),
        readIdentity: () => getIt<DeviceIdentityStore>().readOrCreate(),
        readServerMode: () => getIt<AccountRepository>().readServerMode(),
        refreshRegistration: () async {
          if (!buildSkipsPaywall) {
            await getIt<RevenueCatService>().invalidateCustomerInfoCache();
          }
          await getIt<RegisterDeviceUsecase>()(appVersion: appVersion);
        },
        onPaidChanged: () {
          getIt<WidgetSync>().rewrite();
          unawaited(getIt<AppIconGuard>().check());
        },
      ),
    )
    ..registerFactoryParam<InAppNoticeCubit, ShellCubit?, void>(
      (shellCubit, _) => InAppNoticeCubit(
        getConnectionUsecase: getIt<GetConnectionUsecase>(),
        shellCubit: shellCubit ?? getIt<ShellCubit>(),
        identityRepository: getIt<IdentityRepository>(),
        accountRepository: getIt<AccountRepository>(),
        noticeRepository: getIt<InAppNoticeRepository>(),
        readTopics: () async =>
            (await getIt<GetTopicsUsecase>()(const NoParams())).getOrNull(),
        proEnding: getIt<ProEnding>(),
        identityChanges: appAccountIdentityChanges,
        isSetupDone: () => getIt<SetupGate>().isDone(),
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

/// True when the Pro app icons are open to this device: it is on Pro, or it
/// talks to a server with no plans. The same line widgets draw, except that a
/// device not connected anywhere yet also sees them locked.
Future<bool> _proIconsUnlocked() async {
  final account = getIt<AccountRepository>();
  final mode = await account.readServerMode();
  if (mode == null) return false;
  if (mode != ServerMode.hosted) return true;
  return account.readIsPaid();
}
