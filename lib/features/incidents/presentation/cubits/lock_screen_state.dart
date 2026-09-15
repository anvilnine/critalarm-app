import 'package:critalarm/design/faces/face_state.dart';
import 'package:flutter/foundation.dart';

enum LockScreenStatus { initial, loading, success, failure }

/// Single notification item on the lock screen.
@immutable
class LockNotificationItem {
  const LockNotificationItem({
    required this.topic,
    required this.title,
    required this.body,
    this.faceState = FaceState.calm,
    this.timeText,
    this.ringingPillText,
    this.isCrit = false,
    this.isQuiet = false,
    this.incidentId,
  });

  final String topic;
  final String title;
  final String body;
  final FaceState faceState;
  final String? timeText;
  final String? ringingPillText;
  final bool isCrit;
  final bool isQuiet;
  final String? incidentId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LockNotificationItem &&
          runtimeType == other.runtimeType &&
          topic == other.topic &&
          title == other.title &&
          body == other.body &&
          faceState == other.faceState &&
          timeText == other.timeText &&
          ringingPillText == other.ringingPillText &&
          isCrit == other.isCrit &&
          isQuiet == other.isQuiet &&
          incidentId == other.incidentId;

  @override
  int get hashCode => Object.hash(
    topic,
    title,
    body,
    faceState,
    timeText,
    ringingPillText,
    isCrit,
    isQuiet,
    incidentId,
  );
}

/// State for the LockScreen.
@immutable
class LockScreenState {
  const LockScreenState({
    this.status = LockScreenStatus.initial,
    this.dateText = '',
    this.timeText = '',
    this.notifications = const [],
    this.errorMessage,
  });

  final LockScreenStatus status;
  final String dateText;
  final String timeText;
  final List<LockNotificationItem> notifications;
  final String? errorMessage;

  LockScreenState copyWith({
    LockScreenStatus? status,
    String? dateText,
    String? timeText,
    List<LockNotificationItem>? notifications,
    String? errorMessage,
    bool clearError = false,
  }) {
    return LockScreenState(
      status: status ?? this.status,
      dateText: dateText ?? this.dateText,
      timeText: timeText ?? this.timeText,
      notifications: notifications ?? this.notifications,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LockScreenState &&
          runtimeType == other.runtimeType &&
          status == other.status &&
          dateText == other.dateText &&
          timeText == other.timeText &&
          listEquals(notifications, other.notifications) &&
          errorMessage == other.errorMessage;

  @override
  int get hashCode => Object.hash(
    status,
    dateText,
    timeText,
    Object.hashAll(notifications),
    errorMessage,
  );
}
