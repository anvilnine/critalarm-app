import 'dart:async';

import 'package:critalarm/app/state/incidents_cubit.dart';
import 'package:critalarm/core/account/account_identity_changes.dart';
import 'package:critalarm/core/alarm/incident_alarm_controller.dart';
import 'package:critalarm/core/api/mock_api_client.dart';
import 'package:critalarm/core/api/mock_server.dart';
import 'package:critalarm/core/api/scoped_api_client.dart';
import 'package:critalarm/core/models/incident.dart';
import 'package:critalarm/core/store/local_store.dart';
import 'package:critalarm/features/incidents/data/repositories/in_memory_incident_repository.dart';
import 'package:critalarm/features/incidents/domain/usecases/get_incidents_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'fake_alarm_host.dart';

/// Answers the lookup the resume sweep makes, once the test lets it.
class _SlowLookups extends MockApiClient {
  _SlowLookups(super.server);

  final asked = <String>[];
  Completer<void>? gate;

  @override
  Future<Incident> getIncident(String id) async {
    asked.add(id);
    await gate?.future;
    return Incident(
      id: id,
      topic: 'prod-db',
      state: IncidentStates.acked,
      openedAt: DateTime.utc(2026, 10, 17, 3),
      updatedAt: DateTime.utc(2026, 10, 17, 4),
    );
  }

  @override
  Future<List<Incident>> getIncidents({
    required int limit,
    String? state,
    String? topic,
    DateTime? since,
  }) async => const [];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  late FakeAlarmHost fake;
  late String account;
  late AccountIdentityChanges changes;
  late LocalStore store;
  late _SlowLookups spy;
  late IncidentsCubit shared;
  late IncidentAlarmController controller;

  void moveTo(String next) {
    account = next;
    changes.bump();
  }

  setUp(() async {
    fake = FakeAlarmHost()
      ..answers['ringGeneration'] = 3
      ..answers['applyRemoteState'] = 'stopped'
      ..answers['liveIncidentIds'] = <String>['inc_1'];
    account = 'acc_a';
    changes = AccountIdentityChanges();
    store = await LocalStore.open(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
      scope: () async => account,
    );
    spy = _SlowLookups(MockServer())..gate = Completer<void>();
    final api = ScopedApiClient(spy, readScope: () async => account);
    final repository = InMemoryIncidentRepository(api, store: store);
    shared = IncidentsCubit(
      GetIncidentsUsecase(repository),
      saveIncident: repository.saveIncident,
      identityChanges: changes,
    );
    controller = IncidentAlarmController(
      host: fake.host,
      api: api,
      applyIncident: shared.applyIncident,
      wait: (_) async {},
    );
  });

  tearDown(() async {
    await shared.close();
    await store.close();
    fake.dispose();
  });

  test('a resume sweep whose answer lands after the account switched '
      'touches neither the list nor the archive of the new account', () async {
    final sweeping = controller.stopRingsHandledElsewhere();
    await pumpEventQueue();
    expect(spy.asked, ['inc_1']);

    // The person switched to another account while the question was out.
    moveTo('acc_b');
    await pumpEventQueue();
    spy.gate!.complete();
    await sweeping;
    await pumpEventQueue();

    expect(shared.state.incidents, isEmpty);
    expect(await store.incidents.count(), 0);
    // The card of the account that went is left for the next run.
    expect(fake.argsTo('applyRemoteState'), isEmpty);
  });

  test(
    'the same sweep answered for the same account is applied and stored',
    () async {
      final sweeping = controller.stopRingsHandledElsewhere();
      await pumpEventQueue();

      // A bump that changes nothing about the account.
      changes.bump();
      spy.gate!.complete();
      await sweeping;
      await pumpEventQueue();

      expect(shared.state.incidents.single.id, 'inc_1');
      expect((await store.incidents.page()).single.id, 'inc_1');
      expect(fake.argsTo('applyRemoteState'), hasLength(1));
    },
  );
}
