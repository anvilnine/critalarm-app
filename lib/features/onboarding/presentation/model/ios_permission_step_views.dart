import 'package:critalarm/core/alarm/ring_claim.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/onboarding/presentation/model/onboarding_ambient_profiles.dart';
import 'package:critalarm/features/onboarding/presentation/model/permission_step_view.dart';
import 'package:critalarm/features/onboarding/presentation/widgets/ios_permission_dialog_preview.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';

/// The iOS notification step.
PermissionStepView iosNotificationsStepView() {
  final previewTitle = LocaleKeys
      .onboarding_permissions_ios_notifications_preview_title
      .tr();
  return PermissionStepView(
    face: FaceState.alarmed,
    ambient: OnboardingAmbientStep.notifications,
    badge: LocaleKeys.onboarding_permissions_ios_notifications_badge.tr(),
    title: LocaleKeys.onboarding_permissions_ios_notifications_title.tr(),
    subtitle: LocaleKeys.onboarding_permissions_ios_notifications_subtitle.tr(),
    button: LocaleKeys.onboarding_permissions_ios_notifications_button.tr(),
    preview: PermissionStepPreview(
      title: previewTitle,
      hint: LocaleKeys.onboarding_permissions_ios_notifications_preview_hint
          .tr(),
      child: IosPermissionDialogPreview(
        title: previewTitle,
        message: LocaleKeys
            .onboarding_permissions_ios_notifications_preview_desc
            .tr(),
        allowLabel: LocaleKeys
            .onboarding_permissions_ios_notifications_preview_allow
            .tr(),
        summaryLabel: LocaleKeys
            .onboarding_permissions_ios_notifications_preview_allow_summary
            .tr(),
        denyLabel: LocaleKeys
            .onboarding_permissions_ios_notifications_preview_dont_allow
            .tr(),
      ),
    ),
  );
}

/// The iOS notification step once iOS will not prompt again: it prompts
/// once. The button opens the app's page in Settings, so a switch is drawn
/// and nothing says a prompt is coming.
PermissionStepView iosNotificationsSettingsStepView() {
  final previewTitle = LocaleKeys
      .onboarding_permissions_ios_notifications_settings_preview_title
      .tr();
  return PermissionStepView(
    face: FaceState.alarmed,
    ambient: OnboardingAmbientStep.notifications,
    badge: LocaleKeys.onboarding_permissions_ios_notifications_badge.tr(),
    title: LocaleKeys.onboarding_permissions_ios_notifications_title.tr(),
    subtitle: LocaleKeys.onboarding_permissions_ios_notifications_subtitle.tr(),
    button: LocaleKeys.onboarding_permissions_ios_notifications_settings_button
        .tr(),
    preview: PermissionStepPreview(
      title: previewTitle,
      hint: LocaleKeys
          .onboarding_permissions_ios_notifications_settings_preview_hint
          .tr(),
      child: IosSettingsSwitchPreview(
        title: previewTitle,
        message: LocaleKeys
            .onboarding_permissions_ios_notifications_settings_preview_desc
            .tr(),
      ),
    ),
  );
}

/// The AlarmKit step, iOS 26 or later.
///
/// The chip follows [claim]. This step only exists on a phone that has
/// AlarmKit, where the claim is [RingClaim.alarm]. Should the two ever
/// disagree, the chip says the smaller thing: a phone below iOS 26 is never
/// told it rings through silent mode.
PermissionStepView iosAlarmsStepView(RingClaim claim) {
  final previewTitle = LocaleKeys
      .onboarding_permissions_ios_alarms_preview_title
      .tr();
  return PermissionStepView(
    face: FaceState.watching,
    ambient: OnboardingAmbientStep.alarms,
    badge: switch (claim) {
      RingClaim.alarm =>
        LocaleKeys.onboarding_permissions_ios_alarms_badge.tr(),
      RingClaim.timeSensitive =>
        LocaleKeys.onboarding_permissions_ios_time_sensitive_badge.tr(),
    },
    title: LocaleKeys.onboarding_permissions_ios_alarms_title.tr(),
    subtitle: LocaleKeys.onboarding_permissions_ios_alarms_subtitle.tr(),
    button: LocaleKeys.onboarding_permissions_ios_alarms_button.tr(),
    preview: PermissionStepPreview(
      title: previewTitle,
      hint: LocaleKeys.onboarding_permissions_ios_alarms_preview_hint.tr(),
      child: IosPermissionDialogPreview(
        title: previewTitle,
        message: LocaleKeys.onboarding_permissions_ios_alarms_preview_desc.tr(),
        allowLabel: LocaleKeys.onboarding_permissions_ios_alarms_preview_allow
            .tr(),
        denyLabel: LocaleKeys
            .onboarding_permissions_ios_alarms_preview_dont_allow
            .tr(),
      ),
    ),
  );
}

/// iOS 16 to 25: what the phone does in place of an alarm. No prompt is
/// coming, so there is nothing to draw and nothing to skip.
PermissionStepView iosTimeSensitiveStepView() => PermissionStepView(
  face: FaceState.watching,
  ambient: OnboardingAmbientStep.alarms,
  badge: LocaleKeys.onboarding_permissions_ios_time_sensitive_badge.tr(),
  title: LocaleKeys.onboarding_permissions_ios_time_sensitive_title.tr(),
  subtitle: LocaleKeys.onboarding_permissions_ios_time_sensitive_subtitle.tr(),
  button: LocaleKeys.onboarding_permissions_ios_time_sensitive_button.tr(),
  canSkip: false,
);
