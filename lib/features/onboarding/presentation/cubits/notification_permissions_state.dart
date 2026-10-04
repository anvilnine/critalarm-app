import 'package:critalarm/core/alarm/alarm_host.dart';
import 'package:critalarm/features/permissions/domain/entities/permission_setup_step.dart';
import 'package:flutter/foundation.dart';

/// Where the permissions screen is in asking.
enum NotificationPermissionStep {
  /// A step is on screen, waiting for the user.
  initial,

  /// In the middle of requesting a permission from the OS.
  requesting,

  /// Nothing left to ask. Ready to proceed.
  granted,

  /// Permission was denied. Showing denial path with recovery action.
  denied,
}

@immutable
class NotificationPermissionsState {
  const NotificationPermissionsState({
    this.step = NotificationPermissionStep.initial,
    this.steps = const [],
    this.current,
    this.granted = const {},
    this.errorMessage,
    this.canNavigate = false,
    this.alarm = AlarmAuthorization.notDetermined,
    this.liveActivityStarted = false,
    this.isChecking = false,
  });

  final NotificationPermissionStep step;

  /// The steps this run of the screen draws on this phone, in order. A step
  /// that was already granted when the screen read it is not in here.
  final List<PermissionSetupStep> steps;

  /// The step on screen. Null until the statuses have been read: the screen
  /// shows no prompt before it knows which one the user still needs.
  final PermissionSetupStep? current;

  /// The steps whose permission was granted at the last read.
  final Set<PermissionSetupStep> granted;

  final String? errorMessage;
  final bool canNavigate;

  /// What AlarmKit said at the last read.
  final AlarmAuthorization alarm;

  /// True once onboarding has started its one local Live Activity.
  final bool liveActivityStarted;

  /// Re-reading the system state after the user came back from Settings.
  final bool isChecking;

  bool get isRequesting => step == NotificationPermissionStep.requesting;
  bool get isGranted => step == NotificationPermissionStep.granted;
  bool get isDenied => step == NotificationPermissionStep.denied;

  /// Where [current] sits in [steps], from zero. -1 with no step on screen.
  int get currentIndex {
    final on = current;
    return on == null ? -1 : steps.indexOf(on);
  }

  /// The steps this run has been on, [current] included. The screen only
  /// moves forward, so that is everything up to [current].
  Set<PermissionSetupStep> get shown => steps.take(currentIndex + 1).toSet();

  NotificationPermissionsState copyWith({
    NotificationPermissionStep? step,
    List<PermissionSetupStep>? steps,
    PermissionSetupStep? current,
    Set<PermissionSetupStep>? granted,
    String? errorMessage,
    bool? canNavigate,
    AlarmAuthorization? alarm,
    bool? liveActivityStarted,
    bool? isChecking,
    bool clearError = false,
  }) {
    return NotificationPermissionsState(
      step: step ?? this.step,
      steps: steps ?? this.steps,
      current: current ?? this.current,
      granted: granted ?? this.granted,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      canNavigate: canNavigate ?? this.canNavigate,
      alarm: alarm ?? this.alarm,
      liveActivityStarted: liveActivityStarted ?? this.liveActivityStarted,
      isChecking: isChecking ?? this.isChecking,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NotificationPermissionsState &&
          runtimeType == other.runtimeType &&
          step == other.step &&
          listEquals(steps, other.steps) &&
          current == other.current &&
          setEquals(granted, other.granted) &&
          errorMessage == other.errorMessage &&
          canNavigate == other.canNavigate &&
          alarm == other.alarm &&
          liveActivityStarted == other.liveActivityStarted &&
          isChecking == other.isChecking;

  @override
  int get hashCode => Object.hash(
    step,
    Object.hashAll(steps),
    current,
    Object.hashAllUnordered(granted),
    errorMessage,
    canNavigate,
    alarm,
    liveActivityStarted,
    isChecking,
  );

  @override
  String toString() =>
      'NotificationPermissionsState($step, current: $current, steps: $steps, '
      'granted: $granted, alarm: $alarm, canNavigate: $canNavigate, '
      'isChecking: $isChecking)';
}
