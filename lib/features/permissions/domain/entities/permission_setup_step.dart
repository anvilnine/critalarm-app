import 'package:critalarm/core/device/device_maker.dart';
import 'package:critalarm/features/permissions/domain/entities/background_killer_makers.dart';
import 'package:critalarm/features/permissions/domain/entities/device_permission_type.dart';
import 'package:flutter/foundation.dart';

/// One step of the permissions screen in setup.
///
/// iOS and Android have their own steps, even where both ask for the same
/// thing, because the prompt, the words and the picture differ. A list from
/// [permissionSetupStepsFor] never mixes the two.
enum PermissionSetupStep {
  /// The iOS notification prompt.
  iosNotifications(DevicePermissionType.notifications),

  /// The AlarmKit prompt, iOS 26 or later. It prompts once.
  iosAlarms(DevicePermissionType.alarms),

  /// iOS 16 to 25. There is no alarm to ask for, so this step says what the
  /// phone does instead. It has nothing to grant and no prompt behind it.
  iosTimeSensitiveExplainer(null, asksOnItsOwn: false),

  /// The Android notification prompt.
  androidNotifications(DevicePermissionType.notifications),

  /// Android's full-screen alarm permission, a switch on a settings page.
  androidFullScreen(DevicePermissionType.fullScreenIntent),

  /// The battery exemption, only on phones from [backgroundKillerMakers].
  ///
  /// Setup shows no guide, notice, ask or reminder, and this is none of
  /// those. It is a permission step on the permissions screen: shown once,
  /// skippable, and only on phones where the maker is known to put apps to
  /// sleep and a page can arrive late. Stock Android never sees it, because
  /// nothing in the ring path needs the exemption there. Settings > Health
  /// keeps its own battery row for every phone, with its own explanation, so
  /// the standalone screen leaves this step out.
  androidBattery(DevicePermissionType.batteryOptimization, asksOnItsOwn: false);

  const PermissionSetupStep(this.permission, {this.asksOnItsOwn = true});

  /// The permission whose status says whether this step is done. Null for a
  /// step that only explains.
  final DevicePermissionType? permission;

  /// Whether the step also shows when the screen is opened on its own,
  /// outside setup, to ask for what was never asked.
  final bool asksOnItsOwn;
}

/// The ordered permission steps of setup on this phone.
///
/// The one definition of what setup asks for. The screen draws these and the
/// flow engine checks these, so the two cannot disagree. Every input is a
/// value, so nothing here reads the platform.
///
/// - iOS with AlarmKit (iOS 26 or later): notifications, then alarms.
/// - iOS without it: notifications, then the Time-Sensitive explainer.
/// - Android: notifications, then full-screen alarms, then battery when
///   [maker] is one that kills background apps.
/// - Web and desktop: none.
///
/// To add a step for one platform, add a value to [PermissionSetupStep] and
/// list it under that platform here.
List<PermissionSetupStep> permissionSetupStepsFor(
  TargetPlatform platform, {
  required bool isWeb,
  required bool hasAlarmKit,
  required DeviceMaker maker,
}) {
  if (isWeb) return const [];
  return switch (platform) {
    TargetPlatform.iOS => [
      PermissionSetupStep.iosNotifications,
      if (hasAlarmKit)
        PermissionSetupStep.iosAlarms
      else
        PermissionSetupStep.iosTimeSensitiveExplainer,
    ],
    TargetPlatform.android => [
      PermissionSetupStep.androidNotifications,
      PermissionSetupStep.androidFullScreen,
      if (makerKillsBackgroundApps(maker)) PermissionSetupStep.androidBattery,
    ],
    _ => const [],
  };
}

/// Whether every permission in [steps] is granted. A step with nothing to
/// grant does not count either way.
bool everySetupPermissionGranted(
  List<PermissionSetupStep> steps,
  Set<PermissionSetupStep> granted,
) => steps.every((step) => step.permission == null || granted.contains(step));

/// Why the permissions screen is open, which decides what it draws.
enum PermissionAskMode {
  /// Part of setup. A granted step is left out.
  setup,

  /// Opened on its own, to ask for a permission the user was never asked.
  /// Only a step with a prompt left behind it shows.
  standalone,

  /// Opened to look at the screens. Every step shows.
  replay,
}

