import 'package:critalarm/design/components/chips.dart';
import 'package:flutter/foundation.dart';

/// Representation of a topic item and its priority level in Settings.
@immutable
class TopicPriorityItem {
  const TopicPriorityItem({
    required this.name,
    required this.priority,
  });

  final String name;
  final PriorityLevel priority;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TopicPriorityItem &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          priority == other.priority;

  @override
  int get hashCode => Object.hash(name, priority);
}

enum SettingsStatus { initial, loading, success, failure }

/// State for SettingsScreen.
@immutable
class SettingsState {
  const SettingsState({
    this.status = SettingsStatus.initial,
    this.quietHoursEnabled = true,
    this.criticalRingsQuietHours = true,
    this.escalationCallEnabled = false,
    this.serverUrl = 'api.critalarm.app',
    this.adminToken,
    this.isConnected = true,
    this.analyticsEnabled = false,
    this.crashReportingEnabled = false,
    this.isDisconnecting = false,
    this.isSavingConnection = false,
    this.topics = const [
      TopicPriorityItem(name: 'prod-db', priority: PriorityLevel.critical),
      TopicPriorityItem(name: 'nas-backup', priority: PriorityLevel.high),
      TopicPriorityItem(
        name: 'uptime-kuma',
        priority: PriorityLevel.defaultPriority,
      ),
      TopicPriorityItem(name: 'home-ha', priority: PriorityLevel.low),
    ],
    this.errorMessage,
  });

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
  final List<TopicPriorityItem> topics;
  final String? errorMessage;

  SettingsState copyWith({
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
    List<TopicPriorityItem>? topics,
    String? errorMessage,
    bool clearError = false,
  }) {
    return SettingsState(
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
      topics: topics ?? this.topics,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SettingsState &&
          runtimeType == other.runtimeType &&
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
          listEquals(topics, other.topics) &&
          errorMessage == other.errorMessage;

  @override
  int get hashCode => Object.hash(
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
    Object.hashAll(topics),
    errorMessage,
  );
}
