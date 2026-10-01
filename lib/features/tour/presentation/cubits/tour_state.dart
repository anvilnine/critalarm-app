import 'package:critalarm/features/tour/presentation/tour_steps.dart';
import 'package:flutter/foundation.dart';

enum TourStatus {
  /// Nothing on screen.
  idle,

  /// Someone asked for a guide. The host picks it up, works out which topic
  /// to show, and starts it.
  requested,

  /// A guide is on screen.
  running,

  /// Home is asking whether the user wants to be shown around. Nothing is
  /// highlighted yet. Counts as active, so setup asks keep waiting.
  offering,
}

@immutable
class TourState {
  const TourState({
    this.status = TourStatus.idle,
    this.guide,
    this.stepIndex = 0,
    this.topicName = '',
    this.usingExamples = false,
    this.fromMenu = false,
  });

  final TourStatus status;

  /// The guide asked for or playing. Null while idle, and also for the full
  /// replay from Settings, which plays every guide back to back. Home while
  /// the offer is up.
  final TourGuide? guide;

  final int stepIndex;

  /// The topic the topic steps open.
  final String topicName;

  /// True when the user has no topics yet, so the tour shows example ones
  /// rather than pointing at an empty list.
  final bool usingExamples;

  /// True when the user picked this guide from the Settings list. It starts
  /// from Settings, moves to its own screen, and ends back on Settings.
  final bool fromMenu;

  bool get isRunning => status == TourStatus.running;

  /// True from the moment a guide is asked for until it is gone. Sheets,
  /// asks and reminders wait for this to go false.
  bool get isActive => status != TourStatus.idle;

  /// True for the full replay, which moves between screens on its own. A
  /// single guide stays on the screen it was asked for on.
  bool get isFullReplay => isActive && guide == null;

  /// True when the tour opens each step's screen itself: the full replay and
  /// any guide picked from the Settings list. A first-visit guide stays on
  /// the screen it came up on.
  bool get moves => isActive && (guide == null || fromMenu);

  /// The steps being played.
  List<TourStep> get steps => tourStepsFor(guide);

  TourStep get step => steps[stepIndex];

  bool get isFirstStep => stepIndex == 0;
  bool get isLastStep => stepIndex == steps.length - 1;

  /// True while the Topics list should carry the example topics: during the
  /// home guide and the full replay, not while another screen's guide plays
  /// over it.
  bool get showsHomeExamples =>
      isRunning && (guide == null || guide == TourGuide.home);

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
      guide: guide,
      stepIndex: stepIndex ?? this.stepIndex,
      topicName: topicName ?? this.topicName,
      usingExamples: usingExamples ?? this.usingExamples,
      fromMenu: fromMenu,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TourState &&
          status == other.status &&
          guide == other.guide &&
          stepIndex == other.stepIndex &&
          topicName == other.topicName &&
          usingExamples == other.usingExamples &&
          fromMenu == other.fromMenu;

  @override
  int get hashCode =>
      Object.hash(status, guide, stepIndex, topicName, usingExamples, fromMenu);
}
