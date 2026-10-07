import 'package:critalarm/features/onboarding/domain/flow/onboarding_flow.dart';
import 'package:flutter/foundation.dart';

/// The three parts of setup the tracker counts, in order.
enum OnboardingChapter {
  /// What the app is: the welcome and how it rings.
  meet,

  /// Getting the phone ready: the server, the permissions, the first topic.
  setUp,

  /// The first real alarm.
  hearIt,
}

/// The chapter each step belongs to. A step that is not listed here has no
/// chapter and sits outside the tracker: `hook_up`, `widgets`, the legacy
/// test, and any step added later that the tracker should not count.
const Map<String, OnboardingChapter> _chapterByStep = {
  OnboardingStepId.welcome: OnboardingChapter.meet,
  OnboardingStepId.howItRings: OnboardingChapter.meet,
  OnboardingStepId.connect: OnboardingChapter.setUp,
  OnboardingStepId.permissions: OnboardingChapter.setUp,
  OnboardingStepId.firstTopic: OnboardingChapter.setUp,
  OnboardingStepId.realRing: OnboardingChapter.hearIt,
};

/// The chapter [stepId] belongs to, or null for a step outside the tracker.
OnboardingChapter? onboardingChapterOf(String stepId) => _chapterByStep[stepId];

/// What the tracker shows: how full each of its three bars is.
@immutable
class OnboardingTrackerFill {
  const OnboardingTrackerFill({required this.bars, required this.chapter});

  /// Every bar full.
  const OnboardingTrackerFill.allDone()
    : bars = const [1, 1, 1],
      chapter = null;

  /// One value per chapter, in order, from 0 (empty) to 1 (full).
  final List<double> bars;

  /// The chapter the user is in. Null once every chapter is behind them.
  final OnboardingChapter? chapter;

  /// True when every bar is full.
  bool get isAllDone => bars.every((bar) => bar >= 1);

  /// The fill as one number from 0 to 3: the bars added up. The tracker
  /// animates this one value, so the bars fill one after the other.
  double get position => bars.fold(0, (sum, bar) => sum + bar);

  @override
  bool operator ==(Object other) =>
      other is OnboardingTrackerFill &&
      chapter == other.chapter &&
      listEquals(bars, other.bars);

  @override
  int get hashCode => Object.hash(chapter, Object.hashAll(bars));

  @override
  String toString() => 'OnboardingTrackerFill($bars, $chapter)';
}

/// The tracker for a user on [currentStep] of the flow [flowSteps].
///
/// Bars before the current chapter are full and bars after it are empty.
/// The current bar is the share of its chapter that is behind the user: the
/// chapter's steps listed before [currentStep], over all of the chapter's
/// steps in the flow. A step the run passed over (already granted, already
/// owned, not on this phone) is behind the user like one they finished, so
/// it counts the same. A step the flow does not list is not counted at all.
///
/// A step with no chapter shows what the next step with a chapter would,
/// and every bar full when no such step is left. That is the end of the
/// flow, where `hook_up` sits.
OnboardingTrackerFill onboardingTrackerFillFor({
  required String currentStep,
  required List<String> flowSteps,
}) {
  final at = flowSteps.indexOf(currentStep);
  var step = currentStep;
  var chapter = onboardingChapterOf(step);
  if (chapter == null) {
    // Outside the tracker: stand where the next counted step stands.
    final later = at < 0 ? const <String>[] : flowSteps.skip(at + 1);
    for (final next in later) {
      final nextChapter = onboardingChapterOf(next);
      if (nextChapter == null) continue;
      step = next;
      chapter = nextChapter;
      break;
    }
    if (chapter == null) return const OnboardingTrackerFill.allDone();
  }

  final inChapter = [
    for (final id in flowSteps)
      if (onboardingChapterOf(id) == chapter) id,
  ];
  final behind = inChapter.indexOf(step);
  final current = behind <= 0 ? 0.0 : behind / inChapter.length;
  return OnboardingTrackerFill(
    chapter: chapter,
    bars: [
      for (final each in OnboardingChapter.values)
        if (each.index < chapter.index)
          1
        else if (each == chapter)
          current
        else
          0,
    ],
  );
}

/// Whether moving from the step [from] to the step [to] leaves one chapter
/// for another. Steps outside the tracker count as a place of their own, so
/// the move from the first real alarm to `hook_up` crosses too.
bool onboardingStepChangeCrossesChapter(String from, String to) =>
    onboardingChapterOf(from) != onboardingChapterOf(to);
