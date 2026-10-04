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
    face: FaceState.alarmed,
    ambient: OnboardingAmbientStep.notifications,
    badge: LocaleKeys.onboarding_permissions_android_notifications_badge.tr(),
    title: LocaleKeys.onboarding_permissions_android_notifications_title.tr(),
    subtitle: LocaleKeys.onboarding_permissions_android_notifications_subtitle
        .tr(),
    button: LocaleKeys.onboarding_permissions_android_notifications_button.tr(),
    preview: PermissionStepPreview(
      title: previewTitle,
      hint: LocaleKeys.onboarding_permissions_android_notifications_preview_hint
          .tr(),
      child: AndroidPermissionDialogPreview(
        icon: Icons.notifications_active_rounded,
        title: previewTitle,
        message: LocaleKeys
            .onboarding_permissions_android_notifications_preview_desc
            .tr(),
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

/// The full-screen alarm step. Android has no dialog for it: the button
/// opens a settings page with one switch, so that is what is drawn.
PermissionStepView androidFullScreenStepView() {
  final previewTitle = LocaleKeys
      .onboarding_permissions_android_full_screen_preview_title
      .tr();
  return PermissionStepView(
    face: FaceState.watching,
    ambient: OnboardingAmbientStep.alarms,
    badge: LocaleKeys.onboarding_permissions_android_full_screen_badge.tr(),
    title: LocaleKeys.onboarding_permissions_android_full_screen_title.tr(),
    subtitle: LocaleKeys.onboarding_permissions_android_full_screen_subtitle
        .tr(),
    button: LocaleKeys.onboarding_permissions_android_full_screen_button.tr(),
    preview: PermissionStepPreview(
      title: previewTitle,
      hint: LocaleKeys.onboarding_permissions_android_full_screen_preview_hint
          .tr(),
      child: AndroidSettingsSwitchPreview(
        title: previewTitle,
        message: LocaleKeys
            .onboarding_permissions_android_full_screen_preview_desc
            .tr(),
      ),
    ),
  );
}

/// The battery step, only on phones whose maker puts apps to sleep. The
/// system asks in a dialog. Its one line of why makes no promise about
/// ringing through silent mode: it is about a page arriving on time.
PermissionStepView androidBatteryStepView() {
  final previewTitle = LocaleKeys
      .onboarding_permissions_android_battery_preview_title
      .tr();
  return PermissionStepView(
    face: FaceState.curious,
    ambient: OnboardingAmbientStep.battery,
    badge: LocaleKeys.onboarding_permissions_android_battery_badge.tr(),
    title: LocaleKeys.onboarding_permissions_android_battery_title.tr(),
    subtitle: LocaleKeys.onboarding_permissions_android_battery_subtitle.tr(),
    button: LocaleKeys.onboarding_permissions_android_battery_button.tr(),
    preview: PermissionStepPreview(
      title: previewTitle,
      hint: LocaleKeys.onboarding_permissions_android_battery_preview_hint.tr(),
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
