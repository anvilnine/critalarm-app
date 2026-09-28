import 'package:critalarm/features/feature_guides/presentation/feature_guide_steps.dart';
import 'package:flutter/foundation.dart';

enum FeatureGuideStatus {
  /// Nothing on screen.
  idle,

  /// Someone asked for a guide. The host picks it up, works out which topic
  /// to show, and starts it.
  requested,

  /// A guide is on screen.
  running,
}

@immutable
class FeatureGuideState {
  const FeatureGuideState({
    this.status = FeatureGuideStatus.idle,
    this.guide,
    this.stepIndex = 0,
    this.topicName = '',
    this.usingExamples = false,
  });

  final FeatureGuideStatus status;

  /// The guide asked for or playing. Null while idle, and also for the full
  /// replay from Settings, which plays every guide back to back.
  final FeatureGuide? guide;

  final int stepIndex;

  /// The topic the topic steps open.
  final String topicName;

  /// True when the user has no topics yet, so the guide shows example ones
  /// rather than pointing at an empty list.
  final bool usingExamples;

  bool get isRunning => status == FeatureGuideStatus.running;

  /// True from the moment a guide is asked for until it is gone. Sheets,
  /// asks and reminders wait for this to go false.
  bool get isActive => status != FeatureGuideStatus.idle;

  /// True for the full replay, which moves between screens on its own. A
  /// single guide stays on the screen it was asked for on.
  bool get isFullReplay => isActive && guide == null;

  /// The steps being played.
  List<FeatureGuideStep> get steps => featureGuideStepsFor(guide);

  FeatureGuideStep get step => steps[stepIndex];

  bool get isFirstStep => stepIndex == 0;
  bool get isLastStep => stepIndex == steps.length - 1;

  /// True while the Topics list should carry the example topics: during the
  /// home guide and the full replay, not while another screen's guide plays
  /// over it.
  bool get showsHomeExamples =>
      isRunning && (guide == null || guide == FeatureGuide.home);

  /// True when [name] is the example topic the guide made up, so the topic
  /// screen draws it from the example rather than asking the server for it.
  bool showsExampleTopic(String name) =>
      isRunning && usingExamples && name == topicName;

  FeatureGuideState copyWith({
    FeatureGuideStatus? status,
    int? stepIndex,
    String? topicName,
    bool? usingExamples,
  }) {
    return FeatureGuideState(
      status: status ?? this.status,
      guide: guide,
      stepIndex: stepIndex ?? this.stepIndex,
      topicName: topicName ?? this.topicName,
      usingExamples: usingExamples ?? this.usingExamples,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FeatureGuideState &&
          status == other.status &&
          guide == other.guide &&
          stepIndex == other.stepIndex &&
          topicName == other.topicName &&
          usingExamples == other.usingExamples;

  @override
  int get hashCode =>
      Object.hash(status, guide, stepIndex, topicName, usingExamples);
}
