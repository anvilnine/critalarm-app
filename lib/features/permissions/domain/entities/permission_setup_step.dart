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

/// The steps one run of the screen draws, in order.
///
/// A granted step is never drawn. [alreadyShown] holds the steps this run has
/// been on: they stay in the list whatever their status, so the count on
/// screen never drops under the user. [cannotAsk] holds steps whose prompt is
/// spent and will not come up again.
///
/// In setup a step that only explains follows the others, and is not worth a
/// screen by itself: with every permission granted the answer is empty.
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
      if (alreadyShown.isEmpty && !steps.any(needsAnswer)) return const [];
      return [
        for (final step in steps)
          if (alreadyShown.contains(step) ||
              needsAnswer(step) ||
              step.permission == null)
            step,
      ];
  }
}

/// The first step in [rendered] this run has not been on yet, or null when
/// there is none left and the screen is done.
///
/// [rendered] comes from [permissionStepsToRender], which has already left
/// out what is granted, so this is the first step that still needs an
/// answer. It never goes back to a step the user answered or skipped.
PermissionSetupStep? nextPermissionStep(
  List<PermissionSetupStep> rendered, {
  required Set<PermissionSetupStep> alreadyShown,
}) {
  for (final step in rendered) {
    if (!alreadyShown.contains(step)) return step;
  }
  return null;
}
