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
    // A polite ask, so the face is interested, not shouting.
    face: FaceState.interested,
    ambient: OnboardingAmbientStep.notifications,
    title: LocaleKeys.onboarding_permissions_ios_notifications_title.tr(),
    subtitle: LocaleKeys.onboarding_permissions_ios_notifications_subtitle.tr(),
    button: LocaleKeys.onboarding_permissions_ios_notifications_button.tr(),
    preview: PermissionStepPreview(
      title: previewTitle,
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
    face: FaceState.interested,
    ambient: OnboardingAmbientStep.notifications,
    title: LocaleKeys.onboarding_permissions_ios_notifications_title.tr(),
    subtitle: LocaleKeys.onboarding_permissions_ios_notifications_subtitle.tr(),
    button: LocaleKeys.onboarding_permissions_ios_notifications_settings_button
        .tr(),
    preview: PermissionStepPreview(
      title: previewTitle,
      hint: LocaleKeys
          .onboarding_permissions_ios_notifications_settings_preview_hint
          .tr(),
      child: IosSettingsSwitchPreview(title: previewTitle),
    ),
  );
}

/// The AlarmKit step, iOS 26 or later.
///
/// Its title promises a ring through silent mode, so it is drawn only for
/// [RingClaim.alarm]. This step exists only on a phone that has AlarmKit.
/// Should the two ever disagree, the step says the smaller thing: a phone
/// below iOS 26 is never told it rings through silent mode.
PermissionStepView iosAlarmsStepView(RingClaim claim) {
  if (claim == RingClaim.timeSensitive) return iosTimeSensitiveStepView();
  final previewTitle = LocaleKeys
      .onboarding_permissions_ios_alarms_preview_title
      .tr();
  return PermissionStepView(
    // "I can ring through anything."
    face: FaceState.confident,
    ambient: OnboardingAmbientStep.alarms,
    title: LocaleKeys.onboarding_permissions_ios_alarms_title.tr(),
    subtitle: LocaleKeys.onboarding_permissions_ios_alarms_subtitle.tr(),
    button: LocaleKeys.onboarding_permissions_ios_alarms_button.tr(),
    preview: PermissionStepPreview(
      title: previewTitle,
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
  // A calm, honest limit.
  face: FaceState.content,
  ambient: OnboardingAmbientStep.alarms,
  title: LocaleKeys.onboarding_permissions_ios_time_sensitive_title.tr(),
  subtitle: LocaleKeys.onboarding_permissions_ios_time_sensitive_subtitle.tr(),
  button: LocaleKeys.onboarding_permissions_ios_time_sensitive_button.tr(),
  canSkip: false,
);
