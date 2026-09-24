import 'package:critalarm/app/state/incidents_cubit.dart';
import 'package:critalarm/app/state/topics_cubit.dart';
import 'package:critalarm/core/api/mock_api_client.dart';
import 'package:critalarm/core/api/mock_server.dart';
import 'package:critalarm/features/incidents/data/repositories/in_memory_incident_repository.dart';
import 'package:critalarm/features/incidents/domain/usecases/get_incidents_usecase.dart';
import 'package:critalarm/features/topics/data/repositories/in_memory_topic_repository.dart';
import 'package:critalarm/features/topics/domain/repositories/topic_list_prefs_repository.dart';
import 'package:critalarm/features/topics/domain/usecases/get_topics_usecase.dart';
import 'package:critalarm/features/topics/presentation/cubits/home_cubit.dart';
import 'package:critalarm/features/topics/presentation/cubits/home_state.dart';
import 'package:flutter_test/flutter_test.dart';

class _MemoryPrefs implements TopicListPrefsRepository {
  final Set<String> _pinned = {};
  final Set<String> _muted = {};
  final Map<String, DateTime> _read = {};

  @override
  Set<String> pinned() => {..._pinned};

  @override
  Set<String> muted() => {..._muted};

  @override
  DateTime? lastReadAt(String topic) => _read[topic];

  @override
  Future<void> setPinned(String topic, {required bool pinned}) async =>
      pinned ? _pinned.add(topic) : _pinned.remove(topic);

  @override
  Future<void> setMuted(String topic, {required bool muted}) async =>
      muted ? _muted.add(topic) : _muted.remove(topic);

  @override
  Future<void> markRead(String topic, DateTime at) async => _read[topic] = at;
}

void main() {
  late MockServer server;
  late IncidentsCubit incidentsCubit;
  late TopicsCubit topicsCubit;
  late InMemoryIncidentRepository incidentRepo;
  late _MemoryPrefs prefs;
  late HomeCubit cubit;

  setUp(() {
    server = MockServer()..seedCalm();
    final api = MockApiClient(server);
    incidentRepo = InMemoryIncidentRepository(api);
    incidentsCubit = IncidentsCubit(GetIncidentsUsecase(incidentRepo));
    topicsCubit = TopicsCubit(
      GetTopicsUsecase(InMemoryTopicRepository(api)),
    );
    prefs = _MemoryPrefs();
    cubit = HomeCubit(
      incidentsCubit,
      topicsCubit,
      incidentRepo,
      null,
      null,
      null,
      const Duration(seconds: 5),
      prefs,
    );
  });

  tearDown(() async {
    await cubit.close();
    await incidentsCubit.close();
    await topicsCubit.close();
  });

  HomeTopicItem item(String name) =>
      cubit.state.topicItems.firstWhere((t) => t.name == name);

  test('the first load marks every topic read, so nothing is unread', () async {
    await cubit.load();
    expect(cubit.state.topicItems, isNotEmpty);
    expect(cubit.state.topicItems.every((t) => t.unreadCount == 0), isTrue);
    for (final t in cubit.state.topicItems) {
      expect(prefs.lastReadAt(t.name), isNotNull);
    }
  });

  test('a topic with messages shows the newest one as its preview', () async {
    await cubit.load();
    expect(item('prod-db').preview, isNotEmpty);
  });

  test('messages after the read mark count as unread, and mark read clears '
      'them', () async {
    await prefs.markRead('prod-db', DateTime.fromMillisecondsSinceEpoch(0));
    await cubit.load();
    expect(item('prod-db').unreadCount, greaterThan(0));

    await cubit.markRead('prod-db');
    expect(item('prod-db').unreadCount, 0);
  });

  test('pinning moves a topic to the top, unpinning lets it go', () async {
    await cubit.load();
    final last = cubit.state.topicItems.last.name;

    await cubit.togglePin(last);
    expect(cubit.state.topicItems.first.name, last);
    expect(item(last).isPinned, isTrue);

    await cubit.togglePin(last);
    expect(item(last).isPinned, isFalse);
  });

  test('muting greys a quiet topic, hides its count and moves it '
      'last', () async {
    await prefs.markRead('prod-db', DateTime.fromMillisecondsSinceEpoch(0));
    await cubit.load();
    expect(item('prod-db').isLive, isFalse);

    await cubit.toggleMute('prod-db');
    expect(item('prod-db').isMuted, isTrue);
    expect(item('prod-db').unreadCount, 0);
    expect(cubit.state.topicItems.last.name, 'prod-db');

    await cubit.toggleMute('prod-db');
    expect(item('prod-db').isMuted, isFalse);
    expect(item('prod-db').unreadCount, greaterThan(0));
  });
}
