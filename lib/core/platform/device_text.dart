import 'dart:ui' show Locale;

import 'package:critalarm/core/platform/device_word.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart' show immutable;

/// Translations that name the device the app runs on.
///
/// A string that says "this phone" has a sibling key per [DeviceWord] it can
/// show on: `wake.stop_phone` is the phone's, `wake.stop_phone_ipad` the
/// iPad's, `wake.stop_phone_tablet` the Android tablet's and
/// `wake.stop_phone_computer` the Mac's and the web app's. Each variant is a
/// whole sentence in every language, so German case, Japanese counters and
/// Slavic endings are the translator's, never built in code.
///
/// [DeviceWordAssetLoader] puts the variant for the running device in place
/// of the phone's text as each language loads. Code keeps asking for the
/// phone key (`LocaleKeys.wake_stop_phone.tr()`) and gets "This iPad" on an
/// iPad, wherever the `.tr()` runs: a widget, a cubit or a notification.
///
/// To add a string: give it its `_ipad`, `_tablet` and `_computer` siblings
/// in every language (only `_ipad` for an iOS-only string, only `_tablet`
/// for an Android-only one) and an entry in [deviceVariantKeys].
/// `test/core/platform/device_text_test.dart` fails when the two disagree.

/// [translations] with the text of every phone key in [deviceVariantKeys]
/// replaced by its variant for [word]. A phone, a key with no variant for
/// [word], or a variant missing from [translations] keeps the phone's text.
///
/// [translations] itself is left as it is.
Map<String, dynamic> withDeviceWord(
  Map<String, dynamic> translations,
  DeviceWord word,
) {
  if (word == DeviceWord.phone) return translations;
  final out = _copy(translations);
  for (final entry in deviceVariantKeys.entries) {
    final variant = entry.value.forWord(word);
    if (variant == null) continue;
    final value = _read(out, variant);
    if (value == null) continue;
    _write(out, entry.key, value);
  }
  return out;
}

Map<String, dynamic> _copy(Map<String, dynamic> map) => {
  for (final e in map.entries)
    e.key: e.value is Map<String, dynamic>
        ? _copy(e.value as Map<String, dynamic>)
        : e.value,
};

Object? _read(Map<String, dynamic> map, String dotted) {
  Object? node = map;
  for (final part in dotted.split('.')) {
    if (node is! Map<String, dynamic>) return null;
    node = node[part];
  }
  return node;
}

void _write(Map<String, dynamic> map, String dotted, Object value) {
  final parts = dotted.split('.');
  var node = map;
  for (final part in parts.take(parts.length - 1)) {
    final next = node[part];
    if (next is! Map<String, dynamic>) return;
    node = next;
  }
  if (!node.containsKey(parts.last)) return;
  node[parts.last] = value;
}

/// Loads `assets/translations/<locale>.json` the way easy_localization's own
/// [RootBundleAssetLoader] does, then applies [withDeviceWord] for [word].
///
/// The word is read once at launch, so a language picked later loads with
/// the same word.
class DeviceWordAssetLoader extends AssetLoader {
  const DeviceWordAssetLoader(
    this.word, {
    this.inner = const RootBundleAssetLoader(),
  });

  final DeviceWord word;
  final AssetLoader inner;

  @override
  Future<Map<String, dynamic>?> load(String path, Locale locale) async {
    final translations = await inner.load(path, locale);
    return translations == null ? null : withDeviceWord(translations, word);
  }
}

/// The variants of one phone string, as `LocaleKeys` keys.
@immutable
class DeviceKeys {
  const DeviceKeys({this.ipad, this.tablet, this.computer});

  final String? ipad;
  final String? tablet;
  final String? computer;

  /// The key for [word], or null when this string has no variant for it.
  String? forWord(DeviceWord word) => switch (word) {
    DeviceWord.phone => null,
    DeviceWord.ipad => ipad,
    DeviceWord.tablet => tablet,
    DeviceWord.computer => computer,
  };
}

