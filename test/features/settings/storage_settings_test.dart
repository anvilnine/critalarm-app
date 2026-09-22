import 'package:critalarm/core/api/api_session.dart';
import 'package:critalarm/core/models/account_access.dart';
import 'package:critalarm/core/models/device_identity.dart';
import 'package:critalarm/core/models/incident.dart';
import 'package:critalarm/core/models/message.dart';
import 'package:critalarm/core/store/local_store.dart';
import 'package:critalarm/features/settings/data/repositories/shared_prefs_storage_settings_repository.dart';
import 'package:critalarm/features/settings/domain/entities/storage_settings.dart';
import 'package:critalarm/features/settings/domain/usecases/auto_delete_history_usecase.dart';
import 'package:critalarm/features/settings/presentation/cubits/settings_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

final _now = DateTime.utc(2026, 9, 22, 12);

DateTime _at(int daysAgo) => _now.subtract(Duration(days: daysAgo));

Incident _incident(String id, {required int daysAgo, int priority = 4}) {
  final openedAt = _at(daysAgo);
  return Incident(
    id: id,
    topic: 'prod',
    state: IncidentStates.closed,
    openedAt: openedAt,
    lastMessageAt: openedAt,
    messages: [
      Message(
        id: 'msg_$id',
        topic: 'prod',
        time: openedAt.millisecondsSinceEpoch ~/ 1000,
        priority: priority,
        incidentId: id,
      ),
    ],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  group('the Storage section is drawn for', () {
    const paid = DeviceIdentity(
      deviceId: 'dev_1',
      accountId: 'acc_1',
      tier: 'hosted',
    );
    const free = DeviceIdentity(deviceId: 'dev_1', accountId: 'acc_1');

    test('nobody on a free relay account', () {
      const state = SettingsState(
        access: AccountAccess(free),
        serverMode: ServerMode.hosted,
      );
      expect(state.hasStorageSection, isFalse);
    });

    test('a paid account', () {
      const state = SettingsState(
        access: AccountAccess(paid),
        serverMode: ServerMode.hosted,
      );
      expect(state.hasStorageSection, isTrue);
    });

    test('a self-hosted server, which has no tier', () {
      const state = SettingsState(
        access: AccountAccess(free),
        serverMode: ServerMode.selfhosted,
      );
      expect(state.hasStorageSection, isTrue);
    });
  });

  group('the settings round-trip', () {
    test('defaults to Never and keeping critical alarms', () async {
      SharedPreferences.setMockInitialValues({});
      final repo = SharedPrefsStorageSettingsRepository(
        await SharedPreferences.getInstance(),
      );

      expect(repo.read().retention, HistoryRetention.never);
      expect(repo.read().keepCriticalForever, isTrue);
    });

    test('remembers both rows', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = SharedPrefsStorageSettingsRepository(prefs);

      await repo.setRetention(HistoryRetention.threeMonths);
      await repo.setKeepCriticalForever(keep: false);

      final read = SharedPrefsStorageSettingsRepository(prefs).read();
      expect(read.retention, HistoryRetention.threeMonths);
      expect(read.keepCriticalForever, isFalse);
    });
  });

  group('auto-delete', () {
    late LocalStore store;

    setUp(() async {
      store = await LocalStore.open(
        factory: databaseFactoryFfi,
        path: inMemoryDatabasePath,
      );
      await store.incidents.upsertAll([
        _incident('inc_old_p4', daysAgo: 40),
        _incident('inc_old_p5', daysAgo: 40, priority: 5),
        _incident('inc_new', daysAgo: 2),
      ]);
    });

    tearDown(() async => store.close());

    AutoDeleteHistoryUsecase usecaseWith(StorageSettings settings) =>
        AutoDeleteHistoryUsecase(store, () => settings);

    test('Never removes nothing', () async {
      final removed = await usecaseWith(
        const StorageSettings(),
      )(now: _now);

      expect(removed, 0);
      expect(await store.incidents.count(), 3);
    });

    test('1 month drops the old P4 and keeps the old P5', () async {
      final removed = await usecaseWith(
        const StorageSettings(retention: HistoryRetention.oneMonth),
      )(now: _now);

      expect(removed, 1);
      final left = await store.incidents.page();
      expect(left.map((i) => i.id), ['inc_new', 'inc_old_p5']);
    });

    test('the P5 switch off drops the old P5 too', () async {
      final removed = await usecaseWith(
        const StorageSettings(
          retention: HistoryRetention.oneMonth,
          keepCriticalForever: false,
        ),
      )(now: _now);

      expect(removed, 2);
      final left = await store.incidents.page();
      expect(left.map((i) => i.id), ['inc_new']);
    });

    test('a phone with no database does nothing', () async {
      const usecase = AutoDeleteHistoryUsecase(null, _oneMonth);
      expect(await usecase(now: _now), 0);
    });
  });
}

StorageSettings _oneMonth() =>
    const StorageSettings(retention: HistoryRetention.oneMonth);
