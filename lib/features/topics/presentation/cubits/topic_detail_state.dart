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
    this.status = TopicDetailStatus.initial,
    this.topicName = '',
    this.critical = false,
    this.severity = SeverityMode.none,
    this.faceState = FaceState.calm,
    this.word = 'All clear',
    this.subText = '',
    this.messages = const [],
    this.errorMessage,
    this.isUpdatingCritical = false,
    this.isMarkingAsRead = false,
  });

  final TopicDetailStatus status;
  final String topicName;

  /// Critical delivery / Ring through silent mode. MUST DEFAULT TO FALSE.
  final bool critical;
  final SeverityMode severity;
  final FaceState faceState;
  final String word;
  final String subText;
  final List<TopicDetailMessageItem> messages;
  final String? errorMessage;
  final bool isUpdatingCritical;
  final bool isMarkingAsRead;

  TopicDetailState copyWith({
    TopicDetailStatus? status,
    String? topicName,
    bool? critical,
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
      status: status ?? this.status,
      topicName: topicName ?? this.topicName,
      critical: critical ?? this.critical,
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
          status == other.status &&
          topicName == other.topicName &&
          critical == other.critical &&
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
    status,
    topicName,
    critical,
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
