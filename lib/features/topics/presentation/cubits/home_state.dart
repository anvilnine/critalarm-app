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
    this.isLive = false,
    this.ringsThroughSilent = false,
  });

  final String name;
  final String meta;
  final PriorityLevel priority;
  final FaceState faceState;
  final bool isCrit;
  final bool isQuiet;

  /// True while this topic has something the user still has to deal with: an
  /// open incident or a live warning. The row shows the priority that came in
  /// only while this holds. Once it clears, the row goes back to saying how
  /// the topic is set up, so a red chip never outlives the alarm.
  final bool isLive;

  /// True when critical delivery is on for this topic, so a page rings
  /// through the silent switch.
  final bool ringsThroughSilent;

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
          isQuiet == other.isQuiet &&
          isLive == other.isLive &&
          ringsThroughSilent == other.ringsThroughSilent;

  @override
  int get hashCode => Object.hash(
    name,
    meta,
    priority,
    faceState,
    isCrit,
    isQuiet,
    isLive,
    ringsThroughSilent,
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
