import 'package:flutter/foundation.dart';

enum OnboardingConnectStatus {
  idle,
  connecting,
  connected,
  failure,
}

enum TestAlarmStatus {
  idle,
  ringing,
  success,
  failure,
}

@immutable
class OnboardingConnectState {
  const OnboardingConnectState({
    this.serverUrl = '',
    this.adminToken = '',
    this.requiresAdminToken = false,
    this.status = OnboardingConnectStatus.idle,
    this.testAlarmStatus = TestAlarmStatus.idle,
    this.serverUrlError,
    this.adminTokenError,
    this.errorMessage,
    this.qrNotice,
    this.incidentId,
    this.topic = '',
    this.canNavigateToHome = false,
  });

  final String serverUrl;
  final String adminToken;
  final bool requiresAdminToken;
  final OnboardingConnectStatus status;
  final TestAlarmStatus testAlarmStatus;
  final String? serverUrlError;
  final String? adminTokenError;
  final String? errorMessage;
  final String? qrNotice;
  final String? incidentId;
  final String topic;
  final bool canNavigateToHome;

  bool get isConnecting => status == OnboardingConnectStatus.connecting;
  bool get isConnected => status == OnboardingConnectStatus.connected;
  bool get isRinging => testAlarmStatus == TestAlarmStatus.ringing;
  bool get isAlarmSuccess => testAlarmStatus == TestAlarmStatus.success;
  bool get isAlarmFailure => testAlarmStatus == TestAlarmStatus.failure;

  OnboardingConnectState copyWith({
    String? serverUrl,
    String? adminToken,
    bool? requiresAdminToken,
    OnboardingConnectStatus? status,
    TestAlarmStatus? testAlarmStatus,
    String? serverUrlError,
    String? adminTokenError,
    String? errorMessage,
    String? qrNotice,
    String? incidentId,
    String? topic,
    bool? canNavigateToHome,
    bool clearServerUrlError = false,
    bool clearAdminTokenError = false,
    bool clearErrorMessage = false,
    bool clearQrNotice = false,
    bool clearIncidentId = false,
  }) {
    return OnboardingConnectState(
      serverUrl: serverUrl ?? this.serverUrl,
      adminToken: adminToken ?? this.adminToken,
      requiresAdminToken: requiresAdminToken ?? this.requiresAdminToken,
      status: status ?? this.status,
      testAlarmStatus: testAlarmStatus ?? this.testAlarmStatus,
      serverUrlError: clearServerUrlError
          ? null
          : (serverUrlError ?? this.serverUrlError),
      adminTokenError: clearAdminTokenError
          ? null
          : (adminTokenError ?? this.adminTokenError),
      errorMessage: clearErrorMessage
          ? null
          : (errorMessage ?? this.errorMessage),
      qrNotice: clearQrNotice ? null : (qrNotice ?? this.qrNotice),
      incidentId: clearIncidentId ? null : (incidentId ?? this.incidentId),
      topic: topic ?? this.topic,
      canNavigateToHome: canNavigateToHome ?? this.canNavigateToHome,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OnboardingConnectState &&
          runtimeType == other.runtimeType &&
          serverUrl == other.serverUrl &&
          adminToken == other.adminToken &&
          requiresAdminToken == other.requiresAdminToken &&
          status == other.status &&
          testAlarmStatus == other.testAlarmStatus &&
          serverUrlError == other.serverUrlError &&
          adminTokenError == other.adminTokenError &&
          errorMessage == other.errorMessage &&
          qrNotice == other.qrNotice &&
          incidentId == other.incidentId &&
          topic == other.topic &&
          canNavigateToHome == other.canNavigateToHome;

  @override
  int get hashCode => Object.hash(
    serverUrl,
    adminToken,
    requiresAdminToken,
    status,
    testAlarmStatus,
    serverUrlError,
    adminTokenError,
    errorMessage,
    qrNotice,
    incidentId,
    topic,
    canNavigateToHome,
  );
}
