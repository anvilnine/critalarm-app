import 'package:critalarm/app/state/incidents_cubit.dart';
import 'package:critalarm/app/state/topics_cubit.dart';
import 'package:critalarm/core/alarm/alarm_host.dart';
import 'package:critalarm/core/api/mock_api_client.dart';
import 'package:critalarm/core/api/mock_server.dart';
import 'package:critalarm/core/models/incident.dart';
import 'package:critalarm/core/models/message.dart';
import 'package:critalarm/core/models/topic.dart';
import 'package:critalarm/design/faces/face_state.dart';
import 'package:critalarm/design/tokens/colors.dart';
import 'package:critalarm/features/incidents/data/repositories/in_memory_incident_repository.dart';
import 'package:critalarm/features/incidents/domain/usecases/get_incidents_usecase.dart';
import 'package:critalarm/features/topics/data/repositories/in_memory_topic_repository.dart';
import 'package:critalarm/features/topics/domain/usecases/get_topics_usecase.dart';
import 'package:critalarm/features/topics/domain/usecases/update_topic_usecase.dart';
import 'package:critalarm/features/topics/presentation/cubits/home_cubit.dart';
import 'package:critalarm/features/topics/presentation/cubits/topic_detail_cubit.dart';
import 'package:critalarm/features/topics/presentation/cubits/topic_detail_state.dart';
import 'package:critalarm/features/topics/presentation/cubits/topic_glances.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../core/alarm/fake_alarm_host.dart';

final DateTime _created = DateTime.utc(2026);

/// Whole seconds, because the server's messages carry no more.
final DateTime _now = DateTime.fromMillisecondsSinceEpoch(
  DateTime.now().millisecondsSinceEpoch ~/ 1000 * 1000,
);

int _seconds(DateTime at) => at.millisecondsSinceEpoch ~/ 1000;

Message _message(
  String topic,
  Duration ago, {
  int priority = 3,
  String? incidentId,
}) => Message(
  id: 'm-$topic-${ago.inSeconds}',
  topic: topic,
  time: _seconds(_now.subtract(ago)),
  priority: priority,
  incidentId: incidentId,
);

