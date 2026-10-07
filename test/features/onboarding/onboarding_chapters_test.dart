import 'package:critalarm/features/onboarding/domain/flow/onboarding_chapters.dart';
import 'package:critalarm/features/onboarding/domain/flow/onboarding_flow.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final flow = BundledOnboardingFlows.defaultFlow.steps;

  OnboardingTrackerFill fillAt(String step, [List<String>? steps]) =>
      onboardingTrackerFillFor(currentStep: step, flowSteps: steps ?? flow);

  group('the chapter of a step', () {
    test('Meet is the welcome and how it rings', () {
      expect(onboardingChapterOf('welcome'), OnboardingChapter.meet);
      expect(onboardingChapterOf('how_it_rings'), OnboardingChapter.meet);
    });

    test('Set up is connect, the permissions and the first topic', () {
      expect(onboardingChapterOf('connect'), OnboardingChapter.setUp);
      expect(onboardingChapterOf('permissions'), OnboardingChapter.setUp);
      expect(onboardingChapterOf('first_topic'), OnboardingChapter.setUp);
    });

    test('Hear it is the real ring', () {
      expect(onboardingChapterOf('real_ring'), OnboardingChapter.hearIt);
    });

    test('hook up, widgets, the legacy test and the offer have none', () {
      expect(onboardingChapterOf('hook_up'), isNull);
      expect(onboardingChapterOf('widgets'), isNull);
      expect(onboardingChapterOf('legacy_test'), isNull);
      expect(onboardingChapterOf('offer'), isNull);
      expect(onboardingChapterOf('made_up'), isNull);
    });
  });

  group('the tracker on the default flow', () {
    test('starts empty on the welcome', () {
      final fill = fillAt('welcome');
      expect(fill.bars, [0, 0, 0]);
      expect(fill.chapter, OnboardingChapter.meet);
      expect(fill.position, 0);
    });

    test('the first bar is half full on how it rings', () {
      expect(fillAt('how_it_rings').bars, [0.5, 0, 0]);
    });

    test('a bar is full once its chapter is behind the user', () {
      final fill = fillAt('connect');
      expect(fill.bars, [1, 0, 0]);
      expect(fill.chapter, OnboardingChapter.setUp);
    });

    test('the second bar fills a third for each step behind', () {
      expect(fillAt('permissions').bars[1], closeTo(1 / 3, 1e-9));
      expect(fillAt('first_topic').bars[1], closeTo(2 / 3, 1e-9));
    });

    test('the third bar is empty while the real ring is on screen', () {
      final fill = fillAt('real_ring');
      expect(fill.bars, [1, 1, 0]);
      expect(fill.chapter, OnboardingChapter.hearIt);
    });

    test('every bar is full on hook up, which has no chapter', () {
      final fill = fillAt('hook_up');
      expect(fill.bars, [1, 1, 1]);
      expect(fill.chapter, isNull);
      expect(fill.isAllDone, isTrue);
      expect(fill.position, 3);
    });

    test('the fill never goes down from one step to the next', () {
      var last = -1.0;
      for (final step in flow) {
        final position = fillAt(step).position;
        expect(position, greaterThanOrEqualTo(last), reason: step);
        last = position;
      }
    });
  });

  group('skipped steps', () {
    test('a step the run passed over counts as behind the user', () {
      // The permissions were already granted, so the run went from connect
      // straight to the first topic. The bar shows two of three all the
      // same.
      expect(fillAt('first_topic').bars[1], closeTo(2 / 3, 1e-9));
    });

    test('a whole chapter passed over is a full bar', () {
      // A user who already has a server, the permissions and a topic lands
      // on the real ring.
      expect(fillAt('real_ring').bars, [1, 1, 0]);
    });
  });

  group('flows that lack a step', () {
    test('a chapter is counted over the steps the flow lists', () {
      const steps = ['welcome', 'how_it_rings', 'connect', 'first_topic'];
      expect(fillAt('connect', steps).bars, [1, 0, 0]);
      expect(fillAt('first_topic', steps).bars, [1, 0.5, 0]);
    });

    test('a flow with one Meet step fills that bar in one go', () {
      const steps = ['welcome', 'connect', 'permissions'];
      expect(fillAt('welcome', steps).bars, [0, 0, 0]);
      expect(fillAt('connect', steps).bars, [1, 0, 0]);
      expect(fillAt('permissions', steps).bars, [1, 0.5, 0]);
    });

    test('a flow with no real ring ends with every bar full', () {
      final steps = BundledOnboardingFlows.legacy.steps;
      expect(fillAt('legacy_test', steps).bars, [1, 1, 1]);
    });

    test('a step the flow does not list starts its chapter empty', () {
      const steps = ['welcome', 'how_it_rings', 'connect'];
      expect(fillAt('real_ring', steps).bars, [1, 1, 0]);
      expect(fillAt('first_topic', steps).bars, [1, 0, 0]);
    });

    test('a step with no chapter that the flow does not list is all done', () {
      expect(fillAt('widgets').bars, [1, 1, 1]);
    });
  });

  group('steps with no chapter', () {
    test('at the end of the flow every bar is full', () {
      const steps = ['welcome', 'connect', 'real_ring', 'offer', 'hook_up'];
      expect(fillAt('offer', steps).bars, [1, 1, 1]);
      expect(fillAt('hook_up', steps).bars, [1, 1, 1]);
    });

    test('in the middle it shows what the next counted step shows', () {
      // The first shipped order has widgets between two Set up steps.
      final steps = BundledOnboardingFlows.legacy.steps;
      expect(fillAt('widgets', steps), fillAt('connect', steps));
      expect(fillAt('widgets', steps).bars, [1, 0.5, 0]);
    });
  });

  group('crossing a chapter', () {
    test('two steps of one chapter do not cross', () {
      expect(
        onboardingStepChangeCrossesChapter('welcome', 'how_it_rings'),
        isFalse,
      );
      expect(
        onboardingStepChangeCrossesChapter('connect', 'first_topic'),
        isFalse,
      );
    });

    test('the last step of one chapter to the first of the next crosses', () {
      expect(
        onboardingStepChangeCrossesChapter('how_it_rings', 'connect'),
        isTrue,
      );
      expect(
        onboardingStepChangeCrossesChapter('first_topic', 'real_ring'),
        isTrue,
      );
    });

    test('going back over the same line crosses too', () {
      expect(
        onboardingStepChangeCrossesChapter('connect', 'how_it_rings'),
        isTrue,
      );
    });

    test('leaving the last chapter for hook up crosses', () {
      expect(
        onboardingStepChangeCrossesChapter('real_ring', 'hook_up'),
        isTrue,
      );
    });

    test('two steps outside the tracker do not cross', () {
      expect(onboardingStepChangeCrossesChapter('offer', 'hook_up'), isFalse);
    });
  });
}
