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
  });

  final NotificationPermissionStep step;
  final String? errorMessage;
  final bool canNavigate;

  bool get isRequesting => step == NotificationPermissionStep.requesting;
  bool get isGranted => step == NotificationPermissionStep.granted;
  bool get isDenied => step == NotificationPermissionStep.denied;

  NotificationPermissionsState copyWith({
    NotificationPermissionStep? step,
    String? errorMessage,
    bool? canNavigate,
    bool clearError = false,
  }) {
    return NotificationPermissionsState(
      step: step ?? this.step,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      canNavigate: canNavigate ?? this.canNavigate,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NotificationPermissionsState &&
          runtimeType == other.runtimeType &&
          step == other.step &&
          errorMessage == other.errorMessage &&
          canNavigate == other.canNavigate;

  @override
  int get hashCode => Object.hash(step, errorMessage, canNavigate);
}
