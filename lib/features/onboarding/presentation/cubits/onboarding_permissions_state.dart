import 'package:flutter/foundation.dart';

enum OnboardingPermissionsStatus {
  initial,
  ringing,
  success,
  failure,
}

@immutable
class OnboardingPermissionsState {
  const OnboardingPermissionsState({
    this.status = OnboardingPermissionsStatus.initial,
    this.incidentId,
    this.errorMessage,
    this.topic = 'prod-db',
  });

  final OnboardingPermissionsStatus status;
  final String? incidentId;
  final String? errorMessage;
  final String topic;

  bool get isRinging => status == OnboardingPermissionsStatus.ringing;
  bool get isSuccess => status == OnboardingPermissionsStatus.success;
  bool get isFailure => status == OnboardingPermissionsStatus.failure;

  OnboardingPermissionsState copyWith({
    OnboardingPermissionsStatus? status,
    String? incidentId,
    String? errorMessage,
    String? topic,
    bool clearIncidentId = false,
    bool clearError = false,
  }) {
    return OnboardingPermissionsState(
      status: status ?? this.status,
      incidentId: clearIncidentId ? null : (incidentId ?? this.incidentId),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      topic: topic ?? this.topic,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OnboardingPermissionsState &&
          runtimeType == other.runtimeType &&
          status == other.status &&
          incidentId == other.incidentId &&
          errorMessage == other.errorMessage &&
          topic == other.topic;

  @override
  int get hashCode => Object.hash(
    status,
    incidentId,
    errorMessage,
    topic,
  );
}
