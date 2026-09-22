import 'package:critalarm/app/state/incidents_cubit.dart';
import 'package:critalarm/app/state/topics_cubit.dart';
import 'package:critalarm/core/api/mock_api_client.dart';
import 'package:critalarm/core/api/mock_server.dart';
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
    'markAsRead then a refresh leaves the incident acked (Z repro)',
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

      await cubit.load('prod-db');
      expect(cubit.state.openIncidentIds, isNotEmpty);

      await cubit.markAsRead();

      final incident = incidents.state.incidents.firstWhere(
        (i) => i.id == 'inc_alarmed_proddb',
      );
      expect(incident.isAcked, isTrue);
    },
  );
}
