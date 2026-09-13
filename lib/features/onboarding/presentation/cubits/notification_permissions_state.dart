import 'package:critalarm/core/alarm/alarm_host.dart';
import 'package:flutter/foundation.dart';

/// Step in the notification permissions onboarding flow.
enum NotificationPermissionStep {
  /// Initial prompt before user clicks allow.
  initial,

  /// In the middle of requesting permissions from the OS.
  requesting,

  /// Permission was granted. Ready to proceed.
  granted,

  /// Permission was denied. Showing denial path with AppEmptyState
  /// and settings deep-link.
  denied,
}

@immutable
class NotificationPermissionsState {
  const NotificationPermissionsState({
    this.step = NotificationPermissionStep.initial,
    this.errorMessage,
    this.canNavigate = false,
    this.alarm = AlarmAuthorization.notDetermined,
    this.liveActivityStarted = false,
  });

  final NotificationPermissionStep step;
  final String? errorMessage;
  final bool canNavigate;

  /// Whether iOS lets the app set alarms. Without this a critical topic can
  /// only send a notification, so the toggle on the topic is turned off.
  final AlarmAuthorization alarm;

  /// True once onboarding has started its one local Live Activity, which is
  /// what puts the Allow prompt in front of the user before the relay ever
  /// tries a remote start.
  final bool liveActivityStarted;

  bool get isRequesting => step == NotificationPermissionStep.requesting;
  bool get isGranted => step == NotificationPermissionStep.granted;
  bool get isDenied => step == NotificationPermissionStep.denied;

  NotificationPermissionsState copyWith({
    NotificationPermissionStep? step,
    String? errorMessage,
    bool? canNavigate,
    AlarmAuthorization? alarm,
    bool? liveActivityStarted,
    bool clearError = false,
  }) {
    return NotificationPermissionsState(
      step: step ?? this.step,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      canNavigate: canNavigate ?? this.canNavigate,
      alarm: alarm ?? this.alarm,
      liveActivityStarted: liveActivityStarted ?? this.liveActivityStarted,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NotificationPermissionsState &&
          runtimeType == other.runtimeType &&
          step == other.step &&
          errorMessage == other.errorMessage &&
          canNavigate == other.canNavigate &&
          alarm == other.alarm &&
          liveActivityStarted == other.liveActivityStarted;

  @override
  int get hashCode => Object.hash(
    step,
    errorMessage,
    canNavigate,
    alarm,
    liveActivityStarted,
  );
}
