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
/// Back walks [shownSteps]: the steps that were on screen in this run, in
/// the order the user saw them. It goes to the nearest one before
/// [currentStep] that is in the first two chapters, so it never lands on a
/// step outside the tracker. A step the run passed over, because it was
/// already true for this user or is not on this phone, was never shown, so
/// it is not in the list and Back never opens it.
///
/// Null on the welcome, which has nothing before it, and on every step from
/// the first real alarm on. Null everywhere once the first topic is made
/// ([hasFirstTopic]): there is no going back behind a topic that exists.
/// Null when [currentStep] is not in the list, or is the first one in it.
String? onboardingBackStepFor({
  required String currentStep,
  required List<String> shownSteps,
  required bool hasFirstTopic,
}) {
  if (hasFirstTopic || !_allowsBack(currentStep)) return null;
  final at = shownSteps.lastIndexOf(currentStep);
  if (at <= 0) return null;
  for (var i = at - 1; i >= 0; i--) {
    final step = shownSteps[i];
    if (_allowsBack(step)) return step;
  }
  return null;
}

/// [shownSteps] with [stepId] now on screen.
///
/// A step that is new to the run goes on the end. A step the user has been
/// on before, which is what Back opens, drops everything after it: those
/// steps are ahead of the user again.
List<String> onboardingShownStepsWith(List<String> shownSteps, String stepId) {
  final at = shownSteps.indexOf(stepId);
  return at < 0 ? [...shownSteps, stepId] : shownSteps.sublist(0, at + 1);
}
