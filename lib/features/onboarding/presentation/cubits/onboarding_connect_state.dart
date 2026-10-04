import 'package:critalarm/core/alarm/alarm_host.dart';
import 'package:critalarm/features/onboarding/domain/connect/connect_privacy_line.dart';
import 'package:critalarm/features/onboarding/presentation/model/local_test_alarm.dart';
import 'package:flutter/foundation.dart';

export 'package:critalarm/features/onboarding/presentation/model/local_test_alarm.dart'
    show TestAlarmStatus;

enum OnboardingConnectStatus {
  idle,
  connecting,
  connected,
  failure,
}

/// What the connect step shows once the user's own server has answered: the
/// host that answered and the privacy line its answer supports.
@immutable
class ConnectConfirmation {
  const ConnectConfirmation({required this.host, this.privacyLine});

  final String host;

  /// Null when the server's answer has no sentence this version knows.
  final ConnectPrivacyLine? privacyLine;

  @override
  bool operator ==(Object other) =>
      other is ConnectConfirmation &&
      host == other.host &&
      privacyLine == other.privacyLine;

  @override
  int get hashCode => Object.hash(host, privacyLine);
}

@immutable
class OnboardingConnectState {
  const OnboardingConnectState({
    this.serverUrl = '',
    this.adminToken = '',
    this.requiresAdminToken = false,
    this.isSelfHosting = false,
    this.status = OnboardingConnectStatus.idle,
    this.testAlarmStatus = TestAlarmStatus.idle,
    this.countdownSeconds = 5,
    this.isCountingDown = false,
    this.canLaunchDemoAlarm = false,
    this.alarm = AlarmAuthorization.notDetermined,
    this.serverUrlError,
    this.adminTokenError,
    this.errorMessage,
    this.qrNotice,
    this.incidentId,
    this.topic = '',
    this.canNavigateToHome = false,
    this.cloudOnline,
    this.cloudPrivacyLine,
    this.confirmation,
    this.cloudWaitLine,
  });

  final String serverUrl;
  final String adminToken;
  final bool requiresAdminToken;
  final bool isSelfHosting;
  final OnboardingConnectStatus status;
  final TestAlarmStatus testAlarmStatus;
  final int countdownSeconds;
  final bool isCountingDown;
  final bool canLaunchDemoAlarm;

  /// Whether this phone can set an AlarmKit alarm. The test-alarm copy reads
  /// it so an iPhone older than iOS 26 is not told to try silent mode.
  final AlarmAuthorization alarm;
  final String? serverUrlError;
  final String? adminTokenError;
  final String? errorMessage;
  final String? qrNotice;
  final String? incidentId;
  final String topic;
  final bool canNavigateToHome;

  /// Whether Crit Alarm Cloud could be reached. Null until the first check
  /// answers. It never blocks anything: it only decides whether the offline
  /// card shows.
  final bool? cloudOnline;

  /// The privacy line for Crit Alarm Cloud. Null until its `/v1/info` has
  /// answered, so nothing is claimed before the server said it.
  final ConnectPrivacyLine? cloudPrivacyLine;

  /// Set when the user's own server has just answered. The screen shows it
  /// and waits for Continue.
  final ConnectConfirmation? confirmation;

  /// What the Cloud connect is doing, while the screen waits on it. Only
  /// set when the screen was opened on its own after setup, where it stays
  /// up until the connect lands.
  final String? cloudWaitLine;

  bool get isConnecting => status == OnboardingConnectStatus.connecting;
  bool get isConnected => status == OnboardingConnectStatus.connected;
  bool get isRinging => testAlarmStatus == TestAlarmStatus.ringing;
  bool get isAlarmSuccess => testAlarmStatus == TestAlarmStatus.success;
  bool get isAlarmFailure => testAlarmStatus == TestAlarmStatus.failure;

  OnboardingConnectState copyWith({
    String? serverUrl,
    String? adminToken,
    bool? requiresAdminToken,
    bool? isSelfHosting,
    OnboardingConnectStatus? status,
    TestAlarmStatus? testAlarmStatus,
    int? countdownSeconds,
    bool? isCountingDown,
    bool? canLaunchDemoAlarm,
    AlarmAuthorization? alarm,
    String? serverUrlError,
    String? adminTokenError,
    String? errorMessage,
    String? qrNotice,
    String? incidentId,
    String? topic,
    bool? canNavigateToHome,
    bool? cloudOnline,
    ConnectPrivacyLine? cloudPrivacyLine,
    ConnectConfirmation? confirmation,
    String? cloudWaitLine,
    bool clearCloudWaitLine = false,
    bool clearCloudPrivacyLine = false,
    bool clearConfirmation = false,
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
      isSelfHosting: isSelfHosting ?? this.isSelfHosting,
      status: status ?? this.status,
      testAlarmStatus: testAlarmStatus ?? this.testAlarmStatus,
      countdownSeconds: countdownSeconds ?? this.countdownSeconds,
      isCountingDown: isCountingDown ?? this.isCountingDown,
      canLaunchDemoAlarm: canLaunchDemoAlarm ?? this.canLaunchDemoAlarm,
      alarm: alarm ?? this.alarm,
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
      cloudOnline: cloudOnline ?? this.cloudOnline,
      cloudPrivacyLine: clearCloudPrivacyLine
          ? null
          : (cloudPrivacyLine ?? this.cloudPrivacyLine),
      confirmation: clearConfirmation
          ? null
          : (confirmation ?? this.confirmation),
      cloudWaitLine: clearCloudWaitLine
          ? null
          : (cloudWaitLine ?? this.cloudWaitLine),
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
          isSelfHosting == other.isSelfHosting &&
          status == other.status &&
          testAlarmStatus == other.testAlarmStatus &&
          countdownSeconds == other.countdownSeconds &&
          isCountingDown == other.isCountingDown &&
          canLaunchDemoAlarm == other.canLaunchDemoAlarm &&
          alarm == other.alarm &&
          serverUrlError == other.serverUrlError &&
          adminTokenError == other.adminTokenError &&
          errorMessage == other.errorMessage &&
          qrNotice == other.qrNotice &&
          incidentId == other.incidentId &&
          topic == other.topic &&
          canNavigateToHome == other.canNavigateToHome &&
          cloudOnline == other.cloudOnline &&
          cloudPrivacyLine == other.cloudPrivacyLine &&
          confirmation == other.confirmation &&
          cloudWaitLine == other.cloudWaitLine;

  @override
  int get hashCode => Object.hashAll([
    serverUrl,
    adminToken,
    requiresAdminToken,
    isSelfHosting,
    status,
    testAlarmStatus,
    countdownSeconds,
    isCountingDown,
    canLaunchDemoAlarm,
    alarm,
    serverUrlError,
    adminTokenError,
    errorMessage,
    qrNotice,
    incidentId,
    topic,
    canNavigateToHome,
    cloudOnline,
    cloudPrivacyLine,
    confirmation,
    cloudWaitLine,
  ]);
}
