import 'package:critalarm/features/tour/domain/repositories/tour_repository.dart';
import 'package:critalarm/features/tour/presentation/cubits/tour_cubit.dart';
import 'package:critalarm/features/tour/presentation/cubits/tour_state.dart';
import 'package:critalarm/features/tour/presentation/tour_steps.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeTourRepository implements TourRepository {
  final Set<String> seen = {};

  @override
  bool hasSeenGuide(String guide) => seen.contains(guide);

  @override
  Future<void> markGuidesSeen(Iterable<String> guides) async =>
      seen.addAll(guides);
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
    test("a screen's first visit asks for that screen's guide", () {
      repo.seen.add(TourGuide.home.name);
      cubit.requestIfNew(TourGuide.settings);
      expect(cubit.state.status, TourStatus.requested);
      expect(cubit.state.guide, TourGuide.settings);
      expect(cubit.state.isActive, isTrue);
      expect(cubit.state.isFullReplay, isFalse);
    });

    test('a guide that was seen is not asked for again on its own', () {
      repo.seen.add(TourGuide.settings.name);
      cubit.requestIfNew(TourGuide.settings);
      expect(cubit.state.status, TourStatus.idle);
    });

    test('seeing one guide does not count for another', () {
      repo.seen.add(TourGuide.home.name);
      cubit.requestIfNew(TourGuide.history);
      expect(cubit.state.guide, TourGuide.history);
    });

    test('a second ask while one is going is ignored', () {
      repo.seen.add(TourGuide.home.name);
      cubit
        ..requestIfNew(TourGuide.history)
        ..requestIfNew(TourGuide.search);
      expect(cubit.state.guide, TourGuide.history);
    });

    test('Settings replays every guide after they were seen', () {
      repo.seen.addAll(TourGuide.values.map((g) => g.name));
      cubit.request();
      expect(cubit.state.status, TourStatus.requested);
      expect(cubit.state.isFullReplay, isTrue);
    });

    test('the offer counts as answered once the Topics guide is seen', () {
      expect(cubit.hasSeenFirstGuide, isFalse);
      repo.seen.add(TourGuide.home.name);
      expect(cubit.hasSeenFirstGuide, isTrue);
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

    test('a guide keeps its name once it starts', () {
      repo.seen.add(TourGuide.home.name);
      cubit
        ..requestIfNew(TourGuide.topic)
        ..begin(firstTopicName: 'api');
      expect(cubit.state.guide, TourGuide.topic);
      expect(cubit.state.steps, tourStepsFor(TourGuide.topic));
    });
  });

  group('a single guide', () {
    setUp(() {
      repo.seen.add(TourGuide.home.name);
      cubit
        ..requestIfNew(TourGuide.createTopic)
        ..begin(firstTopicName: 'api');
    });

    test('plays only its own steps', () {
      expect(cubit.state.steps, hasLength(3));
      for (final step in cubit.state.steps) {
        expect(step.guide, TourGuide.createTopic);
      }
    });

    test('next on its last step finishes and marks only it seen', () {
      for (var i = 0; i < cubit.state.steps.length; i++) {
        cubit.next();
      }
      expect(cubit.state.status, TourStatus.idle);
      expect(repo.seen, {TourGuide.home.name, TourGuide.createTopic.name});
    });

    test('skipping marks only it seen', () {
      cubit.finish();
      expect(repo.seen, {TourGuide.home.name, TourGuide.createTopic.name});
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
      expect(cubit.state.steps, tourSteps);
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
      for (var i = 0; i < tourSteps.length; i++) {
        cubit.next();
      }
      expect(cubit.state.status, TourStatus.idle);
      expect(repo.seen, TourGuide.values.map((g) => g.name).toSet());
    });

    test('skipping marks it seen and the examples go away', () {
      expect(cubit.state.showsHomeExamples, isTrue);
      cubit.finish();
      expect(cubit.state.status, TourStatus.idle);
      expect(repo.seen, TourGuide.values.map((g) => g.name).toSet());
      expect(cubit.state.showsHomeExamples, isFalse);
      expect(
        cubit.state.showsExampleTopic(TourCubit.exampleTopicName),
        isFalse,
      );
    });

    test('an alarm stops it without marking it seen', () {
      cubit.stop();
      expect(cubit.state.status, TourStatus.idle);
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
      ..requestIfNew(TourGuide.home)
      ..acceptOffer()
      ..stop();
    expect(cubit.state.isActive, isFalse);
    expect(repo.seen, isEmpty);
  });

  group('the offer', () {
    test('Topics raises it while the Topics guide is unseen', () {
      cubit.requestIfNew(TourGuide.home);
      expect(cubit.state.status, TourStatus.offering);
      expect(cubit.state.guide, TourGuide.home);
      expect(cubit.state.isActive, isTrue);
      expect(cubit.state.isRunning, isFalse);
    });

    test('other screens wait until it is answered', () {
      cubit.requestIfNew(TourGuide.settings);
      expect(cubit.state.status, TourStatus.idle);
      cubit.requestIfNew(TourGuide.search);
      expect(cubit.state.status, TourStatus.idle);
    });

    test('a second Topics visit while it is up changes nothing', () {
      cubit.requestIfNew(TourGuide.home);
      final first = cubit.state;
      cubit
        ..requestIfNew(TourGuide.home)
        ..requestIfNew(TourGuide.history);
      expect(cubit.state, first);
    });

    test('accepting plays the short Topics guide, not the full tour', () {
      cubit
        ..requestIfNew(TourGuide.home)
        ..acceptOffer();
      expect(cubit.state.status, TourStatus.requested);
      expect(cubit.state.guide, TourGuide.home);
      expect(cubit.state.isFullReplay, isFalse);
      expect(cubit.state.moves, isFalse);
      cubit.begin();
      expect(cubit.state.isRunning, isTrue);
      expect(cubit.state.steps, tourStepsFor(TourGuide.home));
    });

    test('finishing the accepted guide marks only Topics seen', () {
      cubit
        ..requestIfNew(TourGuide.home)
        ..acceptOffer()
        ..begin()
        ..finish();
      expect(repo.seen, {TourGuide.home.name});
      cubit.requestIfNew(TourGuide.settings);
      expect(cubit.state.guide, TourGuide.settings);
    });

    test('declining marks every guide seen and goes idle', () {
      cubit
        ..requestIfNew(TourGuide.home)
        ..declineOffer();
      expect(cubit.state.status, TourStatus.idle);
      expect(repo.seen, TourGuide.values.map((g) => g.name).toSet());
      expect(cubit.hasSeenFirstGuide, isTrue);
      cubit
        ..requestIfNew(TourGuide.home)
        ..requestIfNew(TourGuide.history);
      expect(cubit.state.status, TourStatus.idle);
    });

    test('an alarm drops it without marking anything seen', () {
      cubit
        ..requestIfNew(TourGuide.home)
        ..stop();
      expect(cubit.state.status, TourStatus.idle);
      expect(repo.seen, isEmpty);
      cubit.requestIfNew(TourGuide.home);
      expect(cubit.state.status, TourStatus.offering);
    });

    test('accept and decline do nothing unless it is up', () {
      cubit
        ..acceptOffer()
        ..declineOffer();
      expect(cubit.state.status, TourStatus.idle);
      expect(repo.seen, isEmpty);
    });
  });

  group('picked from Settings', () {
    test('the full tour does not use fromMenu and moves', () {
      cubit.requestGuide(null);
      expect(cubit.state.isFullReplay, isTrue);
      expect(cubit.state.fromMenu, isFalse);
      expect(cubit.state.moves, isTrue);
    });

    test('a single guide is flagged fromMenu and moves', () {
      cubit.requestGuide(TourGuide.topic);
      expect(cubit.state.status, TourStatus.requested);
      expect(cubit.state.guide, TourGuide.topic);
      expect(cubit.state.fromMenu, isTrue);
      expect(cubit.state.isFullReplay, isFalse);
      expect(cubit.state.moves, isTrue);
      cubit.begin(firstTopicName: 'api');
      expect(cubit.state.fromMenu, isTrue);
      cubit.next();
      expect(cubit.state.fromMenu, isTrue);
    });

    test('it plays even before the offer was answered', () {
      cubit.requestGuide(TourGuide.history);
      expect(cubit.state.status, TourStatus.requested);
    });

    test('finishing one marks only that guide seen', () {
      cubit
        ..requestGuide(TourGuide.search)
        ..begin()
        ..finish();
      expect(cubit.state.status, TourStatus.idle);
      expect(cubit.state.fromMenu, isFalse);
      expect(repo.seen, {TourGuide.search.name});
    });

    test('first-visit guides do not move', () {
      repo.seen.add(TourGuide.home.name);
      cubit.requestIfNew(TourGuide.history);
      expect(cubit.state.moves, isFalse);
    });
  });
}
