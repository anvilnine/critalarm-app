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
/// Back is offered on the steps of the first two chapters: how it rings,
/// connect, the permissions and the first topic. It goes to the nearest
/// earlier step of the flow that is on this phone ([isAvailable]) and is in
/// one of those chapters too, so it never lands on a step outside the
/// tracker. A step the run passed over because it was already true is still
/// a place Back can land.
///
/// Null on the welcome, which has nothing before it, and on every step from
/// the first real alarm on. Null everywhere once the first topic is made
/// ([hasFirstTopic]): there is no going back behind a topic that exists.
/// Null for a step the flow does not list.
String? onboardingBackStepFor({
  required String currentStep,
  required List<String> flowSteps,
  required bool hasFirstTopic,
  required bool Function(String stepId) isAvailable,
}) {
  if (hasFirstTopic || !_allowsBack(currentStep)) return null;
  final at = flowSteps.indexOf(currentStep);
  if (at <= 0) return null;
  for (var i = at - 1; i >= 0; i--) {
    final step = flowSteps[i];
    if (_allowsBack(step) && isAvailable(step)) return step;
  }
  return null;
}
