import 'dart:async';

import 'package:critalarm/core/access/holding.dart';
import 'package:critalarm/core/api/api_session.dart';
import 'package:critalarm/core/models/device_identity.dart';
import 'package:critalarm/core/models/incident.dart';
import 'package:critalarm/core/models/message.dart';
import 'package:critalarm/core/storage/device_identity_store.dart';
import 'package:critalarm/core/store/local_store.dart';
import 'package:critalarm/features/settings/data/repositories/shared_prefs_storage_settings_repository.dart';
import 'package:critalarm/features/settings/domain/entities/storage_settings.dart';
import 'package:critalarm/features/settings/domain/usecases/auto_delete_history_usecase.dart';
import 'package:critalarm/features/settings/presentation/cubits/settings_cubit.dart';
import 'package:critalarm/features/settings/presentation/cubits/settings_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../core/access/access_fakes.dart';

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

/// An identity that never comes back, the way a slow first read looks to
/// Settings. Everything after it in the load waits.
class _HangingIdentityStore extends DeviceIdentityStore {
  _HangingIdentityStore(super.prefs);

  @override
  Future<DeviceIdentity> readOrCreate() => Completer<DeviceIdentity>().future;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  group('the Storage section is drawn for', () {
    // The rule is the storageRules row of the feature table. Settings asks
    // feature access and keeps no rule of its own.
    Future<bool> drawnFor(TestAccess access) async {
      addTearDown(access.dispose);
      final cubit = SettingsCubit(
        holdings: access.holdings,
        featureAccess: access.features,
      );
      addTearDown(cubit.close);
      await cubit.load();
      return cubit.state.hasStorageSection;
    }

    test('nobody on a free relay account', () async {
      expect(await drawnFor(TestAccess()), isFalse);
    });

    test('a paid account', () async {
      expect(await drawnFor(TestAccess(held: {Holding.hosted})), isTrue);
    });

    test('a self-hosted server, which has no tier', () async {
      expect(
        await drawnFor(TestAccess(serverMode: ServerMode.selfhosted)),
        isTrue,
      );
    });

    test('at once, before the identity and the topics have answered', () async {
      final access = TestAccess(held: {Holding.hosted});
      addTearDown(access.dispose);
      final cubit = SettingsCubit(
        identityStore: _HangingIdentityStore(
          await SharedPreferences.getInstance(),
        ),
        holdings: access.holdings,
        featureAccess: access.features,
      );
      addTearDown(cubit.close);
      // The rest of the load never finishes: no network, no topics.
      unawaited(cubit.load());
      await pumpEventQueue();

      expect(cubit.state.status, SettingsStatus.loading);
      expect(cubit.state.hasStorageSection, isTrue);
      expect(cubit.state.holdsHosted, isTrue);
    });

    test('a purchase that lands while Settings is open', () async {
      final access = TestAccess();
      addTearDown(access.dispose);
      final cubit = SettingsCubit(
        holdings: access.holdings,
        featureAccess: access.features,
      );
      addTearDown(cubit.close);
      await cubit.load();
      expect(cubit.state.hasStorageSection, isFalse);
      expect(cubit.state.holdsHosted, isFalse);

      access.hosted.set(HoldingState.pending);
      await pumpEventQueue();

      expect(cubit.state.hasStorageSection, isTrue);
      expect(cubit.state.holdsHosted, isTrue);
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
