import 'package:critalarm/app/state/incidents_cubit.dart';
import 'package:critalarm/core/account/plan_changes.dart';
import 'package:critalarm/core/models/device_registration.dart';
import 'package:critalarm/core/models/incident.dart';
import 'package:critalarm/core/result/result.dart';
import 'package:critalarm/core/storage/device_identity_store.dart';
import 'package:critalarm/core/store/local_store.dart';
import 'package:critalarm/features/history/presentation/cubits/history_cubit.dart';
import 'package:critalarm/features/incidents/domain/repositories/incident_repository.dart';
import 'package:critalarm/features/incidents/domain/usecases/get_incidents_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// A server with nothing new to add, so the cubit only ever sees local rows.
class _QuietIncidents implements IncidentRepository {
  @override
  Future<AppResult<List<Incident>>> getIncidents({
    required int limit,
    String? state,
    String? topic,
    DateTime? since,
    bool fullRefresh = false,
  }) async => <Incident>[].toSuccess();

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  final now = DateTime.utc(2026, 9, 22, 12);
  late LocalStore store;

  setUp(() async {
    store = await LocalStore.open(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    // One alarm a day for the last 30 days, all on the phone.
    await store.incidents.upsertAll([
      for (var day = 0; day < 30; day++)
        Incident(
          id: 'i$day',
          topic: 'prod',
          state: IncidentStates.closed,
          openedAt: now.subtract(Duration(days: day, hours: 1)),
          lastMessageAt: now.subtract(Duration(days: day, hours: 1)),
        ),
    ]);
  });

  tearDown(() async => store.close());

  Future<(HistoryCubit, DeviceIdentityStore)> freeHistory(
    PlanChanges plan,
  ) async {
    SharedPreferences.setMockInitialValues({'device_id': 'dev_1'});
    final identity = DeviceIdentityStore(await SharedPreferences.getInstance());
    await identity.saveRegistration(
      deviceToken: 'dv_1',
      accountId: 'acc_1',
      tier: 'free',
      caps: AccountCaps.free,
    );
    final shared = IncidentsCubit(GetIncidentsUsecase(_QuietIncidents()));
    addTearDown(shared.close);
    final history = HistoryCubit(
      shared,
      now: () => now,
      identityStore: identity,
      store: store,
      planChanges: plan,
    );
    addTearDown(history.close);
    await history.load();
    return (history, identity);
  }

  test('the store saying Pro counts as paid before the server does', () async {
    final plan = PlanChanges()..setStoreSaysPro(value: true);
    final (history, _) = await freeHistory(plan);

    expect(history.state.entries, hasLength(30));
    expect(history.state.olderCount, 0);
  });

  test('buying Pro on an open tab shows the older alarms', () async {
    final plan = PlanChanges();
    final (history, _) = await freeHistory(plan);
    expect(history.state.entries, hasLength(7));
    expect(history.state.olderCount, 23);

    plan.setStoreSaysPro(value: true);
    await pumpEventQueue();

    expect(history.state.entries, hasLength(30));
    expect(history.state.olderCount, 0);
  });

  test('a bump after the server catches up reads the new tier', () async {
    final plan = PlanChanges();
    final (history, identity) = await freeHistory(plan);

    await identity.saveRegistration(
      deviceToken: 'dv_1',
      accountId: 'acc_1',
      tier: 'relay',
      caps: const AccountCaps(historyDays: 90),
    );
    plan.bump();
    await pumpEventQueue();

    expect(history.state.olderCount, 0);
  });

  test('refresh reads the tier again', () async {
    final plan = PlanChanges();
    final (history, identity) = await freeHistory(plan);

    await identity.saveRegistration(
      deviceToken: 'dv_1',
      accountId: 'acc_1',
      tier: 'relay',
      caps: const AccountCaps(historyDays: 90),
    );
    await history.refresh();

    expect(history.state.entries, hasLength(30));
  });
}
