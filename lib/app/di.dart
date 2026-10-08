import 'dart:async';
import 'dart:convert';

import 'package:critalarm/app/access/hosted_holding_source.dart';
import 'package:critalarm/app/access/observed_api_session_store.dart';
import 'package:critalarm/app/access/pro_holding_source.dart';
import 'package:critalarm/app/access/sure_lock.dart';
import 'package:critalarm/app/account_data.dart';
import 'package:critalarm/app/challenge_flag_sync.dart';
import 'package:critalarm/app/initial_route_resolver.dart';
import 'package:critalarm/app/router.dart';
import 'package:critalarm/app/shell/shell_cubit.dart';
import 'package:critalarm/app/sound_lock_sync.dart';
import 'package:critalarm/app/state/incidents_cubit.dart';
import 'package:critalarm/app/state/topics_cubit.dart';
import 'package:critalarm/app/widget_sync.dart';
import 'package:critalarm/core/access/access_override.dart';
import 'package:critalarm/core/access/app_feature.dart';
import 'package:critalarm/core/access/dev_access_switches.dart';
import 'package:critalarm/core/access/feature_access.dart';
import 'package:critalarm/core/access/feature_decision.dart';
import 'package:critalarm/core/access/holding.dart';
import 'package:critalarm/core/access/holdings.dart';
import 'package:critalarm/core/account/account_identity_changes.dart';
import 'package:critalarm/core/account/account_tag.dart';
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
import 'package:critalarm/core/api/http_api_client.dart';
import 'package:critalarm/core/api/mock_api_client.dart';
import 'package:critalarm/core/api/mock_server.dart';
import 'package:critalarm/core/api/packs_api.dart';
import 'package:critalarm/core/api/weekly_check_api.dart';
import 'package:critalarm/core/app_icon/app_icon_guard.dart';
import 'package:critalarm/core/app_icon/app_icon_host.dart';
import 'package:critalarm/core/device/device_build_mode.dart';
import 'package:critalarm/core/device/device_form.dart';
import 'package:critalarm/core/device/device_maker.dart';
import 'package:critalarm/core/device/os_version_reader.dart';
import 'package:critalarm/core/device/platform_device_maker_reader.dart';
import 'package:critalarm/core/device/platform_os_version_reader.dart';
import 'package:critalarm/core/env/env.dart';
import 'package:critalarm/core/links/connect_link_holder.dart';
import 'package:critalarm/core/models/account_access.dart';
import 'package:critalarm/core/net/launch_call_log.dart';
import 'package:critalarm/core/notifications/app_badge.dart';
import 'package:critalarm/core/paywall/dev_paywall_variant_switch.dart';
import 'package:critalarm/core/paywall/dev_pro_switch.dart';
import 'package:critalarm/core/paywall/paywall_build_mode.dart';
import 'package:critalarm/core/paywall/paywall_layout_setting.dart';
import 'package:critalarm/core/paywall/paywall_variant.dart';
import 'package:critalarm/core/paywall/pro_override.dart';
import 'package:critalarm/core/platform/platform_capabilities.dart';
import 'package:critalarm/core/push/apns_push_token_provider.dart';
import 'package:critalarm/core/push/firebase_push_token_provider.dart';
import 'package:critalarm/core/push/last_push_reader.dart';
import 'package:critalarm/core/push/push_event_drain.dart';
import 'package:critalarm/core/push/push_host.dart';
import 'package:critalarm/core/push/push_token_provider.dart';
import 'package:critalarm/core/push/relay_confirmation_store.dart';
import 'package:critalarm/core/sound/incoming_audio.dart';
import 'package:critalarm/core/sound/own_sound_lock_flag.dart';
import 'package:critalarm/core/sound/own_sound_rule.dart';
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
import 'package:critalarm/core/telemetry/connect_link_analytics.dart';
import 'package:critalarm/core/telemetry/firebase_telemetry_gate.dart';
import 'package:critalarm/core/telemetry/local_reminder_analytics.dart';
import 'package:critalarm/core/telemetry/onboarding_funnel.dart';
import 'package:critalarm/core/telemetry/paywall_analytics.dart';
import 'package:critalarm/core/telemetry/telemetry_gate.dart';
import 'package:critalarm/core/ui_sound/interface_sounds_setting.dart';
import 'package:critalarm/core/ui_sound/intro_sound_flavour.dart';
import 'package:critalarm/core/ui_sound/paywall_cues.dart';
import 'package:critalarm/core/ui_sound/playing_paywall_cues.dart';
import 'package:critalarm/core/ui_sound/ui_sound_host.dart';
import 'package:critalarm/core/usecase/usecase.dart';
import 'package:critalarm/core/version/app_version.dart';
import 'package:critalarm/core/widgets/widget_host.dart';
import 'package:critalarm/design_system/edge_effect.dart';
import 'package:critalarm/design_system/haptics.dart';
import 'package:critalarm/features/account/data/repositories/api_account_repository.dart';
import 'package:critalarm/features/account/data/repositories/http_identity_repository.dart';
import 'package:critalarm/features/account/data/services/provider_sign_in.dart';
import 'package:critalarm/features/account/domain/repositories/account_repository.dart';
import 'package:critalarm/features/account/domain/repositories/identity_repository.dart';
import 'package:critalarm/features/account/presentation/cubits/account_cubit.dart';
import 'package:critalarm/features/challenges/data/shared_prefs_challenge_choices.dart';
import 'package:critalarm/features/challenges/domain/challenge_choices.dart';
import 'package:critalarm/features/challenges/domain/challenge_gate.dart';
import 'package:critalarm/features/challenges/presentation/challenge.dart';
import 'package:critalarm/features/feature_guides/data/repositories/shared_prefs_feature_guide_repository.dart';
import 'package:critalarm/features/feature_guides/domain/repositories/feature_guide_repository.dart';
import 'package:critalarm/features/feature_guides/presentation/cubits/feature_guide_cubit.dart';
import 'package:critalarm/features/feedback/data/platform_device_report_repository.dart';
import 'package:critalarm/features/feedback/domain/repositories/device_report_repository.dart';
import 'package:critalarm/features/history/presentation/cubits/history_cubit.dart';
import 'package:critalarm/features/in_app_notices/data/repositories/shared_prefs_in_app_notice_repository.dart';
import 'package:critalarm/features/in_app_notices/domain/day0_card_rules.dart';
import 'package:critalarm/features/in_app_notices/domain/home_ask_rules.dart';
import 'package:critalarm/features/in_app_notices/domain/pro_ask_rules.dart';
import 'package:critalarm/features/in_app_notices/domain/pro_ending.dart';
import 'package:critalarm/features/in_app_notices/domain/repositories/in_app_notice_repository.dart';
import 'package:critalarm/features/in_app_notices/domain/setup_gate.dart';
import 'package:critalarm/features/in_app_notices/presentation/cubits/day0_card_cubit.dart';
import 'package:critalarm/features/in_app_notices/presentation/cubits/in_app_notice_cubit.dart';
import 'package:critalarm/features/incidents/data/own_look/file_own_look_store.dart';
import 'package:critalarm/features/incidents/data/own_look/platform_own_photo_picker.dart';
import 'package:critalarm/features/incidents/data/own_look/ui_own_photo_codec.dart';
import 'package:critalarm/features/incidents/data/repositories/in_memory_incident_repository.dart';
import 'package:critalarm/features/incidents/data/shared_prefs_alarm_style_choices.dart';
import 'package:critalarm/features/incidents/domain/alarm_style/alarm_style_choices.dart';
import 'package:critalarm/features/incidents/domain/alarm_style/alarm_style_gate.dart';
import 'package:critalarm/features/incidents/domain/alarm_style/own_look_store.dart';
import 'package:critalarm/features/incidents/domain/alarm_style/own_photo_import.dart';
import 'package:critalarm/features/incidents/domain/real_use.dart';
import 'package:critalarm/features/incidents/domain/repositories/incident_repository.dart';
import 'package:critalarm/features/incidents/domain/usecases/acknowledge_incident_usecase.dart';
import 'package:critalarm/features/incidents/domain/usecases/close_incident_usecase.dart';
import 'package:critalarm/features/incidents/domain/usecases/get_incident_usecase.dart';
import 'package:critalarm/features/incidents/domain/usecases/get_incidents_usecase.dart';
import 'package:critalarm/features/incidents/domain/usecases/trigger_test_alarm_usecase.dart';
import 'package:critalarm/features/incidents/presentation/alarm_style/own_alarm_look_keeper.dart';
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
import 'package:critalarm/features/onboarding/data/repositories/observed_connection_repository.dart';
import 'package:critalarm/features/onboarding/data/repositories/platform_alarm_arrivals.dart';
import 'package:critalarm/features/onboarding/data/repositories/platform_notification_permission_repository.dart';
import 'package:critalarm/features/onboarding/data/repositories/prefs_setup_test_ring.dart';
import 'package:critalarm/features/onboarding/data/repositories/shared_prefs_connection_repository.dart';
import 'package:critalarm/features/onboarding/data/repositories/shared_prefs_developer_onboarding_overrides.dart';
import 'package:critalarm/features/onboarding/data/repositories/shared_prefs_onboarding_flow_repository.dart';
import 'package:critalarm/features/onboarding/data/repositories/shared_prefs_onboarding_progress_repository.dart';
import 'package:critalarm/features/onboarding/domain/connect/background_connect.dart';
import 'package:critalarm/features/onboarding/domain/connect/connect_intent_store.dart';
import 'package:critalarm/features/onboarding/domain/entities/notification_permission_status.dart';
import 'package:critalarm/features/onboarding/domain/flow/developer_onboarding.dart';
import 'package:critalarm/features/onboarding/domain/flow/onboarding_flow.dart';
import 'package:critalarm/features/onboarding/domain/flow/onboarding_flow_engine.dart';
import 'package:critalarm/features/onboarding/domain/flow/onboarding_flow_source.dart';
import 'package:critalarm/features/onboarding/domain/flow/onboarding_funnel_hook.dart';
import 'package:critalarm/features/onboarding/domain/flow/onboarding_step_catalog.dart';
import 'package:critalarm/features/onboarding/domain/flow/onboarding_step_facts.dart';
import 'package:critalarm/features/onboarding/domain/flow/remote_onboarding_flow_source.dart';
import 'package:critalarm/features/onboarding/domain/offer/onboarding_offer_rule.dart';
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
import 'package:critalarm/features/onboarding/domain/usecases/connect_to_server_usecase.dart';
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
import 'package:critalarm/features/paywall/domain/entities/paywall_product.dart';
import 'package:critalarm/features/paywall/domain/repositories/subscription_repository.dart';
import 'package:critalarm/features/paywall/domain/usecases/get_customer_info_usecase.dart';
import 'package:critalarm/features/paywall/domain/usecases/get_offerings_usecase.dart';
import 'package:critalarm/features/paywall/domain/usecases/purchase_package_usecase.dart';
import 'package:critalarm/features/paywall/domain/usecases/restore_purchases_usecase.dart';
import 'package:critalarm/features/paywall/presentation/cubits/paywall_cubit.dart';
import 'package:critalarm/features/paywall/presentation/cubits/pro_status_cubit.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/demo_paywall_buy_cubit.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/hosted_paywall_buy_cubit.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_buy_cubit.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_layout_registry.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/pro_paywall_buy_cubit.dart';
import 'package:critalarm/features/paywall/presentation/paywall_door.dart';
import 'package:critalarm/features/permissions/data/repositories/platform_device_permissions_repository.dart';
import 'package:critalarm/features/permissions/domain/repositories/device_permissions_repository.dart';
import 'package:critalarm/features/permissions/domain/usecases/get_device_permissions_usecase.dart';
import 'package:critalarm/features/permissions/domain/usecases/open_permission_settings_usecase.dart';
import 'package:critalarm/features/permissions/presentation/cubits/device_permissions_cubit.dart';
import 'package:critalarm/features/pro_pack/data/prefs_pro_pack_dev_switch.dart';
import 'package:critalarm/features/pro_pack/data/revenuecat_pro_pack_shop.dart';
import 'package:critalarm/features/pro_pack/data/shared_prefs_pro_pack_store.dart';
import 'package:critalarm/features/pro_pack/domain/pro_pack.dart';
import 'package:critalarm/features/pro_pack/domain/pro_pack_access.dart';
import 'package:critalarm/features/pro_pack/domain/pro_pack_analytics.dart';
import 'package:critalarm/features/pro_pack/domain/pro_pack_override.dart';
import 'package:critalarm/features/pro_pack/domain/pro_pack_shop.dart';
import 'package:critalarm/features/pro_pack/domain/pro_pack_store.dart';
import 'package:critalarm/features/pro_pack/presentation/cubits/pro_pack_sheet_cubit.dart';
import 'package:critalarm/features/reliability/data/platform_maker_settings_opener.dart';
import 'package:critalarm/features/reliability/data/platform_phone_capture.dart';
import 'package:critalarm/features/reliability/data/platform_scheduled_summary_reader.dart';
import 'package:critalarm/features/reliability/data/shared_prefs_maker_guide_store.dart';
import 'package:critalarm/features/reliability/data/shared_prefs_missed_alarm_store.dart';
import 'package:critalarm/features/reliability/data/shared_prefs_os_version_store.dart';
import 'package:critalarm/features/reliability/domain/maker/maker_guide.dart';
import 'package:critalarm/features/reliability/domain/maker/maker_guide_store.dart';
import 'package:critalarm/features/reliability/domain/maker/maker_settings_opener.dart';
import 'package:critalarm/features/reliability/domain/missed_alarm/missed_alarm_reader.dart';
import 'package:critalarm/features/reliability/domain/missed_alarm/missed_alarm_store.dart';
import 'package:critalarm/features/reliability/domain/os_version_store.dart';
import 'package:critalarm/features/reliability/domain/reliability_fix_runner.dart';
import 'package:critalarm/features/reliability/domain/scheduled_summary_reader.dart';
import 'package:critalarm/features/reliability/domain/sources/last_push_source.dart';
import 'package:critalarm/features/reliability/domain/sources/missed_alarm_source.dart';
import 'package:critalarm/features/reliability/domain/sources/permissions_source.dart';
import 'package:critalarm/features/reliability/domain/sources/phone_maker_source.dart';
import 'package:critalarm/features/reliability/domain/sources/push_token_source.dart';
import 'package:critalarm/features/reliability/domain/sources/system_update_source.dart';
import 'package:critalarm/features/reliability/domain/sources/time_sensitive_source.dart';
import 'package:critalarm/features/reliability/presentation/cubits/reliability_cubit.dart';
import 'package:critalarm/features/reliability/presentation/maker/maker_guide_cubit.dart';
import 'package:critalarm/features/search/data/repositories/asset_docs_index_repository.dart';
import 'package:critalarm/features/search/data/repositories/shared_prefs_recent_searches_repository.dart';
import 'package:critalarm/features/search/domain/repositories/docs_index_repository.dart';
import 'package:critalarm/features/search/domain/repositories/recent_searches_repository.dart';
import 'package:critalarm/features/search/domain/usecases/add_recent_search_usecase.dart';
import 'package:critalarm/features/search/domain/usecases/clear_recent_searches_usecase.dart';
import 'package:critalarm/features/search/domain/usecases/get_docs_index_usecase.dart';
import 'package:critalarm/features/search/domain/usecases/get_recent_searches_usecase.dart';
import 'package:critalarm/features/search/presentation/cubits/search_cubit.dart';
import 'package:critalarm/features/settings/data/repositories/observed_privacy_repository.dart';
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
import 'package:critalarm/features/settings/presentation/cubits/personalize_cubit.dart';
import 'package:critalarm/features/settings/presentation/cubits/priorities_cubit.dart';
import 'package:critalarm/features/settings/presentation/cubits/recorder_cubit.dart';
import 'package:critalarm/features/settings/presentation/cubits/settings_cubit.dart';
import 'package:critalarm/features/settings/presentation/cubits/sound_crop_cubit.dart';
import 'package:critalarm/features/settings/presentation/cubits/sound_picker_cubit.dart';
import 'package:critalarm/features/settings/presentation/cubits/theme_cubit.dart';
import 'package:critalarm/features/topics/data/api_first_message_source.dart';
import 'package:critalarm/features/topics/data/prefs_first_message_store.dart';
import 'package:critalarm/features/topics/data/prefs_first_topic_handoff.dart';
import 'package:critalarm/features/topics/data/prefs_setup_checklist_store.dart';
import 'package:critalarm/features/topics/data/reader_missed_alarm_feed.dart';
import 'package:critalarm/features/topics/data/repositories/in_memory_topic_repository.dart';
import 'package:critalarm/features/topics/data/repositories/shared_prefs_topic_list_prefs_repository.dart';
import 'package:critalarm/features/topics/data/shared_prefs_tool_template_store.dart';
import 'package:critalarm/features/topics/domain/first_message/first_message_store.dart';
import 'package:critalarm/features/topics/domain/first_message/first_message_watcher.dart';
import 'package:critalarm/features/topics/domain/first_topic_handoff.dart';
import 'package:critalarm/features/topics/domain/missed_alarm_feed.dart';
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
import 'package:critalarm/features/topics/presentation/cubits/home_card_cubit.dart';
import 'package:critalarm/features/topics/presentation/cubits/home_cubit.dart';
import 'package:critalarm/features/topics/presentation/cubits/home_setup_cubit.dart';
import 'package:critalarm/features/topics/presentation/cubits/topic_detail_cubit.dart';
import 'package:critalarm/features/topics/presentation/cubits/topic_tokens_cubit.dart';
import 'package:critalarm/features/weekly_check/data/shared_prefs_weekly_check_store.dart';
import 'package:critalarm/features/weekly_check/domain/weekly_check_monitor.dart';
import 'package:critalarm/features/weekly_check/domain/weekly_check_source.dart';
import 'package:critalarm/features/weekly_check/domain/weekly_check_store.dart';
import 'package:critalarm/features/weekly_check/presentation/cubits/weekly_check_cubit.dart';
import 'package:critalarm/features/weekly_check/presentation/cubits/weekly_check_rounds_cubit.dart';
import 'package:critalarm/firebase_options.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
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
    // The one store behind every developer plan switch: a state per
    // holding and a server mode, set by the Plans and features lab. The
    // only place it is handed to the rest of the app. In a store build
    // appAccessOverride is a NoAccessOverride and this call does nothing.
    if (!getIt.isRegistered<DevAccessSwitches>()) {
      getIt.registerSingleton<DevAccessSwitches>(DevAccessSwitches(prefs));
    }
    final accessSwitches = getIt<DevAccessSwitches>();
    appAccessOverride.watch(accessSwitches);

    // The two older toggles are "force held" on that same store. The older
    // override classes hear it too, for the three readers that are not
    // Holdings: the shipped Hosted paywall, the Settings plan row and the
    // Pro sheet. In a store build both are compiled as the No variant.
    if (!getIt.isRegistered<DevProSwitch>()) {
      getIt.registerSingleton<DevProSwitch>(DevProSwitch(accessSwitches));
    }
    appProOverride.watch(getIt<DevProSwitch>());
    if (!getIt.isRegistered<ProPackDevSwitch>()) {
      getIt.registerSingleton<ProPackDevSwitch>(
        PrefsProPackDevSwitch(accessSwitches),
      );
    }
    appProPackOverride.watch(getIt<ProPackDevSwitch>());
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

  if (buildHasPaywallLayoutSwitch) {
    // What each product's paywall opens, set in Developer options. A store
    // build compiles appPaywallLayoutOverride as a NoPaywallLayoutOverride,
    // registers nothing here and follows the remote values.
    if (!getIt.isRegistered<DevPaywallLayoutSwitches>()) {
      getIt.registerSingleton<DevPaywallLayoutSwitches>(
        DevPaywallLayoutSwitches(
          hosted: DevPaywallLayoutSwitch(
            prefs,
            DevPaywallLayoutSwitch.hostedKey,
          ),
          pro: DevPaywallLayoutSwitch(prefs, DevPaywallLayoutSwitch.proKey),
          hostedIntro: DevPaywallIntroSwitch(
            prefs,
            DevPaywallIntroSwitch.hostedKey,
          ),
          proIntro: DevPaywallIntroSwitch(prefs, DevPaywallIntroSwitch.proKey),
          hostedThanks: DevPaywallThanksSwitch(
            prefs,
            DevPaywallThanksSwitch.hostedKey,
          ),
          proThanks: DevPaywallThanksSwitch(
            prefs,
            DevPaywallThanksSwitch.proKey,
          ),
        ),
      );
    }
    // Which flavour the intro scores play in. A store build has no switch
    // and plays the first.
    if (!getIt.isRegistered<DevIntroSoundSwitch>()) {
      getIt.registerSingleton<DevIntroSoundSwitch>(DevIntroSoundSwitch(prefs));
    }
    final layoutSwitches = getIt<DevPaywallLayoutSwitches>();
    appPaywallLayoutOverride.watch(
      hosted: layoutSwitches.hosted,
      pro: layoutSwitches.pro,
      hostedIntro: layoutSwitches.hostedIntro,
      proIntro: layoutSwitches.proIntro,
      hostedThanks: layoutSwitches.hostedThanks,
      proThanks: layoutSwitches.proThanks,
    );
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
  appEdgeEffect.value = autoEdgeEffect(
    platform: defaultTargetPlatform,
    shaderSupported: await loadEdgeBlurShader(),
    isLowRamDevice: deviceForm.isLowRamDevice,
  );

  // The one place that reads `kIsWeb` for feature code. Features ask
  // `PlatformCapabilities` and never read the global themselves.
  final capabilities = PlatformCapabilities(
    isWeb: kIsWeb,
    platform: defaultTargetPlatform,
  );

  getIt
    ..registerSingleton<PlatformCapabilities>(capabilities)
    ..registerSingleton<SharedPreferences>(prefs)
    ..registerSingleton<DeviceForm>(deviceForm)
    ..registerLazySingleton<TopicListPrefsRepository>(
      () => SharedPrefsTopicListPrefsRepository(getIt<SharedPreferences>()),
    )
    // A connect link the user tapped waits here, in memory only, until a
    // screen takes it.
    ..registerLazySingleton<ConnectLinkHolder>(ConnectLinkHolder.new)
    ..registerLazySingleton<PushHost>(
      () => PushHost(null, getIt<ConnectLinkHolder>()),
    )
    ..registerLazySingleton<NseCredentialStore>(NseCredentialStore.new)
    ..registerLazySingleton<WidgetHost>(WidgetHost.new)
    ..registerLazySingleton<AppIconHost>(AppIconHost.new)
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
              readDeviceToken: () async =>
                  (await getIt<DeviceIdentityStore>().readOrCreate())
                      .deviceToken,
              readDeviceId: () async =>
                  (await getIt<DeviceIdentityStore>().readOrCreate()).deviceId,
            ),
    )
    // The weekly check routes live on the same client too.
    ..registerLazySingleton<WeeklyCheckApi>(() {
      final Object api = getIt<ApiClient>();
      return api is WeeklyCheckApi ? api : const NoWeeklyCheckApi();
    })
    ..registerLazySingleton<WeeklyCheckStore>(
      () => SharedPrefsWeeklyCheckStore(getIt<SharedPreferences>()),
    )
    ..registerLazySingleton<WeeklyCheckMonitor>(() {
      final monitor = WeeklyCheckMonitor(
        api: getIt<WeeklyCheckApi>(),
        store: getIt<WeeklyCheckStore>(),
        readDeviceId: () async =>
            (await getIt<DeviceIdentityStore>().readOrCreate()).deviceId,
        onPackRefused: (packId) => getIt<ProPackAccess>().relayRefused(packId),
      );
      // Gaining or losing the pack changes what the relay answers for the
      // weekly check, so it is read again at once.
      _proPackHeldChanges().listen(
        (_) => unawaited(monitor.refresh(force: true)),
      );
      return monitor;
    })
    ..registerLazySingleton<WeeklyCheckCubit>(
      () => WeeklyCheckCubit(
        monitor: getIt<WeeklyCheckMonitor>(),
        // Words the row for a phone on its own server: the check covers
        // the push relay and not that server.
        readIsSelfHosted: () => getIt<FeatureAccess>().isOwnServerOnceReady(),
      ),
    )
    ..registerFactory(() => WeeklyCheckRoundsCubit(getIt<WeeklyCheckApi>()))
    // The pack routes live on the same client. A client swapped in by a test
    // that does not speak them gets the one that always fails.
    ..registerLazySingleton<PacksApi>(() {
      final Object api = getIt<ApiClient>();
      return api is PacksApi ? api : const NoPacksApi();
    })
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
    )
    // What this install holds. One source per thing a person can buy, and
    // the sources are the only readers of the store, the relay's answer and
    // the developer switches.
    ..registerLazySingleton<HostedHoldingSource>(
      () => HostedHoldingSource(
        readIdentity: () => getIt<DeviceIdentityStore>().readOrCreate(),
        // The source keeps the last tier it read. Every write to the store
        // makes it read again, so a sign-out or a deleted account never
        // leaves the old tier standing.
        identityChanges: [
          appAccountIdentityChanges,
          getIt<DeviceIdentityStore>().changes,
        ],
        readStore: buildSkipsPaywall ? null : getIt.get<SubscriptionRepository>,
        // The developer switch is not read in here. It reaches Holdings
        // through the wrapper below, so this source says what the server
        // and the store say.
        proOverride: const NoProOverride(),
      ),
    )
    // Each source with the developer override in front of it: the one seam
    // that can force a holding's state, for every holding. A store build
    // compiles the override as a NoAccessOverride, and each wrapper then
    // answers with its source's own state.
    ..registerLazySingleton<List<OverriddenHoldingSource>>(
      () => [
        OverriddenHoldingSource(getIt<HostedHoldingSource>()),
        OverriddenHoldingSource(
          ProHoldingSource(getIt<ProPackAccess>(), countsDevSwitch: false),
        ),
      ],
    )
    ..registerLazySingleton<Holdings>(
      () => Holdings(getIt<List<OverriddenHoldingSource>>()),
    )
    // The saved session's server mode, with the same override in front.
    ..registerLazySingleton<OverriddenServerMode>(
      () => OverriddenServerMode(getIt<ObservedApiSessionStore>().mode),
    )
    // Whether a feature is open. The server mode comes from the saved
    // session: the one on disk at launch, then every connect that writes a
    // new one.
    ..registerLazySingleton<FeatureAccess>(() {
      final sessions = getIt<ObservedApiSessionStore>();
      final mode = getIt<OverriddenServerMode>();
      final access = FeatureAccess(
        holdings: getIt<Holdings>(),
        serverMode: mode.value,
        // `ready` waits for this, so nothing is taken away from a phone on
        // its own server before the saved session says so.
        serverModeRead: sessions.read().then<void>(
          (_) {},
          onError: (Object _) {},
        ),
      );
      mode.changes.addListener(() => access.setServerMode(mode.value));
      return access;
    })
    // A build that skips the store has nothing on sale.
    ..registerLazySingleton<ProPackShop>(
      () => buildSkipsPaywall
          ? const ClosedProPackShop()
          : RevenueCatProPackShop(getIt<RevenueCatService>()),
    )
    ..registerFactory(
      () => ProPackSheetCubit(
        access: getIt<ProPackAccess>(),
        shop: getIt<ProPackShop>(),
        analytics: getIt.isRegistered<TelemetryGate>()
            ? ProPackAnalytics(getIt<TelemetryGate>())
            : null,
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
      () => ObservedConnectionRepository(
        KeychainMirrorConnectionRepository(
          SharedPrefsConnectionRepository(getIt<SharedPreferences>()),
          getIt<NseCredentialStore>(),
          widgets: getIt<WidgetHost>(),
        ),
        // The missed alarm check counts an incident only from the moment
        // this phone connected to its server, so it hears every save and
        // every removal here, when it happens.
        onSaved: (serverUrl) =>
            getIt<MissedAlarmReader>().connectionSaved(serverUrl),
        onCleared: () => getIt<MissedAlarmReader>().connectionCleared(),
      ),
    )
    ..registerLazySingleton<OnboardingProgressRepository>(
      () => SharedPrefsOnboardingProgressRepository(getIt<SharedPreferences>()),
    )
    ..registerLazySingleton<AppearanceSettingsRepository>(
      () => SharedPrefsAppearanceSettingsRepository(getIt<SharedPreferences>()),
    )
    // Every analytics answer is saved through this one repository, so the
    // setup funnel hears the setup switch, Settings > Privacy and the Home
    // consent sheet without each of them knowing about it.
    ..registerLazySingleton<PrivacyRepository>(
      () => ObservedPrivacyRepository(
        SharedPrefsPrivacyRepository(getIt<SharedPreferences>()),
        onAnalyticsChoice: ({required isOn}) =>
            getIt<OnboardingFunnel>().answered(isOn: isOn),
      ),
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
        capabilities: getIt<PlatformCapabilities>(),
        prefs: getIt<SharedPreferences>(),
      ),
    )
    ..registerLazySingleton<DevicePermissionsRepository>(
      () => PlatformDevicePermissionsRepository(
        capabilities: getIt<PlatformCapabilities>(),
        alarm: getIt<AlarmHost>(),
      ),
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
        beforePacksRequest: () => getIt<ProPackAccess>().beginRelayRequest(),
        onPacks: (response, {relayUri, request}) =>
            getIt<ProPackAccess>().relayAnswered(
              accountId: response.accountId,
              packs: response.packs,
              tier: response.tier, // access-ok: hands it to the Pro source
              relay: relayUri,
              request: request,
            ),
      ),
    )
    ..registerLazySingleton(
      () => EstablishApiSessionUsecase(
        getIt<ApiSessionStore>(),
        getIt<RegisterDeviceUsecase>(),
        getIt<DeviceIdentityStore>(),
      ),
    )
    ..registerLazySingleton<ProviderSignIn>(
      () => NativeProviderSignIn(capabilities: getIt<PlatformCapabilities>()),
    )
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
        forgetAccountData: () => getIt<AccountData>().forget(),
        signOutBilling: buildSkipsPaywall
            ? null
            : () => getIt<RevenueCatService>().logOut(),
        stopAlarm: getIt<AlarmHost>().stopRinging,
        holdings: getIt<Holdings>(),
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
        readHoldsHosted: _holdsHosted,
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
        isWeb: getIt<PlatformCapabilities>().isWeb,
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
        isWeb: getIt<PlatformCapabilities>().isWeb,
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
    ..registerLazySingleton(() => Day0CardAnalytics(getIt<TelemetryGate>()))
    ..registerLazySingleton<Day0CardRules>(
      () => Day0CardRules(
        noticeRepository: getIt<InAppNoticeRepository>(),
        accountRepository: getIt<AccountRepository>(),
        firstMessageStore: getIt<FirstMessageStore>(),
        isWeb: getIt<PlatformCapabilities>().isWeb,
        isSetupDone: () => getIt<SetupGate>().isDone(),
        isRinging: () => getIt<AlarmFocus>().on,
      ),
    )
    ..registerFactory(
      () => Day0CardCubit(
        rules: getIt<Day0CardRules>(),
        noticeRepository: getIt<InAppNoticeRepository>(),
        analytics: getIt<Day0CardAnalytics>(),
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
      () => ConnectLinkAnalytics(getIt<TelemetryGate>()),
    )
    ..registerLazySingleton(
      () => PushEventDrain(
        getIt<SharedPreferences>(),
        getIt<TelemetryGate>(),
        lastPush: getIt<LastPushStore>(),
      ),
    )
    // Setup step events. They wait on the phone until the user answers the
    // analytics question.
    ..registerLazySingleton(
      () => OnboardingFunnel(
        prefs: getIt<SharedPreferences>(),
        gate: getIt<TelemetryGate>(),
        stepIds: OnboardingStepRegistry.requiresById.keys.toSet(),
      ),
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
        () {
          getIt<BackgroundConnect>().dismissFailure();
          // Setup was finished or left on a build that has the Home
          // checklist, which is what lets Home tell this install from one
          // set up long before it.
          unawaited(getIt<SetupChecklistStore>().markSetUpHere());
          // The missed alarm check counts nothing that opened before this.
          unawaited(getIt<MissedAlarmReader>().setupCompleted());
        },
        getIt<FirstTopicHandoff>(),
        getIt<SetupTestRing>(),
      ),
    )
    // The one exit every "Set this up later" button takes.
    ..registerLazySingleton(
      () => SetUpLaterUsecase(
        getIt<CompleteOnboardingUsecase>(),
        getIt<SetupTestRing>(),
      ),
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
    // The analytics switch on the last setup step. Setup events held back
    // until the user chooses are sent or deleted by the funnel, which hears
    // the answer through the privacy repository.
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
    // The offer step's switches come from the same three places as the
    // flow: Developer options, Remote Config, then what ships in the app.
    // A store build holds no developer value.
    ..registerLazySingleton(
      () => OnboardingOfferGate(
        readDeveloperJson: () =>
            getIt<DeveloperOnboardingOverrides>().offerJson,
        readRemoteJson: () => getIt.isRegistered<TelemetryGate>()
            ? getIt<TelemetryGate>().onboardingOfferJson
            : null,
        readServerMode: () => getIt<AccountRepository>().readServerMode(),
        builtLayoutKeys: () => {
          for (final layout in paywallLayoutBuilders.keys) layout.key,
        },
        readAccountId: () async =>
            (await getIt<DeviceIdentityStore>().readOrCreate()).accountId,
        holdsPro: () => getIt<Holdings>().holdsConfirmed(Holding.pro),
        readHoldsHosted: _holdsHosted,
        isSetupComplete: () async =>
            (await getIt<GetOnboardingCompletedUsecase>()(
              const NoParams(),
            )).getOrNull() ??
            false,
        readFlowSteps: () => getIt<OnboardingFlowEngine>().runningFlow().steps,
        readCompletedSteps: () =>
            getIt<OnboardingFlowRepository>().read().completed,
      ),
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
            offer: getIt<OnboardingOfferGate>(),
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
          unawaited(reportStepToFunnel(getIt<OnboardingFunnel>(), event));
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
        isLocked: () async => ownSoundsLockedBy(
          await ownSoundsOnceReady(getIt<FeatureAccess>()),
        ),
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
    // The one way a server is connected. The setup connect step and a
    // connect link both call it.
    ..registerLazySingleton(
      () => ConnectToServerUsecase(
        getIt<GetServerInfoUsecase>(),
        getIt<EstablishApiSessionUsecase>(),
        getIt<SaveConnectionUsecase>(),
        // A server picked by hand replaces a Cloud connect still waiting.
        cancelPendingConnect: () => getIt<BackgroundConnect>().cancel(),
        readSavedServerUrl: () async =>
            (await getIt<ConnectionRepository>().getConnection())
                .getOrNull()
                ?.serverUrl,
        // A connect to a different server drops what belongs to the old
        // one: everything an account wipe drops, plus the archive.
        // Settings, sounds, permissions and the rest stay.
        forgetServerData: () async {
          await getIt<AccountData>().forget();
          await localStore?.clearServerData();
        },
      ),
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
        // A deleted topic takes its wake-up challenge and its flag along,
        // and the look it had picked for its alarm screen.
        onDeleted: (name) async {
          await getIt<ChallengeChoices>().forgetTopic(name);
          await getIt<ChallengeFlagSync>().check();
          await getIt<AlarmStyleChoices>().forgetTopic(name);
        },
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
    ..registerLazySingleton(() {
      final sync = WidgetSync(
        topics: getIt<TopicsCubit>(),
        incidents: getIt<IncidentsCubit>(),
        host: getIt<WidgetHost>(),
        isConnected: () async =>
            (await getIt<ConnectionRepository>().getConnection()).isSuccess(),
        // The lock is drawn by the widget itself, outside the app, and a
        // wrong one takes the widgets away. So this waits until the plan
        // and the saved server have been read before it answers.
        isLocked: () async =>
            !await getIt<FeatureAccess>().canOnceReady(AppFeature.widgets),
      );
      // The lock follows the widgets decision: a purchase, a plan that
      // ended, a server that became known. Neither list changes then, so
      // this is what writes the snapshot again.
      getIt<FeatureAccess>().changes
          .where((feature) => feature == AppFeature.widgets)
          .listen((_) => sync.rewrite());
      return sync;
    })
    // The one list of what belongs to an account on this phone. A sign-out,
    // an account delete and a connect to a different server all call it.
    ..registerLazySingleton(
      () => AccountData(
        acks: getIt<AckQueue>(),
        messageCursors: getIt<MessageSyncService>(),
        recentSearches: getIt<RecentSearchesRepository>(),
        challenges: getIt<ChallengeChoices>(),
        alarmStyles: getIt<AlarmStyleChoices>(),
        soundLock: getIt<OwnSoundLockFlag>(),
        ownLook: getIt<OwnLookStore>(),
        // Not waited for: each check asks the access layer, and neither a
        // wipe nor a connect waits on a plan.
        afterForget: () async {
          unawaited(getIt<SoundLockSync>().checkAfterWipe());
          unawaited(getIt<ChallengeFlagSync>().checkAfterWipe());
          unawaited(getIt<AlarmStyleGate>().check());
        },
      ),
    )
    // The one flag native code reads to know own sounds are locked. It
    // follows the own sounds decision: a purchase, a pack that ended, a
    // server that became known. It is written only on a sure answer, so
    // this waits for the plan and the saved server to be read, and a plan
    // that cannot be read leaves the last value alone.
    //
    // The flag is kept with the tag of the account it was written for, and
    // a flag for another account is taken away at the start of every check.
    ..registerLazySingleton(
      () => OwnSoundLockFlag(getIt<SharedPreferences>()),
    )
    ..registerLazySingleton(
      () => SoundLockSync(
        isLocked: () async =>
            !await getIt<FeatureAccess>().canOnceReady(AppFeature.ownSounds),
        changes: getIt<FeatureAccess>().changes.where(
          (feature) => feature == AppFeature.ownSounds,
        ),
        keepOnlyOurs: () async => getIt<OwnSoundLockFlag>().keepOnlyFor(
          accountTagFor(
            (await getIt<DeviceIdentityStore>().readOrCreate()).accountId,
          ),
        ),
        readWritten: () => getIt<OwnSoundLockFlag>().written,
        write: ({required locked}) =>
            getIt<OwnSoundLockFlag>().write(locked: locked),
        // The iOS notification extension reads its own copy of the choices.
        // Android reads the flag where it is written, so there is nothing
        // to copy and nothing to retry.
        publish: () async =>
            !getIt<PlatformCapabilities>().isIos ||
            await getIt<SoundHost>().publishSoundAssignments(),
      ),
    )
    // Wake-up challenges: each topic's choice, kept on this phone only; the
    // gate the alarm screen asks before "At my desk" closes an incident;
    // and the one flag per topic native code reads for its Done button.
    // None of it is asked before "I'm up", which stops the ring with one
    // tap on every plan.
    ..registerLazySingleton<ChallengeChoices>(
      () => SharedPrefsChallengeChoices(getIt<SharedPreferences>()),
    )
    // Alarm screen looks: the phone's choice and each topic's, kept on this
    // phone only, and the gate the alarm screen asks which one to draw. A
    // look changes how the in-app alarm screen is drawn and nothing else.
    ..registerLazySingleton<AlarmStyleChoices>(
      () => SharedPrefsAlarmStyleChoices(getIt<SharedPreferences>()),
    )
    ..registerLazySingleton(
      () => AlarmStyleGate(
        choices: getIt<AlarmStyleChoices>(),
        decide: () =>
            getIt<FeatureAccess>().decide(AppFeature.alarmScreenStyles),
        decideOnceReady: () => getIt<FeatureAccess>().decideOnceReady(
          AppFeature.alarmScreenStyles,
        ),
        // The note of the last sure answer belongs to one account.
        readAccountId: () async =>
            (await getIt<DeviceIdentityStore>().readOrCreate()).accountId,
        planRead: getIt<FeatureAccess>().ready,
        changes: [
          getIt<FeatureAccess>().changes.where(
            (feature) => feature == AppFeature.alarmScreenStyles,
          ),
        ],
        // A field read: the alarm screen asks this while it rings.
        isOwnLookReady: () => getIt<OwnAlarmLookKeeper>().isReady,
      ),
    )
    // The person's own alarm look: one photo in the app's own storage,
    // its record and its accent in the preferences. The keeper decodes
    // the photo at launch and holds it, so an alarm that rings loads
    // nothing. The photo never leaves the phone.
    ..registerLazySingleton<OwnLookStore>(
      () => FileOwnLookStore(
        getIt<SharedPreferences>(),
        getApplicationSupportDirectory,
      ),
    )
    ..registerLazySingleton(
      () => OwnAlarmLookKeeper(
        getIt<OwnLookStore>(),
        // The picture is in memory only while a paid look may ring. With
        // looks locked it is let go, and decoded again when that changes.
        mayHold: () => getIt<AlarmStyleGate>().drawsPaidLooks,
        recheck: [
          getIt<AlarmStyleGate>().checked,
          getIt<FeatureAccess>().changes.where(
            (feature) => feature == AppFeature.alarmScreenStyles,
          ),
        ],
      ),
    )
    ..registerLazySingleton<OwnPhotoPicker>(PlatformOwnPhotoPicker.new)
    ..registerLazySingleton(
      () => ImportOwnPhotoUsecase(
        const UiOwnPhotoCodec(),
        getIt<OwnLookStore>(),
        // The last check that looks are open, as the sound import has for
        // own sounds. Only a sure lock turns a photo away.
        isLocked: () async => !await getIt<FeatureAccess>().canOnceReady(
          AppFeature.alarmScreenStyles,
        ),
      ),
    )
    ..registerLazySingleton(
      () => ChallengeGate(
        choices: getIt<ChallengeChoices>(),
        decide: () =>
            getIt<FeatureAccess>().decide(AppFeature.wakeUpChallenges),
        canRun: (kind, incident) =>
            challengeOf(kind)?.canRunFor(incident) ?? false,
        planRead: getIt<FeatureAccess>().ready,
      ),
    )
    // The flag is set only on a sure answer, so this waits for the plan and
    // the saved server to be read, and a plan that cannot be read leaves
    // what is written alone. Without the plan no flag is ever set.
    ..registerLazySingleton(
      () => ChallengeFlagSync(
        decide: () => getIt<FeatureAccess>().decideOnceReady(
          AppFeature.wakeUpChallenges,
        ),
        changes: [
          getIt<FeatureAccess>().changes.where(
            (feature) => feature == AppFeature.wakeUpChallenges,
          ),
          getIt<ChallengeChoices>().changes,
        ],
        // A kind this build has no challenge for asks for nothing.
        readChoices: () => {
          for (final MapEntry(:key, :value)
              in getIt<ChallengeChoices>().choices.entries)
            if (challengeOf(value) != null) key,
        },
        readWritten: () => getIt<ChallengeChoices>().flaggedTopics,
        write: (topic, {required isOwed}) =>
            getIt<ChallengeChoices>().writeFlag(topic, isOwed: isOwed),
        // The iOS Live Activity reads its own copy, made with the sound
        // choices. Android reads the flag where it is written.
        publish: () async =>
            !getIt<PlatformCapabilities>().isIos ||
            await getIt<SoundHost>().publishSoundAssignments(),
        // A widget showing an acknowledged incident draws its Done button
        // from the flag, so it is drawn again when a flag changes. The
        // snapshot rewrite is the refresh the widgets already have.
        redraw: () => getIt<WidgetSync>().rewrite(),
        // The flags are kept with the tag of the account they were written
        // for, and flags for another account go before any is trusted.
        keepOnlyOurs: () async => getIt<ChallengeChoices>().keepFlagsOnlyFor(
          accountTagFor(
            (await getIt<DeviceIdentityStore>().readOrCreate()).accountId,
          ),
        ),
      ),
    )
    // "Share to Crit Alarm". Holds a shared file until onboarding is done and
    // no alarm is going off.
    ..registerLazySingleton(
      () => IncomingAudio(
        canImportSounds: () async =>
            (await getIt<SoundHost>().capabilities()).canImportSounds,
        readOwnSounds: () => ownSoundsOnceReady(getIt<FeatureAccess>()),
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
      ({bool replayForDemo, bool standalone, bool cameBack})?
    >(
      (initialStep, mode) => NotificationPermissionsCubit(
        getIt<RequestNotificationPermissionUsecase>(),
        getIt<OpenNotificationSettingsUsecase>(),
        readSetup: getIt<ReadPermissionSetupUsecase>(),
        alarm: getIt<AlarmHost>(),
        devicePermissions: getIt<DevicePermissionsRepository>(),
        replayForDemo: mode?.replayForDemo ?? false,
        standalone: mode?.standalone ?? false,
        cameBack: mode?.cameBack ?? false,
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
        // "Use a different server" on the connect step drops the old one
        // with the very call Settings > Server makes.
        disconnect: () async {
          final settings = getIt<SettingsCubit>();
          try {
            await settings.disconnectServer();
          } finally {
            await settings.close();
          }
        },
        connectToServer: getIt<ConnectToServerUsecase>(),
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
        readServerUrl: () async => (await getIt<GetConnectionUsecase>()(
          const NoParams(),
        )).getOrNull()?.serverUrl,
        // The same reads the create-topic screen makes for its plan line: a
        // paid plan and a server of the user's own have no cap to state.
        readCriticalLimit: () async {
          return AccountAccess(
            await getIt<DeviceIdentityStore>().readOrCreate(),
          ).freeCriticalCap(
            isUnlimited: await getIt<FeatureAccess>().usableOnceReady(
              AppFeature.unlimitedCriticalTopics,
            ),
          );
        },
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
        () => getIt<SetupTestRing>().setupIncidentIds,
      ),
    )
    // The dark card on Home. It follows the screen's own HomeCubit and
    // HomeSetupCubit, so the screen hands them in:
    // `getIt<HomeCardCubit>(param1: home, param2: setup)`. The checks and the
    // missed alarm entry are shared, so they come from here.
    ..registerFactoryParam<HomeCardCubit, HomeCubit, HomeSetupCubit>(
      (home, setup) => HomeCardCubit(
        home: home,
        reliability: getIt<ReliabilityCubit>(),
        setup: setup,
        missed: getIt<MissedAlarmFeed>(),
        testRouteName: AppRoute.testRing,
        askPermissionsRouteName: AppRoute.askPermissions,
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
        // Home can stay open for days, so its watch slows while nothing
        // arrives. The setup step keeps the steady pace of its own.
        newWatcher: () => FirstMessageWatcher(
          store: getIt<FirstMessageStore>(),
          source: ApiFirstMessageSource(api: getIt<ApiClient>()),
          backsOffWhenQuiet: true,
        ),
        readIncidentIds: () => [
          for (final incident in getIt<IncidentsCubit>().state.incidents)
            incident.id,
        ],
        readSetupIncidentIds: () => getIt<SetupTestRing>().setupIncidentIds,
        isGuideOfferAnswered: () =>
            getIt<FeatureGuideCubit>().hasSeenFirstGuide,
        // The same answer the widgets themselves draw their lock from.
        readWidgetsPlan: () async {
          final access = getIt<FeatureAccess>();
          return homeWidgetsPlanFor(
            await access.decideOnceReady(AppFeature.widgets),
            isOwnServer: access.isOwnServer,
          );
        },
        widgetsPlanChanges: getIt<FeatureAccess>().changes.where(
          (feature) => feature == AppFeature.widgets,
        ),
        platform: defaultTargetPlatform,
        isWeb: kIsWeb,
      ),
    )
    ..registerFactory(
      () => SearchCubit(
        featureAccess: getIt<FeatureAccess>(),
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
    // Reliability checks. Each source answers for its own checks, and the
    // cubit sums them up. A new source is a class and one line in the list
    // below. Nothing draws them yet.
    ..registerLazySingleton(
      () => RelayConfirmationStore(getIt<SharedPreferences>()),
    )
    ..registerLazySingleton(() => LastPushStore(getIt<SharedPreferences>()))
    ..registerLazySingleton(
      () => LastPushReader(
        getIt<SharedPreferences>(),
        getIt<LastPushStore>(),
        // On iOS the extension writes its rows to the App Group, and they
        // only reach Dart's list on the next launch. The alarm channel reads
        // the group directly.
        nativeRows: getIt<PlatformCapabilities>().isIos
            ? () async {
                final snapshot = await getIt<AlarmHost>().debugSnapshot();
                final rows = snapshot['push_events'];
                return rows is List ? rows : const [];
              }
            : null,
      ),
    )
    ..registerLazySingleton<OsVersionReader>(
      () => PlatformOsVersionReader(
        DeviceInfoPlugin(),
        platform: defaultTargetPlatform,
        isWeb: kIsWeb,
      ),
    )
    ..registerLazySingleton<OsVersionStore>(
      () => SharedPrefsOsVersionStore(getIt<SharedPreferences>()),
    )
    ..registerLazySingleton<ScheduledSummaryReader>(
      PlatformScheduledSummaryReader.new,
    )
    ..registerLazySingleton(
      () => SystemUpdateSource(
        os: getIt<OsVersionReader>(),
        store: getIt<OsVersionStore>(),
        // The newest test the server accepted, on any topic.
        lastTestAt: () async {
          final store = getIt<LocalReminderStore>();
          await store.reload();
          DateTime? newest;
          for (final at in store.readLastTestAt().values) {
            if (newest == null || at.isAfter(newest)) newest = at;
          }
          return newest;
        },
        testRouteName: AppRoute.testRing,
      ),
    )
    ..registerLazySingleton<MakerGuideStore>(
      () => SharedPrefsMakerGuideStore(getIt<SharedPreferences>()),
    )
    ..registerLazySingleton<MakerSettingsOpener>(
      PlatformMakerSettingsOpener.new,
    )
    ..registerFactory(
      () => MakerGuideCubit(
        makerReader: getIt<DeviceMakerReader>(),
        os: getIt<OsVersionReader>(),
        store: getIt<MakerGuideStore>(),
        opener: getIt<MakerSettingsOpener>(),
      ),
    )
    // The missed alarm check. It reads what the phone and the shared lists
    // already hold: no call to the server, no alert, nothing on the alarm
    // path changed.
    ..registerLazySingleton<MissedAlarmStore>(
      () => SharedPrefsMissedAlarmStore(getIt<SharedPreferences>()),
    )
    ..registerLazySingleton(
      () => PlatformPhoneCapture(
        prefs: getIt<SharedPreferences>(),
        readNative: getIt<AlarmHost>().debugSnapshot,
        readAckQueue: getIt<AckQueue>().entries,
        alarmIds: [
          getIt<AlarmHost>().alarmsScheduled,
          getIt<PushHost>().alarmPushes,
        ],
        alarmingIds: () => getIt<IncidentAlarmController>().alarmingIncidentIds,
      ),
    )
    ..registerLazySingleton(
      () => MissedAlarmReader(
        store: getIt<MissedAlarmStore>(),
        readIncidents: () => getIt<IncidentsCubit>().state.incidents,
        // What the shared list already holds. Never a fetch.
        readTopicNames: () async {
          final topics = getIt<TopicsCubit>().state;
          return topics.isReady
              ? {for (final topic in topics.topics) topic.name}
              : null;
        },
        capture: getIt<PlatformPhoneCapture>().take,
        isSetupDone: () async =>
            (await getIt<GetOnboardingCompletedUsecase>()(
              const NoParams(),
            )).getOrNull() ??
            false,
        readServer: () async {
          final conn = (await getIt<GetConnectionUsecase>()(
            const NoParams(),
          )).getOrNull();
          final url = conn?.serverUrl.trim() ?? '';
          return url.isEmpty ? null : url;
        },
        firstLaunchAt: getIt<InAppNoticeRepository>().getFirstSeenAt,
        setupIncidentIds: () => getIt<SetupTestRing>().setupIncidentIds,
        // Android writes a row for every push it is handed (`PushRouter`).
        // An iPhone only writes one when the notification extension runs,
        // so there a stretch with no row proves nothing.
        everyPushIsLogged:
            !getIt<PlatformCapabilities>().isWeb &&
            getIt<PlatformCapabilities>().platform == TargetPlatform.android,
      ),
    )
    // The missed alarm entry for Home's card. It reads the reader and the
    // record of closed entries the notice reads, so closing it from either
    // place closes it in both.
    ..registerLazySingleton<MissedAlarmFeed>(
      () => ReaderMissedAlarmFeed(
        readMissed: getIt<MissedAlarmReader>().read,
        readDismissed: () =>
            getIt<MissedAlarmStore>().readDismissed().keys.toSet(),
        writeDismissed: getIt<MissedAlarmReader>().dismiss,
        readIncidents: () => getIt<IncidentsCubit>().state.incidents,
        isSetupDone: () => getIt<SetupGate>().isDone(),
        // Asked again when an incident runs out, and only then: the list
        // changes far more often than that.
        incidentChanges: _expiredIncidentChanges(getIt<IncidentsCubit>()),
      ),
    )
    ..registerLazySingleton(
      () => ReliabilityFixRunner(
        openSystemSettings: (permission) async {
          await getIt<OpenPermissionSettingsUsecase>()(permission);
        },
        reRegisterPushToken: getIt<DeviceTokenRegistry>().confirmNow,
      ),
    )
    ..registerLazySingleton(
      () => ReliabilityCubit([
        PermissionsSource(
          permissions: getIt<DevicePermissionsRepository>(),
          capabilities: getIt<PlatformCapabilities>(),
          os: getIt<OsVersionReader>(),
          // The phone does not tell "never asked" from "said no" for
          // notifications. The same answer the permissions screen uses.
          notificationsNeverAsked: () async =>
              (await getIt<CheckNotificationPermissionUsecase>()(
                const NoParams(),
              )).getOrNull() ==
              NotificationPermissionStatus.notDetermined,
        ),
        PushTokenSource(
          store: getIt<RelayConfirmationStore>(),
          currentScope: getIt<DeviceTokenRegistry>().currentScope,
          // The registry is not started on the mock server, and a phone with
          // no server has nobody to register with.
          isRelayExpected: () async =>
              !buildUsesMockApi &&
              getIt<PlatformCapabilities>().canRegisterPush &&
              await getIt<ApiSessionStore>().read() != null,
        ),
        LastPushSource(
          reader: getIt<LastPushReader>(),
          capabilities: getIt<PlatformCapabilities>(),
          hasCriticalTopic: () async =>
              (await getIt<GetTopicsUsecase>()(
                const NoParams(),
              )).getOrNull()?.any((topic) => topic.critical) ??
              false,
          testRouteName: AppRoute.testRing,
        ),
        TimeSensitiveSource(
          capabilities: getIt<PlatformCapabilities>(),
          os: getIt<OsVersionReader>(),
          permissions: getIt<DevicePermissionsRepository>(),
          summary: getIt<ScheduledSummaryReader>(),
        ),
        getIt<SystemUpdateSource>(),
        PhoneMakerSource(
          capabilities: getIt<PlatformCapabilities>(),
          makerReader: getIt<DeviceMakerReader>(),
          os: getIt<OsVersionReader>(),
          store: getIt<MakerGuideStore>(),
          guideRouteName: makerGuideRouteName,
        ),
        MissedAlarmSource(
          readMissed: getIt<MissedAlarmReader>().read,
          readDismissedIds: () =>
              getIt<MissedAlarmStore>().readDismissed().keys.toSet(),
          testRouteName: AppRoute.testRing,
        ),
        // The weekly check counts while it is switched on, as "needs a
        // look" at most. It reads what the monitor already holds and never
        // calls the relay: the row's own cubit does that.
        WeeklyCheckSource(
          readCheck: () => getIt<WeeklyCheckMonitor>().check,
          isPackHeld: () =>
              getIt<FeatureAccess>().decide(AppFeature.weeklyCheck)
                  is FeatureOpen,
          readMissedByClock: () =>
              getIt<WeeklyCheckMonitor>().twoRoundsMissed(),
          testRouteName: AppRoute.testRing,
        ),
      ]),
    )
    ..registerFactory(
      () => HistoryCubit(
        getIt<IncidentsCubit>(),
        identityStore: getIt<DeviceIdentityStore>(),
        featureAccess: getIt<FeatureAccess>(),
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
        featureAccess: getIt<FeatureAccess>(),
      ),
    )
    ..registerFactory(
      () =>
          CreateTopicCubit(
              getIt<CreateTopicUsecase>(),
              getIt<GetConnectionUsecase>(),
              getIt<DeviceIdentityStore>(),
              getIt<GetTopicsUsecase>(),
              null,
              getIt<FeatureAccess>(),
            )
            ..alarm = getIt<AlarmHost>()
            ..toolTemplates = getIt<ToolTemplateStore>()
            ..applyPhoneDefaults = getIt<ChallengeChoices>().applyDefaultTo
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
        getIt<SetupTestRing>(),
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
        holdings: getIt<Holdings>(),
        featureAccess: getIt<FeatureAccess>(),
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
        readHoldsHosted: () => getIt<AccountRepository>().readHoldsHosted(),
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
        readOwnSounds: () =>
            getIt<FeatureAccess>().decide(AppFeature.ownSounds),
        // The first answer waits for the plan to be read, so someone who
        // holds Pro never sees a lock or a paywall at a cold start.
        readOwnSoundsOnceReady: () =>
            ownSoundsOnceReady(getIt<FeatureAccess>()),
        ownSoundsChanges: getIt<FeatureAccess>().changes.where(
          (feature) => feature == AppFeature.ownSounds,
        ),
      ),
    )
    ..registerFactory(
      () => PersonalizeCubit(
        getIt<AlarmSoundRepository>(),
        getIt<SoundHost>(),
        nameOf: (id) => 'sound_library.names.$id'.tr(),
        packs: getIt<SoundPackRepository>(),
      ),
    )
    ..registerFactory(
      () => PrioritiesCubit(
        getIt<AlarmHost>(),
        getIt<SoundHost>(),
        getIt<AlarmSoundRepository>(),
        packs: getIt<SoundPackRepository>(),
        platform: getIt<PlatformCapabilities>().platform,
        isWeb: getIt<PlatformCapabilities>().isWeb,
        nameOf: (id) => 'sound_library.names.$id'.tr(),
        ownSoundsLocked: () => ownSoundsLockedBy(
          getIt<FeatureAccess>().decide(AppFeature.ownSounds),
        ),
      ),
    )
    ..registerFactory(
      () => DevicePermissionsCubit(
        getIt<GetDevicePermissionsUsecase>(),
        getIt<OpenPermissionSettingsUsecase>(),
        capabilities: getIt<PlatformCapabilities>(),
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
    // The one way into either paywall. With both remote values empty and
    // nothing set in Developer options it answers with the shipped routes.
    ..registerLazySingleton<PaywallDoor>(
      () => PaywallDoor(
        remoteValue: (product) {
          if (!getIt.isRegistered<TelemetryGate>()) return '';
          final gate = getIt<TelemetryGate>();
          return switch (product) {
            PaywallProduct.hosted => gate.paywallLayoutKey,
            PaywallProduct.pro => gate.proPaywallLayoutKey,
          };
        },
        developer: (product) => switch (product) {
          PaywallProduct.hosted => appPaywallLayoutOverride.hosted,
          PaywallProduct.pro => appPaywallLayoutOverride.pro,
        },
        remoteIntroValue: (product) {
          if (!getIt.isRegistered<TelemetryGate>()) return '';
          final gate = getIt<TelemetryGate>();
          return switch (product) {
            PaywallProduct.hosted => gate.paywallIntroKey,
            PaywallProduct.pro => gate.proPaywallIntroKey,
          };
        },
        developerIntro: (product) => switch (product) {
          PaywallProduct.hosted => appPaywallLayoutOverride.hostedIntro,
          PaywallProduct.pro => appPaywallLayoutOverride.proIntro,
        },
        remoteThanksValue: (product) {
          if (!getIt.isRegistered<TelemetryGate>()) return '';
          final gate = getIt<TelemetryGate>();
          return switch (product) {
            PaywallProduct.hosted => gate.paywallThanksKey,
            PaywallProduct.pro => gate.proPaywallThanksKey,
          };
        },
        developerThanks: (product) => switch (product) {
          PaywallProduct.hosted => appPaywallLayoutOverride.hostedThanks,
          PaywallProduct.pro => appPaywallLayoutOverride.proThanks,
        },
        widgetsDecision: () =>
            getIt<FeatureAccess>().decide(AppFeature.widgets),
        hasSeenFalseAlarm: () =>
            getIt<SharedPreferences>().getBool(
              PaywallDoor.falseAlarmShownKey,
            ) ??
            false,
        markFalseAlarmSeen: () => getIt<SharedPreferences>().setBool(
          PaywallDoor.falseAlarmShownKey,
          true,
        ),
      ),
    )
    // The Interface sounds switch in Settings. On until the user turns it off.
    ..registerLazySingleton<InterfaceSoundsSetting>(
      () => InterfaceSoundsSetting(getIt<SharedPreferences>()),
    )
    // The sounds a paywall layout asks for. They play where the platform has
    // a player for interface sounds, and stay silent on the web and anywhere
    // else. Nothing here touches the alarm: it only asks whether one is up.
    ..registerLazySingleton<PaywallCues>(
      () => paywallCuesFor(
        getIt<PlatformCapabilities>(),
        playing: () => PlayingPaywallCues(
          player: UiSoundHost(),
          isSwitchOn: () => getIt<InterfaceSoundsSetting>().isOn,
          isAlarmUp: () =>
              getIt<AlarmFocus>().on ||
              getIt<IncidentAlarmController>().alarmingIncidentIds.isNotEmpty,
          alarmStarts: [
            getIt<AlarmArrivals>().incidentIds,
            getIt<AlarmFocus>().stream.where((isOn) => isOn),
          ],
          haptic: getIt<PlatformCapabilities>().hasHaptics
              ? AppHaptics.play
              : null,
          cancelHaptic: AppHaptics.cancelPattern,
          introFlavour: () => getIt.isRegistered<DevIntroSoundSwitch>()
              ? getIt<DevIntroSoundSwitch>().value
              : IntroSoundFlavour.piano,
        ),
      ),
    )
    // What every paywall layout buys through. A build that skips the store
    // gets made-up options, so a layout still has something to draw.
    ..registerFactoryParam<PaywallBuyCubit, PaywallProduct, PaywallBuyStatus?>(
      (product, demoStatus) {
        if (buildSkipsPaywall) {
          return DemoPaywallBuyCubit(product, startAs: demoStatus);
        }
        return switch (product) {
          PaywallProduct.pro => ProPaywallBuyCubit(
            access: getIt<ProPackAccess>(),
            shop: getIt<ProPackShop>(),
          ),
          PaywallProduct.hosted => HostedPaywallBuyCubit(
            getOfferings: getIt<GetOfferingsUsecase>(),
            purchasePackage: getIt<PurchasePackageUsecase>(),
            restorePurchases: getIt<RestorePurchasesUsecase>(),
            readIsPaid: _holdsHosted, // access-ok: the buy cubit's name
            readIsRegisteredPaid: _hostedByServer, // access-ok: same
            refreshRegistration: () async {
              await getIt<RevenueCatService>().invalidateCustomerInfoCache();
              await getIt<RegisterDeviceUsecase>()(appVersion: appVersion);
              getIt<WidgetSync>().rewrite();
            },
          ),
        };
      },
    )
    ..registerFactory(
      () => ProStatusCubit(
        readHoldsHosted: _holdsHosted,
        holdingChanges: getIt<Holdings>().stream,
      ),
    )
    ..registerLazySingleton(
      () => ProEnding(
        notices: getIt<InAppNoticeRepository>(),
        plan: getIt<PlanStatusSource>(),
        readIdentity: () => getIt<DeviceIdentityStore>().readOrCreate(),
        readServerSaysHosted: _hostedByServer,
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
    ..registerFactory<InAppNoticeCubit>(
      () => InAppNoticeCubit(
        getConnectionUsecase: getIt<GetConnectionUsecase>(),
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

  if (buildSkipsPaywall && useMockApi) {
    // In a mock build the developer switch also makes the mock relay hold
    // the pack, so the read from it and the two pack routes answer the same
    // as the switch.
    final devSwitch = getIt<ProPackDevSwitch>();
    void applyToMock() {
      final granted = getIt<MockServer>().grantedPacks;
      if (devSwitch.value) {
        granted.add(proPackId);
      } else {
        granted.remove(proPackId);
      }
      unawaited(getIt<ProPackAccess>().refresh(force: true));
    }

    devSwitch.addListener(applyToMock);
    applyToMock();
  }
}

/// Starts what the missed alarm check needs from launch on. Call it on the
/// line before the push event drain runs: the drain empties the native list
/// this copies.
///
/// It reads and listens. It changes nothing about how an alarm rings.
void startMissedAlarmWatch() {
  getIt<PlatformPhoneCapture>()
    ..start()
    ..holdPendingRows();
  // A topic is stamped the moment the shared list first holds it.
  final topics = getIt<TopicsCubit>();
  void seen(TopicsState state) {
    if (!state.isReady) return;
    unawaited(
      getIt<MissedAlarmReader>().topicsSeen([
        for (final topic in state.topics) topic.name,
      ]),
    );
  }

  seen(topics.state);
  topics.stream.listen(seen);
}

/// Fires when the set of expired incidents in the shared list changes, and
/// at no other time: the list itself changes far more often than that.
Stream<void> _expiredIncidentChanges(IncidentsCubit incidents) {
  String keyOf(IncidentsState state) => [
    for (final incident in state.incidents)
      if (incident.isExpired) incident.id,
  ].join(',');
  var last = keyOf(incidents.state);
  return incidents.stream.map(keyOf).where((key) {
    if (key == last) return false;
    last = key;
    return true;
  });
}

void _mirrorStorePro(CustomerInfo info) => appPlanChanges.setStoreSaysPro(
  value: HostedHoldingSource.storeSaysHosted(info),
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

/// Whether this install holds Hosted, asked once the sources are current.
/// For the readers that ask once and do not listen: the reminder inputs,
/// the onboarding offer, the Pro badge and the buy flow.
Future<bool> _holdsHosted() => getIt<Holdings>().holdsOnceReady(Holding.hosted);

/// Whether the server's own tier says Hosted, leaving out the store and the
/// developer switch: the Hosted source's named read, for the two callers
/// that report what the server did.
Future<bool> _hostedByServer() {
  final hosted = getIt<HostedHoldingSource>();
  return hosted.readHeldByServer(); // access-ok: the named read, passed on
}

/// Every change of whether the Pro pack is held, for the weekly check
/// monitor. Not a gate: nothing is decided on it, the relay is asked again.
Stream<bool> _proPackHeldChanges() {
  return getIt<ProPackAccess>().stream; // access-ok: re-asks the relay
}
