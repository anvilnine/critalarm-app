import 'package:critalarm/core/api/api_session.dart';
import 'package:critalarm/core/models/account_access.dart';
import 'package:critalarm/core/models/topic.dart';
import 'package:flutter/foundation.dart';

enum SettingsStatus { initial, loading, success, failure }

/// State for SettingsScreen.
@immutable
class SettingsState {
  const SettingsState({
    this.access = const AccountAccess(null),
    this.topics = const [],
    this.status = SettingsStatus.initial,
    this.quietHoursEnabled = true,
    this.criticalRingsQuietHours = true,
    this.escalationCallEnabled = false,
    this.serverUrl = '',
    this.adminToken,
    this.isConnected = false,
    this.analyticsEnabled = false,
    this.crashReportingEnabled = false,
    this.isDisconnecting = false,
    this.isSavingConnection = false,
    this.errorMessage,
    this.serverMode,
  });

  final List<Topic> topics;
  final AccountAccess access;
  String get criticalUsage => access.criticalUsage(topics);
  final SettingsStatus status;
  final bool quietHoursEnabled;
  final bool criticalRingsQuietHours;
  final bool escalationCallEnabled;
  final String serverUrl;
  final String? adminToken;
  final bool isConnected;
  final bool analyticsEnabled;
  final bool crashReportingEnabled;
  final bool isDisconnecting;
  final bool isSavingConnection;
  final String? errorMessage;

  /// Which mode the server runs in, or null before it has been read. A
  /// self-hosted server has no accounts, so the Account row is left out.
  final ServerMode? serverMode;

  bool get hasAccounts =>
      serverMode != null && serverMode != ServerMode.selfhosted;

  SettingsState copyWith({
    List<Topic>? topics,
    AccountAccess? access,
    SettingsStatus? status,
    bool? quietHoursEnabled,
    bool? criticalRingsQuietHours,
    bool? escalationCallEnabled,
    String? serverUrl,
    String? adminToken,
    bool? isConnected,
    bool? analyticsEnabled,
    bool? crashReportingEnabled,
    bool? isDisconnecting,
    bool? isSavingConnection,
    String? errorMessage,
    ServerMode? serverMode,
    bool clearError = false,
  }) {
    return SettingsState(
      access: access ?? this.access,
      topics: topics ?? this.topics,
      status: status ?? this.status,
      quietHoursEnabled: quietHoursEnabled ?? this.quietHoursEnabled,
      criticalRingsQuietHours:
          criticalRingsQuietHours ?? this.criticalRingsQuietHours,
      escalationCallEnabled:
          escalationCallEnabled ?? this.escalationCallEnabled,
      serverUrl: serverUrl ?? this.serverUrl,
      adminToken: adminToken ?? this.adminToken,
      isConnected: isConnected ?? this.isConnected,
      analyticsEnabled: analyticsEnabled ?? this.analyticsEnabled,
      crashReportingEnabled:
          crashReportingEnabled ?? this.crashReportingEnabled,
      isDisconnecting: isDisconnecting ?? this.isDisconnecting,
      isSavingConnection: isSavingConnection ?? this.isSavingConnection,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      serverMode: serverMode ?? this.serverMode,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SettingsState &&
          runtimeType == other.runtimeType &&
          access == other.access &&
          topics == other.topics &&
          status == other.status &&
          quietHoursEnabled == other.quietHoursEnabled &&
          criticalRingsQuietHours == other.criticalRingsQuietHours &&
          escalationCallEnabled == other.escalationCallEnabled &&
          serverUrl == other.serverUrl &&
          adminToken == other.adminToken &&
          isConnected == other.isConnected &&
          analyticsEnabled == other.analyticsEnabled &&
          crashReportingEnabled == other.crashReportingEnabled &&
          isDisconnecting == other.isDisconnecting &&
          isSavingConnection == other.isSavingConnection &&
          errorMessage == other.errorMessage &&
          serverMode == other.serverMode;

  @override
  int get hashCode => Object.hash(
    access,
    topics,
    status,
    quietHoursEnabled,
    criticalRingsQuietHours,
    escalationCallEnabled,
    serverUrl,
    adminToken,
    isConnected,
    analyticsEnabled,
    crashReportingEnabled,
    isDisconnecting,
    isSavingConnection,
    errorMessage,
    serverMode,
  );
}
