import 'package:critalarm/features/tour/domain/repositories/tour_repository.dart';
import 'package:critalarm/features/tour/presentation/cubits/tour_cubit.dart';
import 'package:critalarm/features/tour/presentation/cubits/tour_state.dart';
import 'package:critalarm/features/tour/presentation/tour_steps.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeTourRepository implements TourRepository {
  bool seen = false;

  @override
  bool hasSeenTour() => seen;

  @override
  Future<void> markTourSeen() async => seen = true;
}

void main() {
  late _FakeTourRepository repo;
  late TourCubit cubit;

  setUp(() {
    repo = _FakeTourRepository();
    cubit = TourCubit(repo);
  });

  tearDown(() => cubit.close());

  group('starting', () {
    test('first run asks for the tour', () {
      cubit.requestIfNew();
      expect(cubit.state.status, TourStatus.requested);
    });

    test('a device that has seen it is not asked again on its own', () {
      repo.seen = true;
      cubit.requestIfNew();
      expect(cubit.state.status, TourStatus.idle);
    });

    test('Settings can replay it after it was seen', () {
      repo.seen = true;
      cubit.request();
      expect(cubit.state.status, TourStatus.requested);
    });

    test('nothing starts until something asked for it', () {
      cubit.begin(firstTopicName: 'api');
      expect(cubit.state.status, TourStatus.idle);
    });

    test('with topics, the tour opens the first real one', () {
      cubit
        ..request()
        ..begin(firstTopicName: 'api');
      expect(cubit.state.isRunning, isTrue);
      expect(cubit.state.stepIndex, 0);
      expect(cubit.state.topicName, 'api');
      expect(cubit.state.usingExamples, isFalse);
      expect(cubit.state.showsExampleTopic('api'), isFalse);
    });

    test('with no topics, the tour shows the example topic', () {
      cubit
        ..request()
        ..begin();
      expect(cubit.state.usingExamples, isTrue);
      expect(cubit.state.topicName, TourCubit.exampleTopicName);
      expect(cubit.state.showsExampleTopic(TourCubit.exampleTopicName), isTrue);
      expect(cubit.state.showsExampleTopic('something-else'), isFalse);
    });
  });

  group('moving through it', () {
    setUp(() {
      cubit
        ..request()
        ..begin();
    });

    test('next and back move one step, and back stops at the first', () {
      cubit.next();
      expect(cubit.state.stepIndex, 1);
      cubit
        ..back()
        ..back();
      expect(cubit.state.stepIndex, 0);
    });

    test('next on the last step finishes and marks it seen', () {
      for (var i = 0; i < tourSteps.length; i++) {
        cubit.next();
      }
      expect(cubit.state.status, TourStatus.idle);
      expect(repo.seen, isTrue);
    });

    test('skipping marks it seen and the examples go away', () {
      cubit.finish();
      expect(cubit.state.status, TourStatus.idle);
      expect(repo.seen, isTrue);
      expect(
        cubit.state.showsExampleTopic(TourCubit.exampleTopicName),
        isFalse,
      );
    });

    test('an alarm stops it without marking it seen', () {
      cubit.stop();
      expect(cubit.state.status, TourStatus.idle);
      expect(repo.seen, isFalse);
    });

    test('a step whose spot never shows is skipped once, not twice', () {
      cubit
        ..skipMissing(0)
        // Late report for the step already left behind: ignored.
        ..skipMissing(0);
      expect(cubit.state.stepIndex, 1);
    });
  });
}
