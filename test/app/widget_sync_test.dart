import 'dart:convert';

import 'package:critalarm/app/state/incidents_cubit.dart';
import 'package:critalarm/app/state/topics_cubit.dart';
import 'package:critalarm/app/widget_sync.dart';
import 'package:critalarm/core/account/account_identity_changes.dart';
import 'package:critalarm/core/result/result.dart';
import 'package:critalarm/core/widgets/widget_host.dart';
import 'package:critalarm/features/incidents/domain/entities/incident.dart';
import 'package:critalarm/features/incidents/domain/repositories/incident_repository.dart';
import 'package:critalarm/features/incidents/domain/usecases/get_incidents_usecase.dart';
import 'package:critalarm/features/topics/domain/entities/topic.dart';
import 'package:critalarm/features/topics/domain/repositories/topic_repository.dart';
import 'package:critalarm/features/topics/domain/usecases/get_topics_usecase.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class _Topics implements TopicRepository {
  List<Topic> topics = const [];

  @override
  Future<AppResult<List<Topic>>> getTopics() async => topics.toSuccess();

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

class _Incidents implements IncidentRepository {
  List<Incident> incidents = const [];

  @override
  Future<AppResult<List<Incident>>> getIncidents({
    required int limit,
    String? state,
    String? topic,
    DateTime? since,
    bool fullRefresh = false,
  }) async => incidents.toSuccess();

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

/// The write goes timer, then connection check, then channel. A few turns of
/// the event loop cover all three.
Future<void> settle() async {
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel(WidgetHost.channelName);
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late List<MethodCall> calls;
  late _Topics topicRepo;
  late _Incidents incidentRepo;
  late TopicsCubit topics;
  late IncidentsCubit incidents;
  late WidgetSync sync;
  late bool connected;
  var clock = DateTime.utc(2026, 9, 25);

  Map<String, dynamic> written(int index) =>
      jsonDecode(
            (calls[index].arguments as Map<Object?, Object?>)['json']!
                as String,
          )
          as Map<String, dynamic>;

  setUp(() {
    calls = [];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return null;
    });
    connected = true;
    clock = DateTime.utc(2026, 9, 25);
    topicRepo = _Topics()..topics = const [Topic(name: 'prod')];
    incidentRepo = _Incidents()
      ..incidents = [
        Incident(id: 'inc_1', topic: 'prod', openedAt: DateTime.utc(2026)),
      ];
    final identity = AccountIdentityChanges();
    topics = TopicsCubit(
      GetTopicsUsecase(topicRepo),
      identityChanges: identity,
    );
    incidents = IncidentsCubit(
      GetIncidentsUsecase(incidentRepo),
      identityChanges: identity,
    );
    sync = WidgetSync(
      topics: topics,
      incidents: incidents,
      host: const WidgetHost(),
      isConnected: () async => connected,
      now: () => clock,
      debounce: Duration.zero,
    )..start();
  });

  tearDown(() async {
    await sync.dispose();
    await topics.close();
    await incidents.close();
    messenger.setMockMethodCallHandler(channel, null);
  });

  test('nothing is written until both lists are ready', () async {
    await topics.refresh();
    await settle();
    expect(calls, isEmpty);

    await incidents.refresh();
    await settle();
    expect(calls, hasLength(1));
    expect(calls.single.method, 'write');
    expect(written(0)['open_count'], 1);
    expect(written(0)['connected'], isTrue);
  });

  test('the same content is not written twice, even a second later', () async {
    await topics.refresh();
    await incidents.refresh();
    await settle();
    clock = clock.add(const Duration(seconds: 1));

    await topics.refresh();
    await incidents.refresh();
    await settle();

    expect(calls, hasLength(1));
  });

  test('a change is written', () async {
    await topics.refresh();
    await incidents.refresh();
    await settle();

    incidents.applyIncident(
      Incident(
        id: 'inc_1',
        topic: 'prod',
        state: IncidentStates.acked,
        openedAt: DateTime.utc(2026),
        ackedAt: DateTime.utc(2026, 1, 2),
      ),
    );
    await settle();

    expect(calls, hasLength(2));
    final topic = (written(1)['topics'] as List).single as Map;
    expect((topic['incident'] as Map)['state'], 'acked');
  });

  test('not connected writes the disconnected shape', () async {
    connected = false;
    await topics.refresh();
    await incidents.refresh();
    await settle();

    expect(written(0), {
      'v': 1,
      'updated_at': clock.millisecondsSinceEpoch ~/ 1000,
      'connected': false,
      'open_count': 0,
      'topics': <Object?>[],
    });
  });
}
