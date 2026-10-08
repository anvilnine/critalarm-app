import 'package:critalarm/app/state/incidents_cubit.dart';
import 'package:critalarm/app/state/topics_cubit.dart';
import 'package:critalarm/core/api/mock_api_client.dart';
import 'package:critalarm/core/api/mock_server.dart';
import 'package:critalarm/core/failures/failure.dart';
import 'package:critalarm/core/models/incident.dart';
import 'package:critalarm/core/models/message.dart';
import 'package:critalarm/core/models/topic.dart';
import 'package:critalarm/core/result/result.dart';
import 'package:critalarm/features/incidents/data/repositories/in_memory_incident_repository.dart';
import 'package:critalarm/features/incidents/domain/usecases/get_incidents_usecase.dart';
import 'package:critalarm/features/onboarding/domain/entities/server_connection.dart';
import 'package:critalarm/features/onboarding/domain/repositories/connection_repository.dart';
import 'package:critalarm/features/onboarding/domain/usecases/get_connection_usecase.dart';
import 'package:critalarm/features/topics/data/repositories/in_memory_topic_repository.dart';
import 'package:critalarm/features/topics/domain/home_card/home_facts.dart';
import 'package:critalarm/features/topics/domain/home_card/inbox_order.dart';
import 'package:critalarm/features/topics/domain/repositories/topic_list_prefs_repository.dart';
import 'package:critalarm/features/topics/domain/repositories/topic_repository.dart';
import 'package:critalarm/features/topics/domain/usecases/get_topics_usecase.dart';
import 'package:critalarm/features/topics/presentation/cubits/home_cubit.dart';
import 'package:critalarm/features/topics/presentation/cubits/home_state.dart';
import 'package:flutter_test/flutter_test.dart';

class _MemoryPrefs implements TopicListPrefsRepository {
  final Set<String> pinnedSet = {};
  final Set<String> mutedSet = {};
  final Map<String, DateTime> read = {};

  @override
  Set<String> pinned() => {...pinnedSet};

  @override
  Set<String> muted() => {...mutedSet};

  @override
  DateTime? lastReadAt(String topic) => read[topic];

  @override
  Future<void> setPinned(String topic, {required bool pinned}) async =>
      pinned ? pinnedSet.add(topic) : pinnedSet.remove(topic);

  @override
  Future<void> setMuted(String topic, {required bool muted}) async =>
      muted ? mutedSet.add(topic) : mutedSet.remove(topic);

  @override
  Future<void> markRead(String topic, DateTime at) async => read[topic] = at;
}

/// A topic list that answers until [fails] is turned on.
class _FlakyTopics implements TopicRepository {
  _FlakyTopics(this._inner);

  final TopicRepository _inner;
  bool fails = false;

  @override
  Future<AppResult<List<Topic>>> getTopics() async => fails
      ? const Failure.api(statusCode: 500).toFailure()
      : _inner.getTopics();

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

class _Connections implements ConnectionRepository {
  _Connections(this.connection);

  ServerConnection? connection;