/// Every string that names the device the app runs on, by its phone key.
///
/// A string shown only on iOS has an iPad variant only, one shown only on
/// Android a tablet variant only.
///
/// Two rulings shape the table (Z, 2026-11-03):
/// - On iPadOS 26 an iPad gets through silent mode with a notification, never
///   the iPhone's full-screen alarm. Its variants say so, and iOS strings
///   that promise an alarm get an iPad variant even with no "phone" in them
///   (`priorities.alarm_ios`).
/// - The Mac and the web app cannot ring yet. A string that promises a ring
///   or an alarm has no computer variant, so they keep the phone's words.
///   Only sentences true on a computer today (storage, account, sign-in,
///   purchases) have one.
///
/// `test/core/platform/device_text_test.dart` checks this table against
/// `assets/translations/*.json` both ways: every variant named here exists in
/// every language, and every `_ipad`, `_tablet` or `_computer` key there is
/// named here.
const Map<String, DeviceKeys> deviceVariantKeys = {
  LocaleKeys.onboarding_welcome_subtitle: DeviceKeys(
    ipad: LocaleKeys.onboarding_welcome_subtitle_ipad,
    tablet: LocaleKeys.onboarding_welcome_subtitle_tablet,
  ),
  LocaleKeys.onboarding_welcome_rings_title: DeviceKeys(
    ipad: LocaleKeys.onboarding_welcome_rings_title_ipad,
    tablet: LocaleKeys.onboarding_welcome_rings_title_tablet,
  ),
  LocaleKeys.onboarding_welcome_caption_rings: DeviceKeys(
    ipad: LocaleKeys.onboarding_welcome_caption_rings_ipad,
    tablet: LocaleKeys.onboarding_welcome_caption_rings_tablet,
  ),
  LocaleKeys.onboarding_welcome_caption_rings_silent: DeviceKeys(
    ipad: LocaleKeys.onboarding_welcome_caption_rings_silent_ipad,
    tablet: LocaleKeys.onboarding_welcome_caption_rings_silent_tablet,
  ),
  LocaleKeys.onboarding_welcome_story_curl_label: DeviceKeys(
    ipad: LocaleKeys.onboarding_welcome_story_curl_label_ipad,
    tablet: LocaleKeys.onboarding_welcome_story_curl_label_tablet,
  ),
  LocaleKeys.onboarding_welcome_story_your_phone: DeviceKeys(
    ipad: LocaleKeys.onboarding_welcome_story_your_phone_ipad,
    tablet: LocaleKeys.onboarding_welcome_story_your_phone_tablet,
  ),
  LocaleKeys.onboarding_connect_routes_phone: DeviceKeys(
    ipad: LocaleKeys.onboarding_connect_routes_phone_ipad,
    tablet: LocaleKeys.onboarding_connect_routes_phone_tablet,
  ),
  LocaleKeys.onboarding_connect_routes_label_cloud: DeviceKeys(
    ipad: LocaleKeys.onboarding_connect_routes_label_cloud_ipad,
    tablet: LocaleKeys.onboarding_connect_routes_label_cloud_tablet,
  ),
  LocaleKeys.onboarding_connect_routes_label_own: DeviceKeys(
    ipad: LocaleKeys.onboarding_connect_routes_label_own_ipad,
    tablet: LocaleKeys.onboarding_connect_routes_label_own_tablet,
  ),
  LocaleKeys.onboarding_connect_relay_differs: DeviceKeys(
    ipad: LocaleKeys.onboarding_connect_relay_differs_ipad,
    tablet: LocaleKeys.onboarding_connect_relay_differs_tablet,
  ),
  LocaleKeys.onboarding_connect_registered_elsewhere: DeviceKeys(
    ipad: LocaleKeys.onboarding_connect_registered_elsewhere_ipad,
    tablet: LocaleKeys.onboarding_connect_registered_elsewhere_tablet,
  ),
  LocaleKeys.onboarding_connect_hook_step1_time_sensitive: DeviceKeys(
    ipad: LocaleKeys.onboarding_connect_hook_step1_time_sensitive_ipad,
  ),
  LocaleKeys.onboarding_connect_hook_step2: DeviceKeys(
    ipad: LocaleKeys.onboarding_connect_hook_step2_ipad,
    tablet: LocaleKeys.onboarding_connect_hook_step2_tablet,
  ),
  LocaleKeys.onboarding_connect_hook_button: DeviceKeys(
    ipad: LocaleKeys.onboarding_connect_hook_button_ipad,
    tablet: LocaleKeys.onboarding_connect_hook_button_tablet,
  ),
  LocaleKeys.onboarding_connect_welcome_body: DeviceKeys(
    ipad: LocaleKeys.onboarding_connect_welcome_body_ipad,
    tablet: LocaleKeys.onboarding_connect_welcome_body_tablet,
  ),
  LocaleKeys.onboarding_connect_hook_no_alarm_body: DeviceKeys(
    ipad: LocaleKeys.onboarding_connect_hook_no_alarm_body_ipad,
    tablet: LocaleKeys.onboarding_connect_hook_no_alarm_body_tablet,
  ),
  LocaleKeys.onboarding_connect_hook_not_asked_body: DeviceKeys(
    ipad: LocaleKeys.onboarding_connect_hook_not_asked_body_ipad,
    tablet: LocaleKeys.onboarding_connect_hook_not_asked_body_tablet,
  ),
  LocaleKeys.onboarding_connect_hook_alarms_off_body: DeviceKeys(
    ipad: LocaleKeys.onboarding_connect_hook_alarms_off_body_ipad,
    tablet: LocaleKeys.onboarding_connect_hook_alarms_off_body_tablet,
  ),
  LocaleKeys.onboarding_connect_hook_failed_body: DeviceKeys(
    ipad: LocaleKeys.onboarding_connect_hook_failed_body_ipad,
    tablet: LocaleKeys.onboarding_connect_hook_failed_body_tablet,
  ),
  LocaleKeys.onboarding_connect_background_waiting_push: DeviceKeys(
    ipad: LocaleKeys.onboarding_connect_background_waiting_push_ipad,
    tablet: LocaleKeys.onboarding_connect_background_waiting_push_tablet,
  ),
  LocaleKeys.connect_link_what: DeviceKeys(
    ipad: LocaleKeys.connect_link_what_ipad,
    tablet: LocaleKeys.connect_link_what_tablet,
  ),
  LocaleKeys.onboarding_real_ring_sending: DeviceKeys(
    ipad: LocaleKeys.onboarding_real_ring_sending_ipad,
    tablet: LocaleKeys.onboarding_real_ring_sending_tablet,
  ),
  LocaleKeys.onboarding_real_ring_rang: DeviceKeys(
    ipad: LocaleKeys.onboarding_real_ring_rang_ipad,
    tablet: LocaleKeys.onboarding_real_ring_rang_tablet,
  ),
  LocaleKeys.onboarding_real_ring_failed_offline: DeviceKeys(
    ipad: LocaleKeys.onboarding_real_ring_failed_offline_ipad,
    tablet: LocaleKeys.onboarding_real_ring_failed_offline_tablet,
  ),
  LocaleKeys.onboarding_real_ring_failed_signed_out: DeviceKeys(
    ipad: LocaleKeys.onboarding_real_ring_failed_signed_out_ipad,
    tablet: LocaleKeys.onboarding_real_ring_failed_signed_out_tablet,
  ),
  LocaleKeys.onboarding_real_ring_fallback_button: DeviceKeys(
    ipad: LocaleKeys.onboarding_real_ring_fallback_button_ipad,
    tablet: LocaleKeys.onboarding_real_ring_fallback_button_tablet,
  ),
  LocaleKeys.onboarding_real_ring_fallback_line: DeviceKeys(
    ipad: LocaleKeys.onboarding_real_ring_fallback_line_ipad,
    tablet: LocaleKeys.onboarding_real_ring_fallback_line_tablet,
  ),
  LocaleKeys.onboarding_real_ring_not_reached_title: DeviceKeys(
    ipad: LocaleKeys.onboarding_real_ring_not_reached_title_ipad,
    tablet: LocaleKeys.onboarding_real_ring_not_reached_title_tablet,
  ),
  LocaleKeys.onboarding_real_ring_muted_title: DeviceKeys(
    ipad: LocaleKeys.onboarding_real_ring_muted_title_ipad,
    tablet: LocaleKeys.onboarding_real_ring_muted_title_tablet,
  ),
  LocaleKeys.onboarding_real_ring_proof_phone_rang: DeviceKeys(
    ipad: LocaleKeys.onboarding_real_ring_proof_phone_rang_ipad,
    tablet: LocaleKeys.onboarding_real_ring_proof_phone_rang_tablet,
  ),
  LocaleKeys.onboarding_real_ring_proof_phone_rings: DeviceKeys(
    ipad: LocaleKeys.onboarding_real_ring_proof_phone_rings_ipad,
    tablet: LocaleKeys.onboarding_real_ring_proof_phone_rings_tablet,
  ),
  LocaleKeys.onboarding_real_ring_ios_check_online: DeviceKeys(
    ipad: LocaleKeys.onboarding_real_ring_ios_check_online_ipad,
  ),
  LocaleKeys.onboarding_real_ring_ios_time_sensitive_step_ringer: DeviceKeys(
    ipad: LocaleKeys.onboarding_real_ring_ios_time_sensitive_step_ringer_ipad,
  ),
  LocaleKeys.onboarding_real_ring_ios_time_sensitive_check_online: DeviceKeys(
    ipad: LocaleKeys.onboarding_real_ring_ios_time_sensitive_check_online_ipad,
  ),
  LocaleKeys.onboarding_real_ring_android_check_online: DeviceKeys(
    tablet: LocaleKeys.onboarding_real_ring_android_check_online_tablet,
  ),
  LocaleKeys.onboarding_hook_up_arrived_line: DeviceKeys(
    ipad: LocaleKeys.onboarding_hook_up_arrived_line_ipad,
    tablet: LocaleKeys.onboarding_hook_up_arrived_line_tablet,
  ),
  LocaleKeys.onboarding_hook_up_steps_step_test: DeviceKeys(
    ipad: LocaleKeys.onboarding_hook_up_steps_step_test_ipad,
    tablet: LocaleKeys.onboarding_hook_up_steps_step_test_tablet,
  ),
  LocaleKeys.onboarding_hook_up_steps_step_test_lands: DeviceKeys(
    ipad: LocaleKeys.onboarding_hook_up_steps_step_test_lands_ipad,
    tablet: LocaleKeys.onboarding_hook_up_steps_step_test_lands_tablet,
  ),
  LocaleKeys.onboarding_hook_up_steps_home_assistant_3: DeviceKeys(
    ipad: LocaleKeys.onboarding_hook_up_steps_home_assistant_3_ipad,
    tablet: LocaleKeys.onboarding_hook_up_steps_home_assistant_3_tablet,
  ),
  LocaleKeys.onboarding_hook_up_steps_home_assistant_3_lands: DeviceKeys(
    ipad: LocaleKeys.onboarding_hook_up_steps_home_assistant_3_lands_ipad,
    tablet: LocaleKeys.onboarding_hook_up_steps_home_assistant_3_lands_tablet,
  ),
  LocaleKeys.onboarding_permissions_checking: DeviceKeys(
    ipad: LocaleKeys.onboarding_permissions_checking_ipad,
    tablet: LocaleKeys.onboarding_permissions_checking_tablet,
    computer: LocaleKeys.onboarding_permissions_checking_computer,
  ),
  LocaleKeys.onboarding_permissions_came_back_title: DeviceKeys(
    ipad: LocaleKeys.onboarding_permissions_came_back_title_ipad,
    tablet: LocaleKeys.onboarding_permissions_came_back_title_tablet,
    computer: LocaleKeys.onboarding_permissions_came_back_title_computer,
  ),
  LocaleKeys.onboarding_permissions_ios_notifications_subtitle: DeviceKeys(
    ipad: LocaleKeys.onboarding_permissions_ios_notifications_subtitle_ipad,
  ),
  LocaleKeys.onboarding_permissions_ios_time_sensitive_title: DeviceKeys(
    ipad: LocaleKeys.onboarding_permissions_ios_time_sensitive_title_ipad,
  ),
  LocaleKeys.onboarding_permissions_android_notifications_subtitle: DeviceKeys(
    tablet:
        LocaleKeys.onboarding_permissions_android_notifications_subtitle_tablet,
  ),
  LocaleKeys.onboarding_permissions_android_battery_subtitle: DeviceKeys(
    tablet: LocaleKeys.onboarding_permissions_android_battery_subtitle_tablet,
  ),
  LocaleKeys.feature_guides_topics_body: DeviceKeys(
    ipad: LocaleKeys.feature_guides_topics_body_ipad,
    tablet: LocaleKeys.feature_guides_topics_body_tablet,
  ),
  LocaleKeys.feature_guides_topics_body_example: DeviceKeys(
    ipad: LocaleKeys.feature_guides_topics_body_example_ipad,
    tablet: LocaleKeys.feature_guides_topics_body_example_tablet,
  ),
  LocaleKeys.feature_guides_topic_critical_body: DeviceKeys(
    ipad: LocaleKeys.feature_guides_topic_critical_body_ipad,
    tablet: LocaleKeys.feature_guides_topic_critical_body_tablet,
  ),
  LocaleKeys.feature_guides_topic_critical_body_time_sensitive: DeviceKeys(
    ipad: LocaleKeys.feature_guides_topic_critical_body_time_sensitive_ipad,
  ),
  LocaleKeys.feature_guides_health_body: DeviceKeys(
    ipad: LocaleKeys.feature_guides_health_body_ipad,
    tablet: LocaleKeys.feature_guides_health_body_tablet,
  ),
  LocaleKeys.topic_detail_ack_failed: DeviceKeys(
    ipad: LocaleKeys.topic_detail_ack_failed_ipad,
    tablet: LocaleKeys.topic_detail_ack_failed_tablet,
  ),
  LocaleKeys.incidents_handled_elsewhere_body: DeviceKeys(
    ipad: LocaleKeys.incidents_handled_elsewhere_body_ipad,
    tablet: LocaleKeys.incidents_handled_elsewhere_body_tablet,
  ),
  LocaleKeys.incidents_alarm_ended_body: DeviceKeys(
    ipad: LocaleKeys.incidents_alarm_ended_body_ipad,
    tablet: LocaleKeys.incidents_alarm_ended_body_tablet,
  ),
  LocaleKeys.critical_alarm_demo_body_time_sensitive: DeviceKeys(
    ipad: LocaleKeys.critical_alarm_demo_body_time_sensitive_ipad,
  ),
  LocaleKeys.critical_alarm_close_queued_body: DeviceKeys(
    ipad: LocaleKeys.critical_alarm_close_queued_body_ipad,
    tablet: LocaleKeys.critical_alarm_close_queued_body_tablet,
  ),
  LocaleKeys.critical_alarm_ack_queued_body: DeviceKeys(
    ipad: LocaleKeys.critical_alarm_ack_queued_body_ipad,
    tablet: LocaleKeys.critical_alarm_ack_queued_body_tablet,
  ),
  LocaleKeys.critical_alarm_load_failed_body: DeviceKeys(
    ipad: LocaleKeys.critical_alarm_load_failed_body_ipad,
    tablet: LocaleKeys.critical_alarm_load_failed_body_tablet,
  ),
  LocaleKeys.critical_alarm_silence_button: DeviceKeys(
    ipad: LocaleKeys.critical_alarm_silence_button_ipad,
    tablet: LocaleKeys.critical_alarm_silence_button_tablet,
  ),
  LocaleKeys.critical_alarm_ack_failed: DeviceKeys(
    ipad: LocaleKeys.critical_alarm_ack_failed_ipad,
    tablet: LocaleKeys.critical_alarm_ack_failed_tablet,
  ),
  LocaleKeys.settings_server_disconnect_hint: DeviceKeys(
    ipad: LocaleKeys.settings_server_disconnect_hint_ipad,
    tablet: LocaleKeys.settings_server_disconnect_hint_tablet,
  ),
  LocaleKeys.settings_server_stage_connected: DeviceKeys(
    ipad: LocaleKeys.settings_server_stage_connected_ipad,
    tablet: LocaleKeys.settings_server_stage_connected_tablet,
    computer: LocaleKeys.settings_server_stage_connected_computer,
  ),
  LocaleKeys.settings_server_stage_disconnected: DeviceKeys(
    ipad: LocaleKeys.settings_server_stage_disconnected_ipad,
    tablet: LocaleKeys.settings_server_stage_disconnected_tablet,
    computer: LocaleKeys.settings_server_stage_disconnected_computer,
  ),
  LocaleKeys.settings_priorities_row_subtitle: DeviceKeys(
    ipad: LocaleKeys.settings_priorities_row_subtitle_ipad,
    tablet: LocaleKeys.settings_priorities_row_subtitle_tablet,
  ),
  LocaleKeys.settings_plan_selfhosted_title: DeviceKeys(
    ipad: LocaleKeys.settings_plan_selfhosted_title_ipad,
    tablet: LocaleKeys.settings_plan_selfhosted_title_tablet,
    computer: LocaleKeys.settings_plan_selfhosted_title_computer,
  ),
  LocaleKeys.settings_storage_row_subtitle: DeviceKeys(
    ipad: LocaleKeys.settings_storage_row_subtitle_ipad,
    tablet: LocaleKeys.settings_storage_row_subtitle_tablet,
    computer: LocaleKeys.settings_storage_row_subtitle_computer,
  ),
  LocaleKeys.settings_server_row_subtitle: DeviceKeys(
    ipad: LocaleKeys.settings_server_row_subtitle_ipad,
    tablet: LocaleKeys.settings_server_row_subtitle_tablet,
  ),
  LocaleKeys.settings_help_report_sub: DeviceKeys(
    ipad: LocaleKeys.settings_help_report_sub_ipad,
    tablet: LocaleKeys.settings_help_report_sub_tablet,
    computer: LocaleKeys.settings_help_report_sub_computer,
  ),
  LocaleKeys.device_permissions_battery_explain_body: DeviceKeys(
    tablet: LocaleKeys.device_permissions_battery_explain_body_tablet,
  ),
  LocaleKeys.maker_guide_line_unchecked: DeviceKeys(
    tablet: LocaleKeys.maker_guide_line_unchecked_tablet,
  ),
  LocaleKeys.maker_guide_line_os_changed: DeviceKeys(
    tablet: LocaleKeys.maker_guide_line_os_changed_tablet,
  ),
  LocaleKeys.maker_guide_stage_line: DeviceKeys(
    tablet: LocaleKeys.maker_guide_stage_line_tablet,
  ),
  LocaleKeys.maker_guide_done_line: DeviceKeys(
    tablet: LocaleKeys.maker_guide_done_line_tablet,
  ),
  LocaleKeys.reliability_overall_fine_line: DeviceKeys(
    ipad: LocaleKeys.reliability_overall_fine_line_ipad,
    tablet: LocaleKeys.reliability_overall_fine_line_tablet,
  ),
  LocaleKeys.reliability_line_refused: DeviceKeys(
    ipad: LocaleKeys.reliability_line_refused_ipad,
    tablet: LocaleKeys.reliability_line_refused_tablet,
  ),
  LocaleKeys.reliability_line_os_changed: DeviceKeys(
    ipad: LocaleKeys.reliability_line_os_changed_ipad,
    tablet: LocaleKeys.reliability_line_os_changed_tablet,
  ),
  LocaleKeys.reliability_line_clock: DeviceKeys(
    ipad: LocaleKeys.reliability_line_clock_ipad,
    tablet: LocaleKeys.reliability_line_clock_tablet,
  ),
  LocaleKeys.reliability_line_denied_alarms: DeviceKeys(
    ipad: LocaleKeys.reliability_line_denied_alarms_ipad,
    tablet: LocaleKeys.reliability_line_denied_alarms_tablet,
  ),
  LocaleKeys.reliability_line_restricted: DeviceKeys(
    ipad: LocaleKeys.reliability_line_restricted_ipad,
    tablet: LocaleKeys.reliability_line_restricted_tablet,
  ),
  LocaleKeys.wake_chip_pass: DeviceKeys(
    ipad: LocaleKeys.wake_chip_pass_ipad,
    tablet: LocaleKeys.wake_chip_pass_tablet,
  ),
  LocaleKeys.wake_stop_phone: DeviceKeys(
    ipad: LocaleKeys.wake_stop_phone_ipad,
    tablet: LocaleKeys.wake_stop_phone_tablet,
  ),
  LocaleKeys.weekly_check_what_line: DeviceKeys(
    ipad: LocaleKeys.weekly_check_what_line_ipad,
    tablet: LocaleKeys.weekly_check_what_line_tablet,
  ),
  LocaleKeys.weekly_check_line_token_refused: DeviceKeys(
    ipad: LocaleKeys.weekly_check_line_token_refused_ipad,
    tablet: LocaleKeys.weekly_check_line_token_refused_tablet,
  ),
  LocaleKeys.paywall_kit_benefits_custom_sounds_line: DeviceKeys(
    ipad: LocaleKeys.paywall_kit_benefits_custom_sounds_line_ipad,
    tablet: LocaleKeys.paywall_kit_benefits_custom_sounds_line_tablet,
    computer: LocaleKeys.paywall_kit_benefits_custom_sounds_line_computer,
  ),
  LocaleKeys.hosted_benefits_weekly_check_short: DeviceKeys(
    ipad: LocaleKeys.hosted_benefits_weekly_check_short_ipad,
    tablet: LocaleKeys.hosted_benefits_weekly_check_short_tablet,
  ),
  LocaleKeys.api_errors_unknown_phone: DeviceKeys(
    ipad: LocaleKeys.api_errors_unknown_phone_ipad,
    tablet: LocaleKeys.api_errors_unknown_phone_tablet,
    computer: LocaleKeys.api_errors_unknown_phone_computer,
  ),
  LocaleKeys.sound_picker_user_local_only: DeviceKeys(
    ipad: LocaleKeys.sound_picker_user_local_only_ipad,
    tablet: LocaleKeys.sound_picker_user_local_only_tablet,
    computer: LocaleKeys.sound_picker_user_local_only_computer,
  ),
  LocaleKeys.sound_picker_row_too_long_ios: DeviceKeys(
    ipad: LocaleKeys.sound_picker_row_too_long_ios_ipad,
    computer: LocaleKeys.sound_picker_row_too_long_ios_computer,
  ),
  LocaleKeys.account_row_subtitle: DeviceKeys(
    ipad: LocaleKeys.account_row_subtitle_ipad,
    tablet: LocaleKeys.account_row_subtitle_tablet,
    computer: LocaleKeys.account_row_subtitle_computer,
  ),
  LocaleKeys.account_signed_out_pitch: DeviceKeys(
    ipad: LocaleKeys.account_signed_out_pitch_ipad,
    tablet: LocaleKeys.account_signed_out_pitch_tablet,
    computer: LocaleKeys.account_signed_out_pitch_computer,
  ),
  LocaleKeys.account_error_other_identity: DeviceKeys(
    ipad: LocaleKeys.account_error_other_identity_ipad,
    tablet: LocaleKeys.account_error_other_identity_tablet,
    computer: LocaleKeys.account_error_other_identity_computer,
  ),
  LocaleKeys.account_choose_title: DeviceKeys(
    ipad: LocaleKeys.account_choose_title_ipad,
    tablet: LocaleKeys.account_choose_title_tablet,
    computer: LocaleKeys.account_choose_title_computer,
  ),
  LocaleKeys.account_choose_body: DeviceKeys(
    ipad: LocaleKeys.account_choose_body_ipad,
    tablet: LocaleKeys.account_choose_body_tablet,
    computer: LocaleKeys.account_choose_body_computer,
  ),
  LocaleKeys.account_keep_both_body: DeviceKeys(
    ipad: LocaleKeys.account_keep_both_body_ipad,
    tablet: LocaleKeys.account_keep_both_body_tablet,
    computer: LocaleKeys.account_keep_both_body_computer,
  ),
  LocaleKeys.account_start_fresh_body: DeviceKeys(
    ipad: LocaleKeys.account_start_fresh_body_ipad,
    tablet: LocaleKeys.account_start_fresh_body_tablet,
    computer: LocaleKeys.account_start_fresh_body_computer,
  ),
  LocaleKeys.account_start_fresh_tokens: DeviceKeys(
    ipad: LocaleKeys.account_start_fresh_tokens_ipad,
    tablet: LocaleKeys.account_start_fresh_tokens_tablet,
    computer: LocaleKeys.account_start_fresh_tokens_computer,
  ),
  LocaleKeys.account_delete_failed: DeviceKeys(
    ipad: LocaleKeys.account_delete_failed_ipad,
    tablet: LocaleKeys.account_delete_failed_tablet,
    computer: LocaleKeys.account_delete_failed_computer,
  ),
  LocaleKeys.local_reminders_drill_title_7: DeviceKeys(
    ipad: LocaleKeys.local_reminders_drill_title_7_ipad,
    tablet: LocaleKeys.local_reminders_drill_title_7_tablet,
  ),
  LocaleKeys.local_reminders_backup_body: DeviceKeys(
    ipad: LocaleKeys.local_reminders_backup_body_ipad,
    tablet: LocaleKeys.local_reminders_backup_body_tablet,
  ),
  LocaleKeys.local_reminders_ring_error_unauthorized: DeviceKeys(
    ipad: LocaleKeys.local_reminders_ring_error_unauthorized_ipad,
    tablet: LocaleKeys.local_reminders_ring_error_unauthorized_tablet,
  ),
  LocaleKeys.paywall_lead_jobs_line: DeviceKeys(
    ipad: LocaleKeys.paywall_lead_jobs_line_ipad,
    tablet: LocaleKeys.paywall_lead_jobs_line_tablet,
  ),
  LocaleKeys.paywall_thanks_restored_hosted: DeviceKeys(
    ipad: LocaleKeys.paywall_thanks_restored_hosted_ipad,
    tablet: LocaleKeys.paywall_thanks_restored_hosted_tablet,
    computer: LocaleKeys.paywall_thanks_restored_hosted_computer,
  ),
  LocaleKeys.paywall_thanks_restored_pro: DeviceKeys(
    ipad: LocaleKeys.paywall_thanks_restored_pro_ipad,
    tablet: LocaleKeys.paywall_thanks_restored_pro_tablet,
    computer: LocaleKeys.paywall_thanks_restored_pro_computer,
  ),
  LocaleKeys.personalize_passes_look_same_as_phone: DeviceKeys(
    ipad: LocaleKeys.personalize_passes_look_same_as_phone_ipad,
    tablet: LocaleKeys.personalize_passes_look_same_as_phone_tablet,
    computer: LocaleKeys.personalize_passes_look_same_as_phone_computer,
  ),
  LocaleKeys.alarm_styles_own_private_note: DeviceKeys(
    ipad: LocaleKeys.alarm_styles_own_private_note_ipad,
    tablet: LocaleKeys.alarm_styles_own_private_note_tablet,
    computer: LocaleKeys.alarm_styles_own_private_note_computer,
  ),
  LocaleKeys.home_card_label_will_it_wake_me: DeviceKeys(
    ipad: LocaleKeys.home_card_label_will_it_wake_me_ipad,
    tablet: LocaleKeys.home_card_label_will_it_wake_me_tablet,
  ),
  LocaleKeys.home_card_check_system_update: DeviceKeys(
    ipad: LocaleKeys.home_card_check_system_update_ipad,
    tablet: LocaleKeys.home_card_check_system_update_tablet,
  ),
  LocaleKeys.home_card_check_phone_maker: DeviceKeys(
    tablet: LocaleKeys.home_card_check_phone_maker_tablet,
  ),
  LocaleKeys.alarm_loudness_line: DeviceKeys(
    ipad: LocaleKeys.alarm_loudness_line_ipad,
  ),
  LocaleKeys.onboarding_welcome_rings_subtitle: DeviceKeys(
    ipad: LocaleKeys.onboarding_welcome_rings_subtitle_ipad,
  ),
  LocaleKeys.onboarding_welcome_story_rings: DeviceKeys(
    ipad: LocaleKeys.onboarding_welcome_story_rings_ipad,
  ),
  LocaleKeys.onboarding_welcome_story_until_ack: DeviceKeys(
    ipad: LocaleKeys.onboarding_welcome_story_until_ack_ipad,
  ),
  LocaleKeys.onboarding_welcome_feature_alarm: DeviceKeys(
    ipad: LocaleKeys.onboarding_welcome_feature_alarm_ipad,
  ),
  LocaleKeys.onboarding_real_ring_subtitle: DeviceKeys(
    ipad: LocaleKeys.onboarding_real_ring_subtitle_ipad,
  ),
  LocaleKeys.onboarding_permissions_ios_alarms_subtitle: DeviceKeys(
    ipad: LocaleKeys.onboarding_permissions_ios_alarms_subtitle_ipad,
  ),
  LocaleKeys.priorities_alarm_ios: DeviceKeys(
    ipad: LocaleKeys.priorities_alarm_ios_ipad,
  ),
  LocaleKeys.topic_detail_critical_toggle_subtitle: DeviceKeys(
    ipad: LocaleKeys.topic_detail_critical_toggle_subtitle_ipad,
  ),
  LocaleKeys.create_topic_critical_toggle_subtitle: DeviceKeys(
    ipad: LocaleKeys.create_topic_critical_toggle_subtitle_ipad,
  ),
  LocaleKeys.create_topic_first_topic_critical_subtitle_on: DeviceKeys(
    ipad: LocaleKeys.create_topic_first_topic_critical_subtitle_on_ipad,
  ),
  LocaleKeys.home_day0_free_line: DeviceKeys(
    ipad: LocaleKeys.home_day0_free_line_ipad,
  ),
};
