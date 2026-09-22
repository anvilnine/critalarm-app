import 'package:critalarm/app/state/incidents_cubit.dart';
import 'package:critalarm/core/models/device_registration.dart';
import 'package:critalarm/core/models/incident.dart';
import 'package:critalarm/core/result/result.dart';
import 'package:critalarm/core/storage/device_identity_store.dart';
import 'package:critalarm/core/store/local_store.dart';
import 'package:critalarm/features/history/domain/history_window.dart';
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

  group('HistoryWindow.lowerBound', () {
    test('free stops at now minus history_days', () {
      expect(
        HistoryWindow.lowerBound(tier: 'free', historyDays: 7, now: now),
        now.subtract(const Duration(days: 7)),
      );
    });

    test('a hosted tier has no lower bound', () {
      expect(
        HistoryWindow.lowerBound(tier: 'hosted', historyDays: 90, now: now),
        isNull,
      );
    });

    test('a relay tier has no lower bound', () {
      expect(
        HistoryWindow.lowerBound(tier: 'relay', historyDays: 90, now: now),
        isNull,
      );
    });

    test('self-hosted has no lower bound, whatever the tier says', () {
      expect(
        HistoryWindow.lowerBound(
          tier: 'free',
          historyDays: 7,
          now: now,
          isSelfHosted: true,
        ),
        isNull,
      );
    });
  });

  group('a tier flip on a live cubit', () {
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

    /// The account's plan, as the identity store holds it.
    Future<void> setTier(DeviceIdentityStore identity, String tier) =>
        identity.saveRegistration(
          deviceToken: 'dv_1',
          accountId: 'acc_1',
          tier: tier,
          caps: tier == 'free'
              ? AccountCaps.free
              : const AccountCaps(historyDays: 90),
        );

    Future<(HistoryCubit, DeviceIdentityStore)> historyOn(String tier) async {
      SharedPreferences.setMockInitialValues({'device_id': 'dev_1'});
      final prefs = await SharedPreferences.getInstance();
      final identity = DeviceIdentityStore(prefs);
      await setTier(identity, tier);

      final shared = IncidentsCubit(GetIncidentsUsecase(_QuietIncidents()));
      addTearDown(shared.close);
      final history = HistoryCubit(
        shared,
        now: () => now,
        identityStore: identity,
        store: store,
      );
      addTearDown(history.close);
      await history.load();
      return (history, identity);
    }

    test('buying Pro unhides the old rows in the same cubit', () async {
      final (history, identity) = await historyOn('free');
      expect(history.state.entries, hasLength(7));
      expect(history.state.olderCount, 23);

      // The same handset, the same cubit, a new plan.
      await setTier(identity, 'hosted');
      await history.load();

      expect(history.state.entries, hasLength(30));
      expect(history.state.olderCount, 0);
    });

    test('lapsing hides them again and deletes nothing', () async {
      final (history, identity) = await historyOn('hosted');
      expect(history.state.entries, hasLength(30));
      final held = await store.incidents.count();

      await setTier(identity, 'free');
      await history.load();

      expect(history.state.entries, hasLength(7));
      expect(history.state.olderCount, 23);
      expect(await store.incidents.count(), held);
    });

    test('pages through the store without going to the server', () async {
      await store.incidents.upsertAll([
        for (var minute = 0; minute < 120; minute++)
          Incident(
            id: 'p$minute',
            topic: 'prod',
            state: IncidentStates.closed,
            openedAt: now.subtract(Duration(minutes: minute + 1)),
            lastMessageAt: now.subtract(Duration(minutes: minute + 1)),
          ),
      ]);

      final (history, _) = await historyOn('hosted');
      expect(history.state.entries, hasLength(HistoryCubit.pageSize));
      expect(history.state.hasMore, isTrue);

      await history.loadMore();
      expect(history.state.entries, hasLength(HistoryCubit.pageSize * 2));

      await history.loadMore();
      await history.loadMore();
      expect(history.state.entries, hasLength(150));
      expect(history.state.hasMore, isFalse);
    });
  });
}
