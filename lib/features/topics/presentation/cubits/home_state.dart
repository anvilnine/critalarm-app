import 'package:critalarm/design/components/chips.dart';
import 'package:critalarm/design/faces/face_state.dart';
import 'package:critalarm/design/tokens/colors.dart';
import 'package:flutter/foundation.dart';

enum HomeStatus { initial, loading, success, failure }

/// View model for a topic row in the Home screen sheet.
@immutable
class HomeTopicItem {
  const HomeTopicItem({
    required this.name,
    required this.meta,
    required this.priority,
    this.faceState = FaceState.calm,
    this.isCrit = false,
    this.isQuiet = false,
  });

  final String name;
  final String meta;
  final PriorityLevel priority;
  final FaceState faceState;
  final bool isCrit;
  final bool isQuiet;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HomeTopicItem &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          meta == other.meta &&
          priority == other.priority &&
          faceState == other.faceState &&
          isCrit == other.isCrit &&
          isQuiet == other.isQuiet;

  @override
  int get hashCode => Object.hash(
    name,
    meta,
    priority,
    faceState,
    isCrit,
    isQuiet,
  );
}

/// State for the Home screen.
@immutable
class HomeState {
  const HomeState({
    this.status = HomeStatus.initial,
    this.topicItems = const [],
    this.faceState = FaceState.calm,
    this.word = '',
    this.subText = '',
    this.severity = SeverityMode.none,
    this.ringingIncidentId,
    this.errorMessage,
  });

  final HomeStatus status;
  final List<HomeTopicItem> topicItems;
  final FaceState faceState;
  final String word;
  final String subText;
  final SeverityMode severity;

  /// The open incident that is ringing right now, if there is one. The app is
  /// the alarm while this is set: the list hands the user to the takeover
  /// screen instead of making them hunt for a way to stop it.
  final String? ringingIncidentId;
  final String? errorMessage;

  bool get isEmpty => topicItems.isEmpty && status == HomeStatus.success;

  HomeState copyWith({
    HomeStatus? status,
    List<HomeTopicItem>? topicItems,
    FaceState? faceState,
    String? word,
    String? subText,
    SeverityMode? severity,
    String? ringingIncidentId,
    bool clearRinging = false,
    String? errorMessage,
    bool clearError = false,
  }) {
    return HomeState(
      status: status ?? this.status,
      topicItems: topicItems ?? this.topicItems,
      faceState: faceState ?? this.faceState,
      word: word ?? this.word,
      subText: subText ?? this.subText,
      severity: severity ?? this.severity,
      ringingIncidentId: clearRinging
          ? null
          : (ringingIncidentId ?? this.ringingIncidentId),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HomeState &&
          runtimeType == other.runtimeType &&
          status == other.status &&
          listEquals(topicItems, other.topicItems) &&
          faceState == other.faceState &&
          word == other.word &&
          subText == other.subText &&
          severity == other.severity &&
          ringingIncidentId == other.ringingIncidentId &&
          errorMessage == other.errorMessage;

  @override
  int get hashCode => Object.hash(
    status,
    Object.hashAll(topicItems),
    faceState,
    word,
    subText,
    severity,
    ringingIncidentId,
    errorMessage,
  );
}
