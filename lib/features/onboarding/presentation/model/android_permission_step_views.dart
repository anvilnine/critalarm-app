import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/onboarding/presentation/model/onboarding_ambient_profiles.dart';
import 'package:critalarm/features/onboarding/presentation/model/permission_step_view.dart';
import 'package:critalarm/features/onboarding/presentation/widgets/android_permission_dialog_preview.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// The Android notification step. The system shows a dialog.
PermissionStepView androidNotificationsStepView() {
  final previewTitle = LocaleKeys
      .onboarding_permissions_android_notifications_preview_title
      .tr();
  return PermissionStepView(
    // A polite ask, so the face is interested, not shouting.
    face: FaceState.interested,
    ambient: OnboardingAmbientStep.notifications,
    title: LocaleKeys.onboarding_permissions_android_notifications_title.tr(),
    subtitle: LocaleKeys.onboarding_permissions_android_notifications_subtitle
        .tr(),
    button: LocaleKeys.onboarding_permissions_android_notifications_button.tr(),
    preview: PermissionStepPreview(
      title: previewTitle,
      // The real Android dialog has no body text either.
      child: AndroidPermissionDialogPreview(
        icon: Icons.notifications_active_rounded,
        title: previewTitle,
        allowLabel: LocaleKeys
            .onboarding_permissions_android_notifications_preview_allow
            .tr(),
        denyLabel: LocaleKeys
            .onboarding_permissions_android_notifications_preview_dont_allow
            .tr(),
      ),
    ),
  );
}

/// The Android notification step once the system will not prompt again:
/// after a refusal, or below Android 13 where there never was a prompt. The
/// button opens the app's notification settings, so a switch is drawn and
/// nothing says a prompt is coming.
PermissionStepView androidNotificationsSettingsStepView() {
  final previewTitle = LocaleKeys
      .onboarding_permissions_android_notifications_settings_preview_title
      .tr();
  return PermissionStepView(
    face: FaceState.interested,
    ambient: OnboardingAmbientStep.notifications,
    title: LocaleKeys.onboarding_permissions_android_notifications_title.tr(),
    subtitle: LocaleKeys.onboarding_permissions_android_notifications_subtitle
        .tr(),
    button: LocaleKeys
        .onboarding_permissions_android_notifications_settings_button
        .tr(),
    preview: PermissionStepPreview(
      title: previewTitle,
      hint: LocaleKeys
          .onboarding_permissions_android_notifications_settings_preview_hint
          .tr(),
      child: AndroidSettingsSwitchPreview(title: previewTitle),
    ),
  );
}

/// The full-screen alarm step. Android has no dialog for it: the button
/// opens a settings page with one switch, so that is what is drawn.
///
/// The words say what the screen does and make no promise about ringing
/// through silent mode, so they are the same whatever the phone can claim.
PermissionStepView androidFullScreenStepView() {
  final previewTitle = LocaleKeys
      .onboarding_permissions_android_full_screen_preview_title
      .tr();
  return PermissionStepView(
    face: FaceState.confident,
    ambient: OnboardingAmbientStep.alarms,
    title: LocaleKeys.onboarding_permissions_android_full_screen_title.tr(),
    subtitle: LocaleKeys.onboarding_permissions_android_full_screen_subtitle
        .tr(),
    button: LocaleKeys.onboarding_permissions_android_full_screen_button.tr(),
    preview: PermissionStepPreview(
      title: previewTitle,
      hint: LocaleKeys.onboarding_permissions_android_full_screen_preview_hint
          .tr(),
      child: AndroidSettingsSwitchPreview(title: previewTitle),
    ),
  );
}

/// The battery step, only on phones whose maker puts apps to sleep. The
/// system asks in a dialog. Its one line of why makes no promise about
/// ringing through silent mode: it is about an alarm arriving on time.
PermissionStepView androidBatteryStepView() {
  final previewTitle = LocaleKeys
      .onboarding_permissions_android_battery_preview_title
      .tr();
  return PermissionStepView(
    // The copy is about apps being put to sleep, and allowing wakes it.
    face: FaceState.sleepy,
    grantedFace: FaceState.wakesUp,
    ambient: OnboardingAmbientStep.battery,
    title: LocaleKeys.onboarding_permissions_android_battery_title.tr(),
    subtitle: LocaleKeys.onboarding_permissions_android_battery_subtitle.tr(),
    button: LocaleKeys.onboarding_permissions_android_battery_button.tr(),
    preview: PermissionStepPreview(
      title: previewTitle,
      child: AndroidPermissionDialogPreview(
        icon: Icons.battery_saver_rounded,
        title: previewTitle,
        message: LocaleKeys.onboarding_permissions_android_battery_preview_desc
            .tr(),
        allowLabel: LocaleKeys
            .onboarding_permissions_android_battery_preview_allow
            .tr(),
        denyLabel: LocaleKeys
            .onboarding_permissions_android_battery_preview_deny
            .tr(),
      ),
    ),
  );
}
