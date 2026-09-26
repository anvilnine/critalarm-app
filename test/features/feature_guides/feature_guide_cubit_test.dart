import 'package:critalarm/features/feature_guides/domain/repositories/feature_guide_repository.dart';
import 'package:critalarm/features/feature_guides/presentation/cubits/feature_guide_cubit.dart';
import 'package:critalarm/features/feature_guides/presentation/cubits/feature_guide_state.dart';
import 'package:critalarm/features/feature_guides/presentation/feature_guide_steps.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeFeatureGuideRepository implements FeatureGuideRepository {
  final Set<String> seen = {};

  @override
  bool hasSeenGuide(String guide) => seen.contains(guide);

  @override
  Future<void> markGuidesSeen(Iterable<String> guides) async =>
      seen.addAll(guides);
}

void main() {
  late _FakeFeatureGuideRepository repo;
  late FeatureGuideCubit cubit;

  setUp(() {
    repo = _FakeFeatureGuideRepository();
    cubit = FeatureGuideCubit(repo);
  });

  tearDown(() => cubit.close());

  group('starting', () {
    test("a screen's first visit asks for that screen's guide", () {
      cubit.requestIfNew(FeatureGuide.settings);
      expect(cubit.state.status, FeatureGuideStatus.requested);
      expect(cubit.state.guide, FeatureGuide.settings);
      expect(cubit.state.isActive, isTrue);
      expect(cubit.state.isFullReplay, isFalse);
    });

    test('a guide that was seen is not asked for again on its own', () {
      repo.seen.add(FeatureGuide.settings.name);
      cubit.requestIfNew(FeatureGuide.settings);
      expect(cubit.state.status, FeatureGuideStatus.idle);
    });

    test('seeing one guide does not count for another', () {
      repo.seen.add(FeatureGuide.home.name);
      cubit.requestIfNew(FeatureGuide.history);
      expect(cubit.state.guide, FeatureGuide.history);
    });

    test('a second ask while one is going is ignored', () {
      cubit
        ..requestIfNew(FeatureGuide.home)
        ..requestIfNew(FeatureGuide.search);
      expect(cubit.state.guide, FeatureGuide.home);
    });

    test('Settings replays every guide after they were seen', () {
      repo.seen.addAll(FeatureGuide.values.map((g) => g.name));
      cubit.request();
      expect(cubit.state.status, FeatureGuideStatus.requested);
      expect(cubit.state.isFullReplay, isTrue);
    });

    test('the first guide is the Topics one', () {
      expect(cubit.hasSeenFirstGuide, isFalse);
      repo.seen.add(FeatureGuide.home.name);
      expect(cubit.hasSeenFirstGuide, isTrue);
    });

    test('nothing starts until something asked for it', () {
      cubit.begin(firstTopicName: 'api');
      expect(cubit.state.status, FeatureGuideStatus.idle);
    });

    test('with topics, the guide opens the first real one', () {
      cubit
        ..request()
        ..begin(firstTopicName: 'api');
      expect(cubit.state.isRunning, isTrue);
      expect(cubit.state.stepIndex, 0);
      expect(cubit.state.topicName, 'api');
      expect(cubit.state.usingExamples, isFalse);
      expect(cubit.state.showsExampleTopic('api'), isFalse);
    });

    test('with no topics, the guide shows the example topic', () {
      cubit
        ..request()
        ..begin();
      expect(cubit.state.usingExamples, isTrue);
      expect(cubit.state.topicName, FeatureGuideCubit.exampleTopicName);
      expect(
        cubit.state.showsExampleTopic(FeatureGuideCubit.exampleTopicName),
        isTrue,
      );
      expect(cubit.state.showsExampleTopic('something-else'), isFalse);
    });

    test('a guide keeps its name once it starts', () {
      cubit
        ..requestIfNew(FeatureGuide.topic)
        ..begin(firstTopicName: 'api');
      expect(cubit.state.guide, FeatureGuide.topic);
      expect(cubit.state.steps, featureGuideStepsFor(FeatureGuide.topic));
    });
  });

  group('a single guide', () {
    setUp(() {
      cubit
        ..requestIfNew(FeatureGuide.createTopic)
        ..begin(firstTopicName: 'api');
    });

    test('plays only its own steps', () {
      expect(cubit.state.steps, hasLength(3));
      for (final step in cubit.state.steps) {
        expect(step.guide, FeatureGuide.createTopic);
      }
    });

    test('next on its last step finishes and marks only it seen', () {
      for (var i = 0; i < cubit.state.steps.length; i++) {
        cubit.next();
      }
      expect(cubit.state.status, FeatureGuideStatus.idle);
      expect(repo.seen, {FeatureGuide.createTopic.name});
    });

    test('skipping marks only it seen', () {
      cubit.finish();
      expect(repo.seen, {FeatureGuide.createTopic.name});
    });

    test('does not put the examples on the Topics list', () {
      expect(cubit.state.showsHomeExamples, isFalse);
    });
  });

  group('the full replay', () {
    setUp(() {
      cubit
        ..request()
        ..begin();
    });

    test('plays every step', () {
      expect(cubit.state.steps, featureGuideSteps);
    });

    test('next and back move one step, and back stops at the first', () {
      cubit.next();
      expect(cubit.state.stepIndex, 1);
      cubit
        ..back()
        ..back();
      expect(cubit.state.stepIndex, 0);
    });

    test('next on the last step finishes and marks every guide seen', () {
      for (var i = 0; i < featureGuideSteps.length; i++) {
        cubit.next();
      }
      expect(cubit.state.status, FeatureGuideStatus.idle);
      expect(repo.seen, FeatureGuide.values.map((g) => g.name).toSet());
    });

    test('skipping marks it seen and the examples go away', () {
      expect(cubit.state.showsHomeExamples, isTrue);
      cubit.finish();
      expect(cubit.state.status, FeatureGuideStatus.idle);
      expect(repo.seen, FeatureGuide.values.map((g) => g.name).toSet());
      expect(cubit.state.showsHomeExamples, isFalse);
      expect(
        cubit.state.showsExampleTopic(FeatureGuideCubit.exampleTopicName),
        isFalse,
      );
    });

    test('an alarm stops it without marking it seen', () {
      cubit.stop();
      expect(cubit.state.status, FeatureGuideStatus.idle);
      expect(repo.seen, isEmpty);
    });

    test('a step whose spot never shows is skipped once, not twice', () {
      cubit
        ..skipMissing(0)
        // Late report for the step already left behind: ignored.
        ..skipMissing(0);
      expect(cubit.state.stepIndex, 1);
    });
  });

  test('an alarm during a requested guide drops it unseen', () {
    cubit
      ..requestIfNew(FeatureGuide.home)
      ..stop();
    expect(cubit.state.isActive, isFalse);
    expect(repo.seen, isEmpty);
  });
}
