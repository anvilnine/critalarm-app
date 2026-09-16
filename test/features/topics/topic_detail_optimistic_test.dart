import 'dart:async';

import 'package:critalarm/app/state/incidents_cubit.dart';
import 'package:critalarm/app/state/topics_cubit.dart';
import 'package:critalarm/core/api/mock_api_client.dart';
import 'package:critalarm/core/api/mock_server.dart';
import 'package:critalarm/core/failures/failure.dart';
import 'package:critalarm/features/incidents/domain/entities/incident.dart';
import 'package:critalarm/features/incidents/domain/usecases/get_incidents_usecase.dart';
import 'package:critalarm/features/topics/data/repositories/in_memory_topic_repository.dart';
import 'package:critalarm/features/topics/domain/repositories/topic_repository.dart';
import 'package:critalarm/features/topics/domain/usecases/get_topics_usecase.dart';
import 'package:critalarm/features/topics/domain/usecases/update_topic_usecase.dart';
import 'package:critalarm/features/topics/presentation/cubits/topic_detail_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/scripted_incident_repository.dart';

Incident _open(String id) => Incident(
  id: id,
  topic: 'prod-db',
  openedAt: DateTime.now().subtract(const Duration(minutes: 2)),
);

void main() {
  late ScriptedIncidentRepository repository;
  late IncidentsCubit incidents;
  late TopicDetailCubit cubit;

  Future<void> build() async {
    final api = MockApiClient(MockServer()..seedCalm());
    final TopicRepository topics = InMemoryTopicRepository(api);
    incidents = IncidentsCubit(GetIncidentsUsecase(repository));
    addTearDown(incidents.close);
    final topicsCubit = TopicsCubit(GetTopicsUsecase(topics));
    addTearDown(topicsCubit.close);

    cubit = TopicDetailCubit(
      incidents,
      topicsCubit,
      UpdateTopicUsecase(topics),
      repository,
    );
    addTearDown(cubit.close);
    await cubit.load('prod-db');
  }

  Map<String, Incident> shared() => {
    for (final incident in incidents.state.incidents) incident.id: incident,
  };

  setUp(() {
    repository = ScriptedIncidentRepository([_open('inc_a'), _open('inc_b')]);
  });

  test('the shared list clears before the acknowledges answer', () async {
    await build();
    expect(cubit.state.openIncidentIds, ['inc_a', 'inc_b']);
    repository.gate = Completer<void>();

    final marking = cubit.markAsRead();
    await pumpEventQueue();

    expect(
      incidents.state.openIncidents,
      isEmpty,
      reason: 'Home, History and search read this list',
    );
    expect(cubit.state.openIncidentIds, isEmpty);
    expect(cubit.state.isMarkingAsRead, isFalse);

    repository.gate!.complete();
    await marking;

    expect(incidents.state.openIncidents, isEmpty);
    expect(cubit.state.errorMessage, isNull);
  });

  test('a partial failure leaves the right incident open', () async {
    repository.refuse['inc_b'] = const Failure.api(statusCode: 500);
    await build();

    await cubit.markAsRead();

    expect(shared()['inc_a']!.isAcked, isTrue);
    expect(shared()['inc_b']!.isOpen, isTrue);
    expect(cubit.state.openIncidentIds, ['inc_b']);
    expect(cubit.state.errorMessage, isNotNull);
  });

  test('a 409 counts as acknowledged, not as a failure', () async {
    repository.refuse['inc_b'] = const Failure.api(statusCode: 409);
    await build();

    await cubit.markAsRead();

    expect(
      shared()['inc_b']!.isAcked,
      isTrue,
      reason: 'it was acknowledged somewhere else',
    );
    expect(cubit.state.openIncidentIds, isEmpty);
    expect(cubit.state.errorMessage, isNull);
  });
}
