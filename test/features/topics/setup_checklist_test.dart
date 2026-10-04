import 'package:critalarm/features/incidents/domain/setup_test_kind.dart';
import 'package:critalarm/features/topics/domain/first_message/first_message_source.dart';
import 'package:critalarm/features/topics/domain/first_message/first_message_watcher.dart';
import 'package:critalarm/features/topics/domain/setup_checklist.dart';
import 'package:critalarm/features/topics/presentation/cubits/home_setup_state.dart';
import 'package:critalarm/features/topics/presentation/cubits/home_state.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/home_setup_fakes.dart';

SetupChecklist _checklist({
  bool isRetired = false,
  bool hasServer = true,
  bool isLoaded = true,
  List<bool> topicCritical = const [],
  bool isFirstMessageReceived = false,
}) => setupChecklistFor(
  isRetired: isRetired,
  hasServer: hasServer,
  isLoaded: isLoaded,
  topicCritical: topicCritical,
  isFirstMessageReceived: isFirstMessageReceived,
);

void main() {
  group('setupChecklistFor', () {
    test('no server: nothing is drawn, the no-server card has that row', () {
      final checklist = _checklist(hasServer: false);
      expect(checklist.isVisible, isFalse);
      expect(checklist, SetupChecklist.hidden);
    });

    test('a list that has not loaded draws nothing', () {
      expect(_checklist(isLoaded: false).isVisible, isFalse);
    });

    test('server and no topics: one row ticked', () {
      final checklist = _checklist();
      expect(checklist.isVisible, isTrue);
      expect(checklist.isTicked(SetupChecklistRow.server), isTrue);
      expect(checklist.isTicked(SetupChecklistRow.criticalTopic), isFalse);
      expect(checklist.isTicked(SetupChecklistRow.firstMessage), isFalse);
      expect(checklist.hasTopics, isFalse);
      expect(checklist.tickedCount, 1);
      expect(checklist.isComplete, isFalse);
    });

    test('a topic with Critical delivery off does not tick the row', () {
      final checklist = _checklist(topicCritical: [false, false]);
      expect(checklist.hasTopics, isTrue);
      expect(checklist.hasCriticalTopic, isFalse);
      expect(checklist.tickedCount, 1);
    });

    test('a critical topic and no message: two rows ticked', () {
      final checklist = _checklist(topicCritical: [false, true]);
      expect(checklist.hasCriticalTopic, isTrue);
      expect(checklist.hasFirstMessage, isFalse);
      expect(checklist.tickedCount, 2);
      expect(checklist.isComplete, isFalse);
    });

    test('a message on a topic that is not critical: the middle row waits', () {
      final checklist = _checklist(
        topicCritical: [false],
        isFirstMessageReceived: true,
      );
      expect(checklist.hasCriticalTopic, isFalse);
      expect(checklist.hasFirstMessage, isTrue);
      expect(checklist.isComplete, isFalse);
    });

    test('all three true: complete', () {
      final checklist = _checklist(
        topicCritical: [true],
        isFirstMessageReceived: true,
      );
      expect(checklist.tickedCount, 3);
      expect(checklist.isComplete, isTrue);
    });

    test('every topic deleted after the message arrived: the first-message '
        'row stays ticked and the checklist stays', () {
      final checklist = _checklist(isFirstMessageReceived: true);
      expect(checklist.isVisible, isTrue);
      expect(checklist.hasFirstMessage, isTrue);
      expect(checklist.hasCriticalTopic, isFalse);
    });

    test('retired: absent whatever else is true, no topics included', () {
      expect(_checklist(isRetired: true).isVisible, isFalse);
      expect(
        _checklist(isRetired: true, topicCritical: [true]).isVisible,
        isFalse,
      );
    });
  });

  group('seedSetupChecklist', () {
    SetupChecklistSeed seed({
      bool isFirstMessageReceived = false,
      bool hasOwnMessage = false,
      List<String> incidentIds = const [],
      Set<String> setupIncidentIds = const {},
    }) => seedSetupChecklist(
      isFirstMessageReceived: isFirstMessageReceived,
      hasOwnMessage: hasOwnMessage,
      incidentIds: incidentIds,
      setupIncidentIds: setupIncidentIds,
    );

    test('a phone with nothing of its own gets the checklist', () {
      final result = seed();
      expect(result.marksFirstMessage, isFalse);
      expect(result.retiresChecklist, isFalse);
    });

    test("a message of the user's own retires it and sets the flag", () {
      final result = seed(hasOwnMessage: true);
      expect(result.marksFirstMessage, isTrue);
      expect(result.retiresChecklist, isTrue);
    });

    test('an alarm that was not a setup test retires it', () {
      final result = seed(incidentIds: ['inc_real']);
      expect(result.marksFirstMessage, isTrue);
      expect(result.retiresChecklist, isTrue);
    });

    test('setup tests never count', () {
      final result = seed(
        incidentIds: ['inc_setup', phoneOnlyTestIncidentId],
        setupIncidentIds: {'inc_setup'},
      );
      expect(result.marksFirstMessage, isFalse);
      expect(result.retiresChecklist, isFalse);
    });

    test('the flag already set (setup was finished) retires it', () {
      final result = seed(isFirstMessageReceived: true);
      expect(result.marksFirstMessage, isFalse);
      expect(result.retiresChecklist, isTrue);
    });
  });

  group('setupChecklistRoute', () {
    String? route(
      SetupChecklistRow row,
      SetupChecklist checklist, {
      String? firstTopic,
      String? watchedTopic,
    }) => setupChecklistRoute(
      row,
      checklist: checklist,
      firstTopic: firstTopic,
      watchedTopic: watchedTopic,
    );

    test('the critical-topic row opens the new-topic screen with no topic', () {
      expect(
        route(SetupChecklistRow.criticalTopic, _checklist()),
        '/topics/new',
      );
    });

    test('with a topic it opens that topic, where the switch is', () {
      expect(
        route(
          SetupChecklistRow.criticalTopic,
          _checklist(topicCritical: [false]),
          firstTopic: 'db backups',
        ),
        '/topics/db%20backups',
      );
    });

    test('the first-message row opens the watched topic with its curl', () {
      expect(
        route(
          SetupChecklistRow.firstMessage,
          _checklist(topicCritical: [true]),
          watchedTopic: 'prod',
        ),
        '/topics/prod?curl=1',
      );
      expect(route(SetupChecklistRow.firstMessage, _checklist()), isNull);
    });

    test('a ticked row and the server row are not buttons', () {
      final checklist = _checklist(
        topicCritical: [true],
        isFirstMessageReceived: true,
      );
      for (final row in SetupChecklistRow.values) {
        expect(
          route(row, checklist, firstTopic: 'prod', watchedTopic: 'prod'),
          isNull,
        );
      }
      expect(route(SetupChecklistRow.server, _checklist()), isNull);
    });

    test('no row does anything but open a screen: nothing here can turn '
        'Critical delivery on', () {
      // A row's whole effect is the route it returns. Every route is a
      // topic page or the new-topic screen, and none carries a value for
      // the switch.
      final checklists = [
        _checklist(),
        _checklist(topicCritical: [false]),
        _checklist(topicCritical: [true]),
        _checklist(topicCritical: [false], isFirstMessageReceived: true),
      ];
      for (final checklist in checklists) {
        for (final row in SetupChecklistRow.values) {
          final to = route(row, checklist, firstTopic: 'a', watchedTopic: 'a');
          if (to == null) continue;
          expect(to, anyOf('/topics/new', '/topics/a', '/topics/a?curl=1'));
          expect(to.toLowerCase(), isNot(contains('critical')));
        }
      }
    });
  });

  group('topicsToWatchForFirstMessage', () {
    test('critical topics first, then list order, capped', () {
      expect(
        topicsToWatchForFirstMessage([
          (name: 'a', isCritical: false),
          (name: 'b', isCritical: true),
          (name: 'c', isCritical: false),
          (name: 'd', isCritical: true),
        ]),
        ['b', 'd', 'a'],
      );
      expect(topicsToWatchForFirstMessage(const []), isEmpty);
    });
  });

  group('HomeSetupCubit, the checklist', () {
    late HomeSetupHarness h;

    setUp(() => h = HomeSetupHarness());
    tearDown(() => h.dispose());

    test('no server: nothing shows and nothing is read or saved', () async {
      await h.open(
        const HomeState(status: HomeStatus.failure, hasServer: false),
      );
      expect(h.cubit.state.phase, HomeSetupPhase.none);
      expect(h.source.reads, isEmpty);
      expect(h.store.isSeeded, isFalse);
    });

    test('a user who left setup early sees one row ticked', () async {
      await h.open(loadedHome());
      final state = h.cubit.state;
      expect(state.phase, HomeSetupPhase.checklist);
      expect(state.checklist.tickedCount, 1);
      expect(state.routeFor(SetupChecklistRow.criticalTopic), '/topics/new');
      expect(h.store.isSeeded, isTrue);
      expect(h.store.isDone, isFalse);
      expect(h.cubit.watchedTopics, isEmpty);
    });

    test('a topic that is not critical leaves the middle row open and '
        'points at that topic', () async {
      await h.open(loadedHome([topicItem('cron')]));
      final state = h.cubit.state;
      expect(state.checklist.hasCriticalTopic, isFalse);
      expect(state.routeFor(SetupChecklistRow.criticalTopic), '/topics/cron');
    });

    test('rows tick as they turn true, and stay while topics exist', () async {
      await h.open(loadedHome());
      await h.cubit.homeChanged(loadedHome([topicItem('prod')]));
      await h.settle();
      expect(h.cubit.state.checklist.tickedCount, 1);
      await h.cubit.homeChanged(
        loadedHome([topicItem('prod', isCritical: true)]),
      );
      await h.settle();
      expect(h.cubit.state.phase, HomeSetupPhase.checklist);
      expect(h.cubit.state.checklist.tickedCount, 2);
      expect(
        h.cubit.state.routeFor(SetupChecklistRow.firstMessage),
        '/topics/prod?curl=1',
      );
    });

    test(
      'the first-message row stays ticked after every topic is deleted',
      () async {
        await h.open(loadedHome([topicItem('cron')]));
        h.firstMessage.isReceived = true;
        await h.cubit.homeChanged(loadedHome());
        await h.settle();
        final state = h.cubit.state;
        expect(state.phase, HomeSetupPhase.checklist);
        expect(state.checklist.hasFirstMessage, isTrue);
        expect(state.checklist.hasCriticalTopic, isFalse);
      },
    );

    test('all three true on first sight (setup was finished): no checklist, '
        'no celebration, done is saved', () async {
      h
        ..firstMessage.isReceived = true
        ..store.isWidgetsCardSeen = true;
      await h.open(loadedHome([topicItem('prod', isCritical: true)]));
      expect(
        h.states.map((s) => s.phase),
        isNot(contains(HomeSetupPhase.checklist)),
      );
      expect(
        h.states.map((s) => s.phase),
        isNot(contains(HomeSetupPhase.celebration)),
      );
      expect(h.store.isDone, isTrue);
      expect(h.timers, isEmpty);
    });

    test('the last row turning in view saves done, then ticks, then '
        'celebrates, then goes for good', () async {
      await h.open(loadedHome([topicItem('prod', isCritical: true)]));
      expect(h.cubit.state.checklist.tickedCount, 2);
      h.log.clear();

      h.firstMessage.isReceived = true;
      await h.cubit.homeChanged(
        loadedHome([topicItem('prod', isCritical: true)]),
      );
      await h.settle();

      // Done is on disk before the ticked rows are drawn, and so before
      // the celebration: a kill at any point after cannot replay it.
      expect(h.log, ['done', 'state:checklist']);
      expect(h.cubit.state.checklist.isComplete, isTrue);

      await h.fire(h.cubit.tickHold);
      expect(h.cubit.state.phase, HomeSetupPhase.celebration);
      expect(h.log, ['done', 'state:checklist', 'state:celebration']);

      await h.fire(h.cubit.celebrationHold);
      expect(h.cubit.state.phase, HomeSetupPhase.none);

      // Whatever happens next, it does not come back: not with the topic
      // gone, not on a fresh Home.
      await h.cubit.homeChanged(loadedHome());
      await h.settle();
      expect(h.cubit.state.phase, HomeSetupPhase.none);
    });

    test('a new Home after done never celebrates or lists again', () async {
      h.store
        ..isSeeded = true
        ..isDone = true
        ..isWidgetsCardSeen = true;
      h.firstMessage.isReceived = true;
      await h.open(loadedHome([topicItem('prod', isCritical: true)]));
      expect(h.states, isEmpty);
      await h.cubit.homeChanged(loadedHome());
      await h.settle();
      expect(h.states, isEmpty);
    });

    test('leaving Home ends the celebration', () async {
      await h.open(loadedHome([topicItem('prod', isCritical: true)]));
      h.firstMessage.isReceived = true;
      await h.cubit.homeChanged(
        loadedHome([topicItem('prod', isCritical: true)]),
      );
      await h.settle();
      await h.fire(h.cubit.tickHold);
      expect(h.cubit.state.phase, HomeSetupPhase.celebration);

      await h.cubit.screenChanged(isInFront: false, isGuideActive: false);
      await h.settle();
      expect(h.cubit.state.phase, HomeSetupPhase.none);
      expect(h.store.isDone, isTrue);
    });

    test(
      'a row that turns while Home is covered waits for Home to be back',
      () async {
        await h.open(loadedHome([topicItem('prod')]));
        await h.cubit.screenChanged(isInFront: false, isGuideActive: false);
        await h.cubit.homeChanged(
          loadedHome([topicItem('prod', isCritical: true)]),
        );
        await h.settle();
        expect(h.cubit.state.checklist.hasCriticalTopic, isFalse);

        await h.cubit.screenChanged(isInFront: true, isGuideActive: false);
        await h.settle();
        expect(h.cubit.state.checklist.hasCriticalTopic, isTrue);
      },
    );

    test(
      'the last row turning while Home is covered celebrates on return',
      () async {
        await h.open(loadedHome([topicItem('prod')]));
        h.firstMessage.isReceived = true;
        await h.cubit.screenChanged(isInFront: false, isGuideActive: false);
        await h.cubit.homeChanged(
          loadedHome([topicItem('prod', isCritical: true)]),
        );
        await h.settle();
        expect(h.store.isDone, isFalse);
        expect(h.timers.where((t) => t.duration == h.cubit.tickHold), isEmpty);

        await h.cubit.screenChanged(isInFront: true, isGuideActive: false);
        await h.settle();
        expect(h.store.isDone, isTrue);
        await h.fire(h.cubit.tickHold);
        expect(h.cubit.state.phase, HomeSetupPhase.celebration);
      },
    );

    test('a list that failed or went stale draws nothing', () async {
      await h.open(loadedHome([topicItem('prod')]));
      expect(h.cubit.state.phase, HomeSetupPhase.checklist);
      await h.cubit.homeChanged(
        HomeState(
          status: HomeStatus.failure,
          topicItems: [topicItem('prod')],
          isStale: true,
        ),
      );
      await h.settle();
      expect(h.cubit.state.phase, HomeSetupPhase.none);
    });
  });

  group('HomeSetupCubit, the first look at an existing install', () {
    late HomeSetupHarness h;

    setUp(() => h = HomeSetupHarness());
    tearDown(() => h.dispose());

    test("a topic that already holds a message of the user's own: the "
        'flag is set, the checklist never shows', () async {
      h.store.isWidgetsCardSeen = true;
      h.source.everything['cron'] = const FirstMessagePage(
        candidates: ['m1'],
        newestId: 'm1',
      );
      await h.open(loadedHome([topicItem('db'), topicItem('cron')]));
      expect(h.firstMessage.isReceived, isTrue);
      expect(h.store.isDone, isTrue);
      expect(h.store.isSeeded, isTrue);
      expect(h.states, isEmpty);
      expect(h.source.reads, ['db@all', 'cron@all']);
    });

    test('a topic that holds only test alarms does not count', () async {
      // The source leaves test alarms out of the candidates.
      h.source.everything['prod'] = const FirstMessagePage(
        candidates: [],
        newestId: 'm_test',
      );
      await h.open(loadedHome([topicItem('prod', isCritical: true)]));
      expect(h.firstMessage.isReceived, isFalse);
      expect(h.store.isDone, isFalse);
      expect(h.cubit.state.phase, HomeSetupPhase.checklist);
      expect(h.cubit.state.checklist.tickedCount, 2);
    });

    test('an old alarm in history counts, a setup test does not', () async {
      h
        ..incidentIds = ['inc_setup']
        ..setupIncidentIds = {'inc_setup'};
      await h.open(loadedHome());
      expect(h.cubit.state.phase, HomeSetupPhase.checklist);
      await h.dispose();

      h = HomeSetupHarness()
        ..store.isWidgetsCardSeen = true
        ..incidentIds = ['inc_setup', 'inc_real']
        ..setupIncidentIds = {'inc_setup'};
      await h.open(loadedHome());
      expect(h.firstMessage.isReceived, isTrue);
      expect(h.store.isDone, isTrue);
      expect(h.states, isEmpty);
    });

    test('it looks once: a message that lands later goes through the '
        'checklist, not the seed', () async {
      h.source.everything['prod'] = const FirstMessagePage(
        candidates: [],
        newestId: 'm_test',
      );
      await h.open(loadedHome([topicItem('prod', isCritical: true)]));
      expect(h.log.where((entry) => entry == 'seeded'), hasLength(1));

      // A message of the user's own is on the topic by the next load. The
      // seed would have retired the checklist in silence. It has had its
      // one look, so the list stays up and the row is the watcher's to
      // tick.
      h.source.everything['prod'] = const FirstMessagePage(
        candidates: ['m1'],
        newestId: 'm1',
      );
      await h.cubit.homeChanged(
        loadedHome([topicItem('prod', isCritical: true), topicItem('b')]),
      );
      await h.settle();
      expect(h.log.where((entry) => entry == 'seeded'), hasLength(1));
      expect(h.store.isDone, isFalse);
      expect(h.cubit.state.phase, HomeSetupPhase.checklist);
      expect(h.cubit.state.checklist.hasFirstMessage, isFalse);
    });

    test('a server that cannot be read: nothing is saved or drawn, and the '
        'next load looks again', () async {
      h.source.failure = Exception('offline');
      await h.open(loadedHome([topicItem('prod')]));
      expect(h.store.isSeeded, isFalse);
      expect(h.cubit.state.phase, HomeSetupPhase.none);

      h.source.failure = null;
      await h.cubit.homeChanged(loadedHome([topicItem('prod')]));
      await h.settle();
      expect(h.store.isSeeded, isTrue);
      expect(h.cubit.state.phase, HomeSetupPhase.checklist);
    });
  });

  group('HomeSetupCubit, the first-message poll', () {
    late HomeSetupHarness h;

    setUp(() => h = HomeSetupHarness());
    tearDown(() => h.dispose());

    test('polls only while the row is open and Home is in front', () async {
      await h.open(loadedHome([topicItem('prod', isCritical: true)]));
      expect(h.cubit.watchedTopics, ['prod']);
      // The seed read, then the watcher's baseline read.
      expect(h.source.reads, ['prod@all', 'prod@all']);
      expect(
        h.timers.where((t) => t.isActive).map((t) => t.duration),
        [FirstMessageWatcher.interval],
      );

      await h.cubit.screenChanged(isInFront: false, isGuideActive: false);
      await h.settle();
      expect(h.timers.where((t) => t.isActive), isEmpty);

      await h.cubit.screenChanged(isInFront: true, isGuideActive: false);
      await h.settle();
      expect(h.source.reads.length, 3);
      expect(h.timers.where((t) => t.isActive), hasLength(1));
    });

    test('a guide on screen counts as not looking', () async {
      await h.open(
        loadedHome([topicItem('prod', isCritical: true)]),
        isGuideActive: true,
      );
      expect(h.cubit.state.phase, HomeSetupPhase.checklist);
      expect(h.cubit.watchedTopics, isEmpty);
    });

    test('with no topic there is nothing to poll', () async {
      await h.open(loadedHome());
      expect(h.cubit.watchedTopics, isEmpty);
      expect(h.timers, isEmpty);
    });

    test('a message that lands ticks the row and ends the poll', () async {
      h.source.everything['prod'] = const FirstMessagePage(
        candidates: [],
        newestId: 'm0',
      );
      await h.open(loadedHome([topicItem('prod', isCritical: true)]));
      expect(h.firstMessage.cursors['prod'], 'm0');

      h.source.later['prod'] = const FirstMessagePage(
        candidates: ['m1'],
        newestId: 'm1',
      );
      await h.fire(FirstMessageWatcher.interval);

      expect(h.firstMessage.isReceived, isTrue);
      expect(h.store.isDone, isTrue);
      expect(h.cubit.state.checklist.isComplete, isTrue);
      expect(h.cubit.watchedTopics, isEmpty);
      await h.fire(h.cubit.tickHold);
      expect(h.cubit.state.phase, HomeSetupPhase.celebration);
    });

    test(
      'a message on a topic that is not critical still ticks its row',
      () async {
        h.source.everything['cron'] = const FirstMessagePage(
          candidates: [],
          newestId: 'm0',
        );
        await h.open(loadedHome([topicItem('cron')]));
        expect(h.cubit.watchedTopics, ['cron']);
        h.source.later['cron'] = const FirstMessagePage(
          candidates: ['m1'],
          newestId: 'm1',
        );
        await h.fire(FirstMessageWatcher.interval);
        expect(h.cubit.state.phase, HomeSetupPhase.checklist);
        expect(h.cubit.state.checklist.hasFirstMessage, isTrue);
        expect(h.cubit.state.checklist.hasCriticalTopic, isFalse);
        expect(h.cubit.watchedTopics, isEmpty);
      },
    );

    test('closing the cubit ends every poll', () async {
      await h.open(loadedHome([topicItem('prod', isCritical: true)]));
      await h.cubit.close();
      expect(h.timers.where((t) => t.isActive), isEmpty);
    });
  });
}
