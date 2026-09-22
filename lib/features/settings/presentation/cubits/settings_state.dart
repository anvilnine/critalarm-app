import 'package:critalarm/core/alarm/quiet_hours.dart';
import 'package:critalarm/core/api/api_session.dart';
import 'package:critalarm/core/models/account_access.dart';
import 'package:critalarm/core/models/topic.dart';
import 'package:critalarm/features/settings/domain/entities/storage_settings.dart';
import 'package:flutter/foundation.dart';

enum SettingsStatus { initial, loading, success, failure }

/// State for SettingsScreen.
@immutable
class SettingsState {
  const SettingsState({
    this.access = const AccountAccess(null),
    this.topics = const [],
    this.status = SettingsStatus.initial,
    // Matches QuietHours.defaults, so nothing claims quiet hours is on before
    // the store has been read.
    this.quietHoursEnabled = false,
    this.quietHoursStartMinutes = QuietHours.defaultStartMinutes,
    this.quietHoursEndMinutes = QuietHours.defaultEndMinutes,
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
    this.storage = const StorageSettings(),
  });

  final List<Topic> topics;
  final AccountAccess access;
  String get criticalUsage => access.criticalUsage(topics);
  final SettingsStatus status;
  final bool quietHoursEnabled;

  /// Minutes from local midnight. 22:00 is 1320.
  final int quietHoursStartMinutes;

  /// Minutes from local midnight. 07:00 is 420.
  final int quietHoursEndMinutes;
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

  /// How long the phone keeps alarms, and whether P5 alarms are exempt.
  final StorageSettings storage;

  bool get hasAccounts =>
      serverMode != null && serverMode != ServerMode.selfhosted;

  /// The Storage section is drawn on a paid tier and on a self-hosted server,
  /// which has no tier at all. A free relay account does not see it.
  bool get hasStorageSection =>
      access.isPaid || serverMode == ServerMode.selfhosted;

  SettingsState copyWith({
    List<Topic>? topics,
    AccountAccess? access,
    SettingsStatus? status,
    bool? quietHoursEnabled,
    int? quietHoursStartMinutes,
    int? quietHoursEndMinutes,
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
    StorageSettings? storage,
    bool clearError = false,
  }) {
    return SettingsState(
      access: access ?? this.access,
      topics: topics ?? this.topics,
      status: status ?? this.status,
      quietHoursEnabled: quietHoursEnabled ?? this.quietHoursEnabled,
      quietHoursStartMinutes:
          quietHoursStartMinutes ?? this.quietHoursStartMinutes,
      quietHoursEndMinutes: quietHoursEndMinutes ?? this.quietHoursEndMinutes,
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
      storage: storage ?? this.storage,
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
          quietHoursStartMinutes == other.quietHoursStartMinutes &&
          quietHoursEndMinutes == other.quietHoursEndMinutes &&
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
    quietHoursStartMinutes,
    quietHoursEndMinutes,
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
