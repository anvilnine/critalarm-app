import 'package:critalarm/app/state/incidents_cubit.dart';
import 'package:critalarm/app/state/topics_cubit.dart';
import 'package:critalarm/core/api/mock_api_client.dart';
import 'package:critalarm/core/api/mock_server.dart';
import 'package:critalarm/core/models/incident.dart';
import 'package:critalarm/core/store/local_store.dart';
import 'package:critalarm/features/incidents/data/repositories/in_memory_incident_repository.dart';
import 'package:critalarm/features/incidents/domain/usecases/get_incidents_usecase.dart';
import 'package:critalarm/features/topics/data/repositories/in_memory_topic_repository.dart';
import 'package:critalarm/features/topics/domain/usecases/get_topics_usecase.dart';
import 'package:critalarm/features/topics/domain/usecases/update_topic_usecase.dart';
import 'package:critalarm/features/topics/presentation/cubits/topic_detail_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  test(
    'a 409 on ack pulls the server copy so the phone stops calling it open',
    () async {
      final store = await LocalStore.open(
        factory: databaseFactoryFfi,
        path: inMemoryDatabasePath,
      );
      addTearDown(store.close);
      final server = MockServer()..seedAlarmed();
      final api = MockApiClient(server);
      final repository = InMemoryIncidentRepository(api, store: store);
      final incidents = IncidentsCubit(
        GetIncidentsUsecase(repository),
        saveIncident: repository.saveIncident,
      );
      addTearDown(incidents.close);
      final topicRepo = InMemoryTopicRepository(api);
      final topics = TopicsCubit(GetTopicsUsecase(topicRepo));
      addTearDown(topics.close);
      final cubit = TopicDetailCubit(
        incidents,
        topics,
        UpdateTopicUsecase(topicRepo),
        repository,
      );
      addTearDown(cubit.close);

      const id = 'inc_alarmed_proddb';
      await cubit.load('prod-db');
      expect(cubit.state.openIncidentIds, contains(id));

      // The server expires the incident behind the phone's back, and a list
      // read with `since` never mentions it again. That is what a server on
      // contract 1.16 does: it filters on opened_at. The mock filters on
      // updated_at, so the copy gets an updated_at before the phone's cursor
      // to make the mock answer the same way.
      final held = server.getIncident(id);
      server.seedState(
        incidents: [
          held.copyWith(
            state: IncidentStates.expired,
            closedAt: DateTime.now().toUtc(),
            updatedAt: held.openedAt,
          ),
        ],
      );

      await cubit.markAsRead();

      final shared = incidents.state.incidents.firstWhere((i) => i.id == id);
      expect(shared.isOpen, isFalse, reason: 'shared list still says open');

      final stored = (await store.incidents.page()).firstWhere(
        (i) => i.id == id,
      );
      expect(stored.isOpen, isFalse, reason: 'store row still says open');
    },
  );
}