/// The steps one run of the screen would draw if it opened now, in order.
///
/// A granted step is never drawn. [alreadyShown] holds the steps this run has
/// been on: they stay in the list whatever their status. [cannotAsk] holds
/// steps whose prompt is spent and will not come up again.
///
/// A step that only explains what the phone does with notifications follows
/// the notification step, and only once notifications are granted: after a
/// refusal what it says would be false. It is never worth a screen by
/// itself, so with every permission granted the answer is empty.
List<PermissionSetupStep> permissionStepsToRender(
  List<PermissionSetupStep> steps, {
  required Set<PermissionSetupStep> granted,
  PermissionAskMode mode = PermissionAskMode.setup,
  Set<PermissionSetupStep> alreadyShown = const {},
  Set<PermissionSetupStep> cannotAsk = const {},
}) {
  bool needsAnswer(PermissionSetupStep step) =>
      step.permission != null && !granted.contains(step);

  switch (mode) {
    case PermissionAskMode.replay:
      return List.of(steps);
    case PermissionAskMode.standalone:
      return [
        for (final step in steps)
          if (alreadyShown.contains(step) ||
              (needsAnswer(step) &&
                  step.asksOnItsOwn &&
                  !cannotAsk.contains(step)))
            step,
      ];
    case PermissionAskMode.setup:
      final explains =
          alreadyShown.isNotEmpty &&
          granted.contains(PermissionSetupStep.iosNotifications);
      return [
        for (final step in steps)
          if (alreadyShown.contains(step) ||
              needsAnswer(step) ||
              (step.permission == null && explains))
            step,
      ];
  }
}

/// Keeps the list on screen still while the run goes on.
///
/// [frozen] is what the screen has drawn dots for. [fresh] is what
/// [permissionStepsToRender] says now. A step is never taken out of [frozen]
/// and never put in before its last step, so no dot the user has seen moves.
/// A step [fresh] adds after the last frozen one is appended. [order] is the
/// phone's full list, which says what "after" means.
List<PermissionSetupStep> freezePermissionSteps(
  List<PermissionSetupStep> frozen,
  List<PermissionSetupStep> fresh, {
  required List<PermissionSetupStep> order,
}) {
  if (frozen.isEmpty) return fresh;
  final last = order.indexOf(frozen.last);
  return [
    ...frozen,
    for (final step in fresh)
      if (!frozen.contains(step) && order.indexOf(step) > last) step,
  ];
}

/// The next step to put on screen, or null when the screen is done.
///
/// It is the first step in [rendered] that this run has not been on and that
/// still needs an answer. A step granted since the list was frozen is passed
/// over, though its dot stays. It never goes back to a step the user answered
/// or skipped, even one that was revoked since. With [showGranted], for a
/// replay, a granted step is shown like any other.
PermissionSetupStep? nextPermissionStep(
  List<PermissionSetupStep> rendered, {
  required Set<PermissionSetupStep> alreadyShown,
  Set<PermissionSetupStep> granted = const {},
  bool showGranted = false,
}) {
  // Everything up to the last step shown is behind the user.
  var from = 0;
  for (var i = 0; i < rendered.length; i++) {
    if (alreadyShown.contains(rendered[i])) from = i + 1;
  }
  for (final step in rendered.skip(from)) {
    if (showGranted || !granted.contains(step)) return step;
  }
  return null;
}

/// Whether the button of a not-allowed [step], on the list a user who came
/// back to the permissions sees, opens Settings. Otherwise it asks the
/// system, which can still show its prompt.
///
/// Only the two prompts that come up once can still be asked, and only
/// until they have been ([promptSpent]). The full-screen switch lives on a
/// settings page, and the battery dialog is not raised a second time.
bool permissionAnswerOpensSettings(
  PermissionSetupStep step, {
  required bool promptSpent,
}) => switch (step) {
  PermissionSetupStep.iosNotifications ||
  PermissionSetupStep.androidNotifications ||
  PermissionSetupStep.iosAlarms => promptSpent,
  PermissionSetupStep.iosTimeSensitiveExplainer ||
  PermissionSetupStep.androidFullScreen ||
  PermissionSetupStep.androidBattery => true,
};

/// Whether the system will show the notification prompt again.
///
/// iOS prompts once. Android 13 or later stops prompting after a refusal,
/// and below 13 there is no prompt at all: notifications are a switch in
/// Settings. [refusedBefore] is whether the app asked and was told no.
/// [androidSdk] is null off Android or when it could not be read.
bool notificationPromptSpent({
  required TargetPlatform platform,
  required bool granted,
  required bool refusedBefore,
  required int? androidSdk,
}) {
  if (granted) return false;
  return switch (platform) {
    TargetPlatform.iOS => refusedBefore,
    TargetPlatform.android =>
      refusedBefore ||
          (androidSdk != null && androidSdk < _androidNotificationPromptSdk),
    _ => false,
  };
}

/// Android 13, the first version with a notification prompt.
const _androidNotificationPromptSdk = 33;
