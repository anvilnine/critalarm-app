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
  final List<TopicPriorityItem> topics;
  final String? errorMessage;

  SettingsState copyWith({
    SettingsStatus? status,
    bool? quietHoursEnabled,
    bool? criticalRingsQuietHours,
    bool? escalationCallEnabled,
    String? serverUrl,
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
          listEquals(topics, other.topics) &&
          errorMessage == other.errorMessage;

  @override
  int get hashCode => Object.hash(
    status,
    quietHoursEnabled,
    criticalRingsQuietHours,
    escalationCallEnabled,
    serverUrl,
    Object.hashAll(topics),
    errorMessage,
  );
}
