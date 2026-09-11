import 'package:critalarm/design/components/chips.dart';
import 'package:critalarm/design/faces/face_state.dart';
import 'package:flutter/foundation.dart';

enum TopicsListStatus { initial, loading, success, failure }

/// View model for each topic row on TopicsListScreen.
@immutable
class TopicsListItem {
  const TopicsListItem({
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
      other is TopicsListItem &&
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

@immutable
class TopicsListState {
  const TopicsListState({
    this.status = TopicsListStatus.initial,
    this.topics = const [],
    this.errorMessage,
  });

  final TopicsListStatus status;
  final List<TopicsListItem> topics;
  final String? errorMessage;

  bool get isEmpty => topics.isEmpty && status == TopicsListStatus.success;

  TopicsListState copyWith({
    TopicsListStatus? status,
    List<TopicsListItem>? topics,
    String? errorMessage,
    bool clearError = false,
  }) {
    return TopicsListState(
      status: status ?? this.status,
      topics: topics ?? this.topics,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TopicsListState &&
          runtimeType == other.runtimeType &&
          status == other.status &&
          listEquals(topics, other.topics) &&
          errorMessage == other.errorMessage;

  @override
  int get hashCode => Object.hash(
        status,
        Object.hashAll(topics),
        errorMessage,
      );
}
