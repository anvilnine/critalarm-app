import 'package:critalarm/features/onboarding/domain/flow/onboarding_chapters.dart';

/// The chapters Back works in. From the first real alarm on, setup only
/// moves forward.
const Set<OnboardingChapter> _backChapters = {
  OnboardingChapter.meet,
  OnboardingChapter.setUp,
};

bool _allowsBack(String stepId) =>
    _backChapters.contains(onboardingChapterOf(stepId));

/// The step Back goes to from [currentStep], or null when Back is not
/// offered there.
///
/// Back goes to the nearest step before [currentStep] in [flowSteps] that
/// is in [shownSteps], the steps that were on screen at any point in this
/// run, and is in the first two chapters, so it never lands on a step
/// outside the tracker. A step the run passed over, because it was already
/// true for this user or is not on this phone, was never shown, so Back
/// never opens it. Going back takes nothing out of [shownSteps], so a step
/// the user saw once stays in reach for the whole run.
///
/// Null on the welcome, which has nothing before it, and on every step from
/// the first real alarm on. Null everywhere once the first topic is made
/// ([hasFirstTopic]): there is no going back behind a topic that exists.
/// Null when [currentStep] was not shown or is not in the flow, and when no
/// step before it was shown.
String? onboardingBackStepFor({
  required String currentStep,
  required List<String> flowSteps,
  required Set<String> shownSteps,
  required bool hasFirstTopic,
}) {
  if (hasFirstTopic || !_allowsBack(currentStep)) return null;
  if (!shownSteps.contains(currentStep)) return null;
  final at = flowSteps.indexOf(currentStep);
  for (var i = at - 1; i >= 0; i--) {
    final step = flowSteps[i];
    if (shownSteps.contains(step) && _allowsBack(step)) return step;
  }
  return null;
}
