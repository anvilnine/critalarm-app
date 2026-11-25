import 'package:critalarm/app/state/incidents_cubit.dart';
import 'package:critalarm/app/state/topics_cubit.dart';
import 'package:critalarm/core/api/mock_api_client.dart';
import 'package:critalarm/core/api/mock_server.dart';
import 'package:critalarm/core/models/message.dart';
import 'package:critalarm/core/models/topic.dart';
import 'package:critalarm/core/storage/device_identity_store.dart';
import 'package:critalarm/core/store/local_store.dart';
import 'package:critalarm/features/incidents/data/repositories/in_memory_incident_repository.dart';
import 'package:critalarm/features/incidents/domain/usecases/get_incidents_usecase.dart';
import 'package:critalarm/features/topics/data/repositories/in_memory_topic_repository.dart';
import 'package:critalarm/features/topics/domain/usecases/get_topics_usecase.dart';
import 'package:critalarm/features/topics/domain/usecases/update_topic_usecase.dart';
import 'package:critalarm/features/topics/presentation/cubits/topic_detail_cubit.dart';
import 'package:critalarm/features/topics/presentation/cubits/topic_message_rows.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Whole seconds, because the server's messages carry no more.
final DateTime _now = DateTime.fromMillisecondsSinceEpoch(
  DateTime.now().millisecondsSinceEpoch ~/ 1000 * 1000,
);

Message _message(String id, Duration ago) => Message(
  id: id,
  topic: 'backups',
  time: _now.subtract(ago).millisecondsSinceEpoch ~/ 1000,
  message: id,
);

void main() {
  sqfliteFfiInit();

  group('TopicMessageWindow.outside', () {
    final fresh = _message('fresh', const Duration(days: 1));
    final old = _message('old', const Duration(days: 10));
    final bound = _now.subtract(const Duration(days: 7));

    test('holds what inside leaves out', () {
      expect(TopicMessageWindow.inside([fresh, old], bound), [fresh]);
      expect(TopicMessageWindow.outside([fresh, old], bound), [old]);
    });

    test('is empty with no bound, where everything shows', () {
      expect(TopicMessageWindow.outside([fresh, old], null), isEmpty);
    });
  });

  group('Topic screen on the free plan', () {
    late LocalStore store;
    late IncidentsCubit incidents;
    late TopicsCubit topics;
    late TopicDetailCubit cubit;

    setUp(() async {
      SharedPreferences.setMockInitialValues({
        'account_caps': '{"history_days":7}',
      });
      final prefs = await SharedPreferences.getInstance();
      store = await LocalStore.open(
        factory: databaseFactoryFfi,
        path: inMemoryDatabasePath,
      );
      final server = MockServer()
        ..reset()
        ..seedState(topics: [const Topic(name: 'backups')]);
      final api = MockApiClient(server);
      final incidentRepo = InMemoryIncidentRepository(api, store: store);
      incidents = IncidentsCubit(GetIncidentsUsecase(incidentRepo));
      topics = TopicsCubit(GetTopicsUsecase(InMemoryTopicRepository(api)));
      cubit = TopicDetailCubit(
        incidents,
        topics,
        UpdateTopicUsecase(InMemoryTopicRepository(api)),
        incidentRepo,
        identityStore: DeviceIdentityStore(prefs),
      );
      // The phone kept a message the server no longer returns: it is past
      // the 7 days the free plan keeps, and Home still shows it as the
      // topic's last message.
      await store.messages.upsertAll([
        _message('ten-days-old', const Duration(days: 10)),
      ]);
    });

    tearDown(() async {
      await cubit.close();
      await incidents.close();
      await topics.close();
      await store.close();
    });

    test('keeps messages past the window as older, not as nothing', () async {
      await cubit.load('backups');

      expect(cubit.state.messages, isEmpty);
      expect(cubit.state.olderMessages, hasLength(1));
      expect(cubit.state.olderMessages.single.body, 'ten-days-old');
      // The line under the face counts it, so it never says "No messages
      // yet" for a topic that has messages.
      expect(
        cubit.state.subText,
        isNot(
          LocaleKeys.topic_detail_stage_sub_empty.tr(
            namedArgs: {'priority': 'default'},
          ),
        ),
      );
      expect(cubit.state.subText, isNot(contains('No messages')));
    });
  });
}