void main() {
  late MockServer server;
  late InMemoryIncidentRepository incidentRepo;
  late IncidentsCubit incidents;
  late TopicsCubit topics;
  late TopicGlances glances;

  setUp(() {
    server = MockServer()..reset();
    final api = MockApiClient(server);
    incidentRepo = InMemoryIncidentRepository(api);
    final topicRepo = InMemoryTopicRepository(api);
    incidents = IncidentsCubit(GetIncidentsUsecase(incidentRepo));
    topics = TopicsCubit(GetTopicsUsecase(topicRepo));
    glances = TopicGlances();
  });

  tearDown(() async {
    await incidents.close();
    await topics.close();
  });

  TopicDetailCubit build({AlarmHost? alarm, TopicGlances? memory}) {
    final cubit = TopicDetailCubit(
      incidents,
      topics,
      UpdateTopicUsecase(InMemoryTopicRepository(MockApiClient(server))),
      incidentRepo,
      alarm: alarm,
      glances: memory,
    );
    addTearDown(cubit.close);
    return cubit;
  }

  /// A calm topic, a critical one that is ringing, and a calm one whose only
  /// sign of a warning is a message of priority 4.
  void seedTopics() {
    server.seedState(
      topics: [
        Topic(name: 'calm', createdAt: _created),
        Topic(name: 'ringing', critical: true, createdAt: _created),
        Topic(name: 'warned', createdAt: _created),
      ],
      incidents: [
        Incident(
          id: 'i-ringing',
          topic: 'ringing',
          openedAt: _now.subtract(const Duration(minutes: 2)),
          updatedAt: _now.subtract(const Duration(minutes: 2)),
          messages: [
            _message(
              'ringing',
              const Duration(minutes: 2),
              priority: 5,
              incidentId: 'i-ringing',
            ),
          ],
        ),
      ],
      messages: [
        _message(
          'ringing',
          const Duration(minutes: 2),
          priority: 5,
          incidentId: 'i-ringing',
        ),
        _message('calm', const Duration(hours: 1)),
        _message('warned', const Duration(minutes: 20), priority: 4),
      ],
    );
  }

  Future<void> loadLists() =>
      Future.wait([incidents.ensureLoaded(), topics.ensureLoaded()]);

  group('seedFor', () {
    test('has nothing to say until both lists are loaded', () async {
      seedTopics();
      final cubit = build();
      expect(cubit.seedFor('calm'), isNull);
      await topics.ensureLoaded();
      expect(cubit.seedFor('calm'), isNull);
    });

    test('has nothing to say for a topic the lists do not hold', () async {
      seedTopics();
      await loadLists();
      expect(build().seedFor('nobody'), isNull);
    });

    test('carries Critical delivery and the canvas values', () async {
      seedTopics();
      await loadLists();
      final seed = build().seedFor('ringing')!;
      expect(seed.status, TopicDetailStatus.success);
      expect(seed.topicName, 'ringing');
      expect(seed.critical, isTrue);
      expect(seed.severity, SeverityMode.crit);
      expect(seed.faceState, FaceState.alarmed);
      expect(seed.openIncidentIds, ['i-ringing']);
      expect(seed.lastAlarmAt, _now.subtract(const Duration(minutes: 2)));
    });

    test('keeps Critical delivery off for a topic that has it off', () async {
      seedTopics();
      await loadLists();
      final seed = build().seedFor('calm')!;
      expect(seed.critical, isFalse);
      expect(seed.severity, SeverityMode.none);
      expect(seed.faceState, FaceState.calm);
    });

    test('leaves the messages loading when none were read yet', () async {
      seedTopics();
      await loadLists();
      final seed = build().seedFor('calm')!;
      expect(seed.isMessagesLoading, isTrue);
      expect(seed.showMessagesSkeleton, isTrue);
      expect(seed.areMessageTimesKnown, isFalse);
      expect(seed.messages, isEmpty);
    });

    test('shows a warning that only a message carries', () async {
      seedTopics();
      await loadLists();
      glances.rememberFromList(
        'warned',
        createdAt: _created,
        messageTimes: [_now.subtract(const Duration(minutes: 20))],
        hasHighMessage: true,
      );
      final seed = build(memory: glances).seedFor('warned')!;
      expect(seed.severity, SeverityMode.high);
      expect(seed.faceState, FaceState.worried);
      expect(seed.areMessageTimesKnown, isTrue);
      expect(seed.messageTimes, hasLength(1));
    });

    test('ignores a glance taken from an earlier topic of that name', () async {
      seedTopics();
      await loadLists();
      glances.rememberFromList(
        'warned',
        createdAt: DateTime.utc(2025, 6),
        messageTimes: const [],
        hasHighMessage: true,
      );
      final seed = build(memory: glances).seedFor('warned')!;
      expect(seed.severity, SeverityMode.none);
      expect(seed.areMessageTimesKnown, isFalse);
    });

    test('waits on the alarm permission, which the switch needs', () async {
      seedTopics();
      await loadLists();
      final fake = FakeAlarmHost();
      final cubit = build(alarm: fake.host);

      final before = cubit.seedFor('ringing')!;
      expect(before.status, TopicDetailStatus.loading);
      // The canvas values are still right while the card waits.
      expect(before.critical, isTrue);
      expect(before.severity, SeverityMode.crit);

      await fake.host.authorizationStatus();
      final after = cubit.seedFor('ringing')!;
      expect(after.status, TopicDetailStatus.success);
      expect(after.alarm, AlarmAuthorization.authorized);
      expect(after.canEditCritical, isTrue);
    });
  });

  group('load', () {
    test('a topic the lists hold opens on the seed', () async {
      seedTopics();
      await loadLists();
      final cubit = build();
      final seen = <TopicDetailState>[];
      cubit.stream.listen(seen.add);

      final loading = cubit.load('ringing');
      final first = cubit.state;
      await loading;

      expect(first, build().seedFor('ringing'));
      expect(first.status, TopicDetailStatus.success);
      expect(first.critical, isTrue);
      expect(seen.first, first);
    });

    test('without a seed it opens on the loading state', () async {
      seedTopics();
      final cubit = build();
      final loading = cubit.load('ringing');
      expect(
        cubit.state,
        const TopicDetailState(
          status: TopicDetailStatus.loading,
          topicName: 'ringing',
        ),
      );
      await loading;
      expect(cubit.state.status, TopicDetailStatus.success);
    });

    test('the loaded card and canvas match the seed, whatever the topic '
        'has not read yet', () async {
      seedTopics();
      await loadLists();
      for (final name in ['calm', 'ringing', 'warned']) {
        final cubit = build();
        final loading = cubit.load(name);
        final seed = cubit.state;
        await loading;
        final loaded = cubit.state;

        expect(loaded.topicName, seed.topicName, reason: name);
        expect(loaded.critical, seed.critical, reason: name);
        expect(loaded.alarm, seed.alarm, reason: name);
        expect(loaded.openIncidentIds, seed.openIncidentIds, reason: name);
        expect(loaded.lastAlarmAt, seed.lastAlarmAt, reason: name);
        expect(loaded.status, seed.status, reason: name);
      }
      // A warning that rides on a message alone is the one value the seed
      // cannot know before the messages are read once.
      final warned = build();
      await warned.load('warned');
      expect(warned.state.severity, SeverityMode.high);
    });

    test('a topic read before opens equal to how it ends up', () async {
      seedTopics();
      await loadLists();
      // The list has read every topic's messages.
      final home = HomeCubit(
        incidents,
        topics,
        incidentRepo,
        null,
        null,
        () => _now,
        const Duration(seconds: 5),
        null,
        glances,
      );
      addTearDown(home.close);
      await home.load();

      for (final name in ['calm', 'ringing', 'warned']) {
        // Opened once from the list, then again.
        final first = build(memory: glances);
        final loading = first.load(name);
        final seed = first.state;
        await loading;
        final seen = <TopicDetailState>[];
        final second = build(memory: glances);
        second.stream.listen(seen.add);
        final reopening = second.load(name);
        final opened = second.state;
        await reopening;

        expect(opened.severity, first.state.severity, reason: name);
        expect(opened.messageTimes, first.state.messageTimes, reason: name);
        expect(seed.severity, first.state.severity, reason: name);
        // The rows the first visit read are on the second one's first frame,
        // and reading again changes nothing.
        expect(opened, first.state, reason: name);
        expect(second.state, opened, reason: name);
        expect(seen, [opened], reason: name);
      }
    });

    test('a refresh that returns the same data emits nothing', () async {
      seedTopics();
      await loadLists();
      final cubit = build(memory: glances);
      await cubit.load('ringing');
      final settled = cubit.state;

      final seen = <TopicDetailState>[];
      cubit.stream.listen(seen.add);
      expect(await cubit.refresh(), isTrue);

      expect(seen, isEmpty);
      expect(cubit.state, settled);
    });

    test('a refresh that returns new data changes the state', () async {
      seedTopics();
      await loadLists();
      final cubit = build(memory: glances);
      await cubit.load('calm');
      expect(cubit.state.critical, isFalse);

      server.seedState(topics: [const Topic(name: 'calm', critical: true)]);
      await cubit.refresh();
      expect(cubit.state.critical, isTrue);
    });
  });

  group('TopicGlances', () {
    test('answers only for the topic it was taken from', () {
      glances.remember(
        'a',
        TopicGlance(
          topicCreatedAt: _created,
          messageTimes: const [],
          hasHighMessage: false,
        ),
      );
      expect(glances.of('a', createdAt: _created), isNotNull);
      expect(glances.of('a', createdAt: DateTime.utc(2026, 2)), isNull);
      expect(glances.of('b', createdAt: _created), isNull);
    });

    test('a list read of the same messages keeps the remembered rows', () {
      final times = [_now];
      glances
        ..remember(
          'a',
          TopicGlance(
            topicCreatedAt: _created,
            messageTimes: times,
            hasHighMessage: false,
            messages: const [
              TopicDetailMessageItem(
                title: 't',
                timestamp: '02:41',
                body: 'b',
                source: '',
              ),
            ],
          ),
        )
        ..rememberFromList(
          'a',
          createdAt: _created,
          messageTimes: [_now],
          hasHighMessage: false,
        );
      expect(glances.of('a', createdAt: _created)!.messages, hasLength(1));

      glances.rememberFromList(
        'a',
        createdAt: _created,
        messageTimes: [_now, _now.subtract(const Duration(minutes: 1))],
        hasHighMessage: false,
      );
      expect(glances.of('a', createdAt: _created)!.messages, isNull);
    });
  });

  group('Home fills the glances', () {
    test('with the last 7 days of each topic', () async {
      server.seedState(
        topics: [
          Topic(name: 'fresh', createdAt: _created),
          Topic(name: 'stale', createdAt: _created),
        ],
        messages: [
          _message('fresh', const Duration(minutes: 5), priority: 4),
          _message('stale', const Duration(days: 9), priority: 4),
        ],
      );
      await loadLists();
      final home = HomeCubit(
        incidents,
        topics,
        incidentRepo,
        null,
        null,
        () => _now,
        const Duration(seconds: 5),
        null,
        glances,
      );
      addTearDown(home.close);
      await home.load();

      final fresh = glances.of('fresh', createdAt: _created)!;
      expect(fresh.hasHighMessage, isTrue);
      expect(fresh.messageTimes, hasLength(1));
      // A message past what the free plan shows is not a warning to draw.
      final stale = glances.of('stale', createdAt: _created)!;
      expect(stale.hasHighMessage, isFalse);
      expect(stale.messageTimes, isEmpty);
    });
  });
}
