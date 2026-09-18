import 'package:critalarm/core/alarm/alarm_host.dart';
import 'package:flutter/foundation.dart';

/// Step in the notification permissions onboarding flow.
enum NotificationPermissionStep {
  /// Prompt before user clicks allow.
  initial,

  /// In the middle of requesting permissions from the OS.
  requesting,

  /// All required permissions granted. Ready to proceed.
  granted,

  /// Permission was denied. Showing denial path with recovery action.
  denied,
}

@immutable
class NotificationPermissionsState {
  const NotificationPermissionsState({
    this.step = NotificationPermissionStep.initial,
    this.activeSubstep = 0,
    this.notificationsGranted = false,
    this.criticalAlertsGranted = false,
    this.errorMessage,
    this.canNavigate = false,
    this.alarm = AlarmAuthorization.notDetermined,
    this.liveActivityStarted = false,
    this.alarmSupported = true,
    this.isChecking = false,
    this.batteryNeeded = false,
    this.batteryGranted = false,
  });

  final NotificationPermissionStep step;

  /// 0 = Notifications step, 1 = Critical Alerts / Silent bypass step.
  final int activeSubstep;

  final bool notificationsGranted;
  final bool criticalAlertsGranted;
  final String? errorMessage;
  final bool canNavigate;

  /// Whether iOS lets the app set alarms / Critical Alerts.
  final AlarmAuthorization alarm;

  /// True once onboarding has started its one local Live Activity.
  final bool liveActivityStarted;

  /// False where this OS has no alarm permission to ask for: Android, and iOS
  /// below 26. The step still shows, saying plainly what the phone can do,
  /// rather than promising a ring the platform will never deliver.
  final bool alarmSupported;

  /// Re-reading the system state after the user came back from Settings.
  final bool isChecking;

  /// True on Android, where battery optimisation can put the app to sleep and
  /// hold a page back. Step 2 there asks to lift it instead of asking for an
  /// alarm permission Android does not have.
  final bool batteryNeeded;

  /// True once the app is exempt from battery optimisation.
  final bool batteryGranted;

  /// Step 2 on this phone is the battery step.
  bool get isBatteryStep => !alarmSupported && batteryNeeded;

  /// How many steps the stepper really has on this phone.
  int get totalSteps => alarmSupported || batteryNeeded ? 2 : 1;

  bool get isRequesting => step == NotificationPermissionStep.requesting;
  bool get isGranted => step == NotificationPermissionStep.granted;
  bool get isDenied => step == NotificationPermissionStep.denied;

  NotificationPermissionsState copyWith({
    NotificationPermissionStep? step,
    int? activeSubstep,
    bool? notificationsGranted,
    bool? criticalAlertsGranted,
    String? errorMessage,
    bool? canNavigate,
    AlarmAuthorization? alarm,
    bool? liveActivityStarted,
    bool? alarmSupported,
    bool? isChecking,
    bool? batteryNeeded,
    bool? batteryGranted,
    bool clearError = false,
  }) {
    return NotificationPermissionsState(
      step: step ?? this.step,
      activeSubstep: activeSubstep ?? this.activeSubstep,
      notificationsGranted: notificationsGranted ?? this.notificationsGranted,
      criticalAlertsGranted:
          criticalAlertsGranted ?? this.criticalAlertsGranted,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      canNavigate: canNavigate ?? this.canNavigate,
      alarm: alarm ?? this.alarm,
      liveActivityStarted: liveActivityStarted ?? this.liveActivityStarted,
      alarmSupported: alarmSupported ?? this.alarmSupported,
      isChecking: isChecking ?? this.isChecking,
      batteryNeeded: batteryNeeded ?? this.batteryNeeded,
      batteryGranted: batteryGranted ?? this.batteryGranted,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NotificationPermissionsState &&
          runtimeType == other.runtimeType &&
          step == other.step &&
          activeSubstep == other.activeSubstep &&
          notificationsGranted == other.notificationsGranted &&
          criticalAlertsGranted == other.criticalAlertsGranted &&
          errorMessage == other.errorMessage &&
          canNavigate == other.canNavigate &&
          alarm == other.alarm &&
          liveActivityStarted == other.liveActivityStarted &&
          alarmSupported == other.alarmSupported &&
          isChecking == other.isChecking &&
          batteryNeeded == other.batteryNeeded &&
          batteryGranted == other.batteryGranted;

  @override
  int get hashCode => Object.hash(
    step,
    activeSubstep,
    notificationsGranted,
    criticalAlertsGranted,
    errorMessage,
    canNavigate,
    alarm,
    liveActivityStarted,
    alarmSupported,
    isChecking,
    batteryNeeded,
    batteryGranted,
  );
}
