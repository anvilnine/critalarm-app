import 'package:critalarm/core/alarm/alarm_host.dart';
import 'package:critalarm/core/failures/cap_reached.dart';
import 'package:critalarm/design/faces/face_state.dart';
import 'package:critalarm/design/tokens/colors.dart';
import 'package:flutter/foundation.dart';

enum TopicDetailStatus { initial, loading, success, failure }

/// View model for a message card in TopicDetailScreen.
@immutable
class TopicDetailMessageItem {
  const TopicDetailMessageItem({
    required this.title,
    required this.timestamp,
    required this.body,
    required this.source,
    this.isHigh = false,
  });

  final String title;
  final String timestamp;
  final String body;
  final String source;
  final bool isHigh;

  TopicDetailMessageItem copyWith({
    String? title,
    String? timestamp,
    String? body,
    String? source,
    bool? isHigh,
  }) {
    return TopicDetailMessageItem(
      title: title ?? this.title,
      timestamp: timestamp ?? this.timestamp,
      body: body ?? this.body,
      source: source ?? this.source,
      isHigh: isHigh ?? this.isHigh,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TopicDetailMessageItem &&
          runtimeType == other.runtimeType &&
          title == other.title &&
          timestamp == other.timestamp &&
          body == other.body &&
          source == other.source &&
          isHigh == other.isHigh;

  @override
  int get hashCode => Object.hash(
    title,
    timestamp,
    body,
    source,
    isHigh,
  );
}

/// State for the TopicDetailScreen.
/// Commitment made to Apple: [critical] defaults to `false`.
@immutable
class TopicDetailState {
  const TopicDetailState({
    this.capReached,
    this.status = TopicDetailStatus.initial,
    this.topicName = '',
    this.critical = false,
    this.alarm = AlarmAuthorization.notDetermined,
    this.severity = SeverityMode.none,
    this.faceState = FaceState.calm,
    this.word = '',
    this.subText = '',
    this.messages = const [],
    this.errorMessage,
    this.isUpdatingCritical = false,
    this.isMarkingAsRead = false,
  });

  /// Set when the server refused with a 429 naming a cap (api.md §4.2), so the
  /// screen can say which limit was hit instead of failing generically.
  final CapReached? capReached;

  final TopicDetailStatus status;
  final String topicName;

  /// Critical delivery / Ring through silent mode. MUST DEFAULT TO FALSE.
  final bool critical;

  /// Whether iOS lets the app set alarms. Critical delivery needs one, so the
  /// toggle is turned off and explained when this is denied.
  final AlarmAuthorization alarm;

  /// api.md §3.1 keeps `critical` off by default, and it can only be switched
  /// on where an alarm can actually ring.
  bool get canEditCritical =>
      alarm == AlarmAuthorization.authorized ||
      alarm == AlarmAuthorization.unsupported;
  final SeverityMode severity;
  final FaceState faceState;
  final String word;
  final String subText;
  final List<TopicDetailMessageItem> messages;
  final String? errorMessage;
  final bool isUpdatingCritical;
  final bool isMarkingAsRead;

  TopicDetailState copyWith({
    CapReached? capReached,
    TopicDetailStatus? status,
    String? topicName,
    bool? critical,
    AlarmAuthorization? alarm,
    SeverityMode? severity,
    FaceState? faceState,
    String? word,
    String? subText,
    List<TopicDetailMessageItem>? messages,
    String? errorMessage,
    bool? isUpdatingCritical,
    bool? isMarkingAsRead,
    bool clearError = false,
  }) {
    return TopicDetailState(
      capReached: clearError ? null : (capReached ?? this.capReached),
      status: status ?? this.status,
      topicName: topicName ?? this.topicName,
      critical: critical ?? this.critical,
      alarm: alarm ?? this.alarm,
      severity: severity ?? this.severity,
      faceState: faceState ?? this.faceState,
      word: word ?? this.word,
      subText: subText ?? this.subText,
      messages: messages ?? this.messages,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      isUpdatingCritical: isUpdatingCritical ?? this.isUpdatingCritical,
      isMarkingAsRead: isMarkingAsRead ?? this.isMarkingAsRead,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TopicDetailState &&
          runtimeType == other.runtimeType &&
          capReached == other.capReached &&
          status == other.status &&
          topicName == other.topicName &&
          critical == other.critical &&
          alarm == other.alarm &&
          severity == other.severity &&
          faceState == other.faceState &&
          word == other.word &&
          subText == other.subText &&
          listEquals(messages, other.messages) &&
          errorMessage == other.errorMessage &&
          isUpdatingCritical == other.isUpdatingCritical &&
          isMarkingAsRead == other.isMarkingAsRead;

  @override
  int get hashCode => Object.hash(
    capReached,
    status,
    topicName,
    critical,
    alarm,
    severity,
    faceState,
    word,
    subText,
    Object.hashAll(messages),
    errorMessage,
    isUpdatingCritical,
    isMarkingAsRead,
  );
}
