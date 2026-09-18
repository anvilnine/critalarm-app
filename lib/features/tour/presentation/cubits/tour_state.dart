import 'package:critalarm/features/tour/presentation/tour_steps.dart';
import 'package:flutter/foundation.dart';

enum TourStatus {
  /// Nothing on screen.
  idle,

  /// Someone asked for the tour. The host picks it up, works out which topic
  /// to show, and starts it.
  requested,

  /// The tour is on screen.
  running,
}

@immutable
class TourState {
  const TourState({
    this.status = TourStatus.idle,
    this.stepIndex = 0,
    this.topicName = '',
    this.usingExamples = false,
  });

  final TourStatus status;
  final int stepIndex;

  /// The topic the topic steps open.
  final String topicName;

  /// True when the user has no topics yet, so the tour shows example ones
  /// rather than pointing at an empty list.
  final bool usingExamples;

  bool get isRunning => status == TourStatus.running;

  TourStep get step => tourSteps[stepIndex];

  bool get isFirstStep => stepIndex == 0;
  bool get isLastStep => stepIndex == tourSteps.length - 1;

  /// True when [name] is the example topic the tour made up, so the topic
  /// screen draws it from the example rather than asking the server for it.
  bool showsExampleTopic(String name) =>
      isRunning && usingExamples && name == topicName;

  TourState copyWith({
    TourStatus? status,
    int? stepIndex,
    String? topicName,
    bool? usingExamples,
  }) {
    return TourState(
      status: status ?? this.status,
      stepIndex: stepIndex ?? this.stepIndex,
      topicName: topicName ?? this.topicName,
      usingExamples: usingExamples ?? this.usingExamples,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TourState &&
          status == other.status &&
          stepIndex == other.stepIndex &&
          topicName == other.topicName &&
          usingExamples == other.usingExamples;

  @override
  int get hashCode => Object.hash(status, stepIndex, topicName, usingExamples);
}