  @override
  Future<AppResult<ServerConnection>> getConnection() async {
    final saved = connection;
    return saved == null
        ? const Failure.notFound().toFailure()
        : saved.toSuccess();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

const _server = ServerConnection(
  serverUrl: 'https://api.critalarm.app',
  adminToken: 'tk_test',
);

/// Whole seconds, because the server's messages carry no more.
final DateTime _base = DateTime.fromMillisecondsSinceEpoch(
  DateTime.now().millisecondsSinceEpoch ~/ 1000 * 1000,
);

DateTime _ago(Duration d) => _base.subtract(d);

int _seconds(DateTime at) => at.millisecondsSinceEpoch ~/ 1000;

Message _msg(
  String topic,
  Duration ago, {
  int priority = 3,
  String? incidentId,
  List<String> tags = const [],
}) => Message(
  id: 'm-$topic-${ago.inSeconds}',
  topic: topic,
  time: _seconds(_ago(ago)),
  priority: priority,
  incidentId: incidentId,
  tags: tags,
);

Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  late MockServer server;
  late MockApiClient api;
  late InMemoryIncidentRepository incidentRepo;
  late IncidentsCubit incidentsCubit;
  late TopicsCubit topicsCubit;
  late _MemoryPrefs prefs;
  late HomeCubit cubit;

  void build({
    TopicsCubit? topics,
    GetConnectionUsecase? connection,
    DateTime Function()? clock,
  }) {
    cubit = HomeCubit(
      incidentsCubit,
      topics ?? topicsCubit,
      incidentRepo,
      null,
      connection,
      clock,
      const Duration(seconds: 5),
      prefs,
    );
  }

  setUp(() {
    server = MockServer()..reset();
    api = MockApiClient(server);
    incidentRepo = InMemoryIncidentRepository(api);
    incidentsCubit = IncidentsCubit(GetIncidentsUsecase(incidentRepo));
    topicsCubit = TopicsCubit(GetTopicsUsecase(InMemoryTopicRepository(api)));
    prefs = _MemoryPrefs();
  });

  tearDown(() async {
    await cubit.close();
    await incidentsCubit.close();
    await topicsCubit.close();
  });

  HomeTopicItem item(String name) =>
      cubit.state.topicItems.firstWhere((t) => t.name == name);

  /// One topic for each state a row can be in, plus plain ones.
  void seedEveryState() {
    server.seedState(
      topics: const [
        Topic(name: 'ring', critical: true),
        Topic(name: 'ack', critical: true),
        Topic(name: 'warn'),
        Topic(name: 'miss', critical: true),
        Topic(name: 'done', critical: true),
        Topic(name: 'plain'),
      ],
      incidents: [
        Incident(
          id: 'i-ring',
          topic: 'ring',
          openedAt: _ago(const Duration(minutes: 2)),
          updatedAt: _ago(const Duration(minutes: 2)),
          messages: [
            _msg(
              'ring',
              const Duration(minutes: 2),
              priority: 5,
              incidentId: 'i-ring',
            ),
          ],
        ),
        Incident(
          id: 'i-ack',
          topic: 'ack',
          state: IncidentStates.acked,
          openedAt: _ago(const Duration(minutes: 5)),
          ackedAt: _ago(const Duration(minutes: 1)),
          deskTimerFiresAt: _base.add(const Duration(minutes: 9)),
          updatedAt: _ago(const Duration(minutes: 1)),
          messages: [
            _msg(
              'ack',
              const Duration(minutes: 5),
              priority: 5,
              incidentId: 'i-ack',
            ),
          ],
        ),
        Incident(
          id: 'i-miss',
          topic: 'miss',
          state: IncidentStates.expired,
          openedAt: _ago(const Duration(minutes: 40)),
          closedAt: _ago(const Duration(minutes: 10)),
          updatedAt: _ago(const Duration(minutes: 10)),
          messages: [
            _msg(
              'miss',
              const Duration(minutes: 40),
              priority: 5,
              incidentId: 'i-miss',
            ),
          ],
        ),
        Incident(
          id: 'i-done',
          topic: 'done',
          state: IncidentStates.closed,
          openedAt: _ago(const Duration(minutes: 20)),
          ackedAt: _ago(const Duration(minutes: 19, seconds: 49)),
          closedAt: _ago(const Duration(minutes: 5)),
          updatedAt: _ago(const Duration(minutes: 5)),
          messages: [
            _msg(
              'done',
              const Duration(minutes: 20),
              priority: 5,
              incidentId: 'i-done',
            ),
          ],
        ),
      ],
      messages: [
        _msg('ring', const Duration(minutes: 2), priority: 5),
        _msg('ack', const Duration(minutes: 5), priority: 5),
        _msg('warn', const Duration(minutes: 20), priority: 4),
        _msg('miss', const Duration(minutes: 40), priority: 5),
        _msg('done', const Duration(minutes: 20), priority: 5),
        _msg('plain', const Duration(hours: 3)),
      ],
    );
  }

  group('a row knows when its newest message came in', () {
    test('the time of the newest message, or null for none', () async {
      server.seedState(
        topics: const [
          Topic(name: 'busy'),
          Topic(name: 'empty'),
        ],
        messages: [
          _msg('busy', const Duration(hours: 5)),
          _msg('busy', const Duration(hours: 1)),
          _msg('busy', const Duration(hours: 3)),
        ],
      );
      build();
      await cubit.load();
      expect(item('busy').lastMessageAt, _ago(const Duration(hours: 1)));
      expect(item('empty').lastMessageAt, isNull);
    });
  });

  group('a row knows what state it is in', () {
    test('from the real incidents and messages', () async {
      seedEveryState();
      build();
      await cubit.load();
      expect(item('ring').rowKind, InboxRowKind.ringing);
      expect(item('ack').rowKind, InboxRowKind.acknowledged);
      expect(item('warn').rowKind, InboxRowKind.warning);
      expect(item('miss').rowKind, InboxRowKind.missed);
      expect(item('done').rowKind, InboxRowKind.handled);
      expect(item('plain').rowKind, InboxRowKind.normal);
    });

    test(
      'an acknowledgement whose desk timer ran out is a plain row',
      () async {
        seedEveryState();
        // Ten minutes after the deadline the server gave.
        build(clock: () => _base.add(const Duration(minutes: 19)));
        await cubit.load();
        expect(item('ack').rowKind, InboxRowKind.normal);
      },
    );

    test('a handled row goes back to plain after an hour', () async {
      seedEveryState();
      build(clock: () => _base.add(const Duration(hours: 2)));
      await cubit.load();
      expect(item('done').rowKind, InboxRowKind.normal);
    });
  });

  group('the inbox order', () {
    void seedOrder() {
      server.seedState(
        topics: const [
          Topic(name: 'newest'),
          Topic(name: 'middle'),
          Topic(name: 'oldest'),
          Topic(name: 'silent'),
          Topic(name: 'pinned'),
          Topic(name: 'unread'),
          Topic(name: 'muted'),
          Topic(name: 'ring', critical: true),
          Topic(name: 'warn'),
        ],
        incidents: [
          Incident(
            id: 'i-ring',
            topic: 'ring',
            openedAt: _ago(const Duration(hours: 11)),
            updatedAt: _ago(const Duration(hours: 11)),
            messages: [
              _msg(
                'ring',
                const Duration(hours: 11),
                priority: 5,
                incidentId: 'i-ring',
              ),
            ],
          ),
        ],
        messages: [
          _msg('ring', const Duration(hours: 11), priority: 5),
          _msg('warn', const Duration(minutes: 10), priority: 4),
          _msg('newest', const Duration(hours: 1)),
          _msg('middle', const Duration(hours: 3)),
          _msg('oldest', const Duration(hours: 6)),
          _msg('pinned', const Duration(hours: 9)),
          _msg('unread', const Duration(hours: 8)),
          _msg('muted', const Duration(minutes: 5)),
        ],
      );
    }

    test('needs-you rows, then pinned, unread, the rest, then muted', () async {
      seedOrder();
      prefs
        ..pinnedSet.add('pinned')
        ..mutedSet.add('muted')
        ..read['unread'] = DateTime.fromMillisecondsSinceEpoch(0);
      build();
      await cubit.load();
      expect(
        [for (final t in cubit.state.topicItems) t.name],
        [
          'ring',
          'warn',
          'pinned',
          'unread',
          'newest',
          'middle',
          'oldest',
          'silent',
          'muted',
        ],
      );
    });

    test('a pinned topic does not push a sounding one down', () async {
      seedOrder();
      prefs.pinnedSet.add('oldest');
      build();
      await cubit.load();
      final names = [for (final t in cubit.state.topicItems) t.name];
      expect(names.indexOf('ring'), lessThan(names.indexOf('oldest')));
      expect(names.indexOf('warn'), lessThan(names.indexOf('oldest')));
    });

    test('a muted topic that needs you does not sink', () async {
      seedOrder();
      prefs.mutedSet.add('ring');
      build();
      await cubit.load();
      expect(cubit.state.topicItems.first.name, 'ring');
    });

    test('a pin moves a row and the order follows', () async {
      seedOrder();
      build();
      await cubit.load();
      expect(item('oldest').isPinned, isFalse);
      await cubit.togglePin('oldest');
      final names = [for (final t in cubit.state.topicItems) t.name];
      expect(names.indexOf('oldest'), 2);
    });
  });

  group('the facts in the state', () {
    test('hold the live alarm and the times for the card', () async {
      seedEveryState();
      build();
      await cubit.load();
      final facts = cubit.state.facts;
      expect(facts.ringing?.incidentId, 'i-ring');
      expect(facts.ringing?.topic, 'ring');
      expect(facts.acknowledged?.incidentId, 'i-ack');
      expect(
        facts.acknowledged?.deadline,
        _base.add(const Duration(minutes: 9)),
      );
      expect(facts.warningCount, 1);
      expect(facts.newestMessageAt, _ago(const Duration(minutes: 2)));
      expect(facts.lastAlarmAt, _ago(const Duration(minutes: 2)));
      // Closed five minutes ago: past the short moment the card keeps.
      expect(facts.handled, isNull);
    });

    test('hold the handled moment with how long the answer took', () async {
      server.seedState(
        topics: const [Topic(name: 'done', critical: true)],
        incidents: [
          Incident(
            id: 'i-done',
            topic: 'done',
            state: IncidentStates.closed,
            openedAt: _ago(const Duration(seconds: 40)),
            ackedAt: _ago(const Duration(seconds: 29)),
            closedAt: _ago(const Duration(seconds: 5)),
            updatedAt: _ago(const Duration(seconds: 5)),
            messages: [
              _msg(
                'done',
                const Duration(seconds: 40),
                priority: 5,
                incidentId: 'i-done',
              ),
            ],
          ),
        ],
      );
      build();
      await cubit.load();
      expect(cubit.state.facts.handled?.topic, 'done');
      expect(
        cubit.state.facts.handled?.answeredAfter,
        const Duration(seconds: 11),
      );
    });

    test('name an alarm setup rang as the last alarm', () async {
      server.seedState(
        topics: const [Topic(name: 'prod-db', critical: true)],
        incidents: [
          Incident(
            id: 'real',
            topic: 'prod-db',
            state: IncidentStates.closed,
            openedAt: _ago(const Duration(days: 2)),
            closedAt: _ago(const Duration(days: 2)),
            updatedAt: _ago(const Duration(days: 2)),
          ),
          Incident(
            id: 'setup',
            topic: 'prod-db',
            state: IncidentStates.closed,
            openedAt: _ago(const Duration(hours: 1)),
            closedAt: _ago(const Duration(hours: 1)),
            updatedAt: _ago(const Duration(hours: 1)),
          ),
        ],
      );
      build();
      await cubit.load();
      expect(cubit.state.facts.lastAlarmAt, _ago(const Duration(hours: 1)));
    });

    test('are empty for a server with no topics', () async {
      build();
      await cubit.load();
      expect(cubit.state.status, HomeStatus.success);
      expect(cubit.state.facts, HomeFacts.none);
    });

    test('drop what is live when the server stops answering', () async {
      seedEveryState();
      final flaky = _FlakyTopics(InMemoryTopicRepository(api));
      final flakyCubit = TopicsCubit(GetTopicsUsecase(flaky));
      addTearDown(flakyCubit.close);
      build(
        topics: flakyCubit,
        connection: GetConnectionUsecase(_Connections(_server)),
      );
      await cubit.load();
      await _settle();
      expect(cubit.state.facts.ringing, isNotNull);

      flaky.fails = true;
      await cubit.refresh();
      await _settle();

      expect(cubit.state.isStale, isTrue);
      final facts = cubit.state.facts;
      expect(facts.ringing, isNull);
      expect(facts.acknowledged, isNull);
      expect(facts.warningCount, 0);
      expect(facts.newestMessageAt, _ago(const Duration(minutes: 2)));
    });

    test('are cleared when no server is saved', () async {
      seedEveryState();
      final flaky = _FlakyTopics(InMemoryTopicRepository(api));
      final flakyCubit = TopicsCubit(GetTopicsUsecase(flaky));
      addTearDown(flakyCubit.close);
      final connections = _Connections(_server);
      build(topics: flakyCubit, connection: GetConnectionUsecase(connections));
      await cubit.load();
      await _settle();

      flaky.fails = true;
      connections.connection = null;
      await cubit.refresh();
      await _settle();

      expect(cubit.state.hasServer, isFalse);
      expect(cubit.state.facts, HomeFacts.none);
    });

    test('a read after a pin keeps the facts', () async {
      seedEveryState();
      build();
      await cubit.load();
      final before = cubit.state.facts;
      await cubit.togglePin('plain');
      expect(cubit.state.facts, before);
    });
  });
}
