import 'package:critalarm/features/onboarding/data/repositories/shared_prefs_setup_use_store.dart';
import 'package:critalarm/features/onboarding/domain/setup_use/setup_use.dart';
import 'package:critalarm/features/onboarding/domain/setup_use/setup_use_store.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _ThrowingPrefs extends Fake implements SharedPreferences {
  @override
  String? getString(String key) => throw PlatformException(code: 'boom');
}

class _MemoryStore implements SetupUseStore {
  _MemoryStore([this.value]);

  SetupUse? value;
  int saves = 0;

  @override
  SetupUse? read() => value;

  @override
  Future<void> save(SetupUse use) async {
    saves++;
    value = use;
  }

  @override
  Future<void> clear() async => value = null;
}

void main() {
  Future<SharedPreferences> prefsWith(Map<String, Object> values) async {
    SharedPreferences.setMockInitialValues(values);
    return SharedPreferences.getInstance();
  }

  group('SharedPrefsSetupUseStore', () {
    test('keeps the wire id under setup_use', () async {
      final prefs = await prefsWith({});
      final store = SharedPrefsSetupUseStore(prefs);
      expect(store.read(), isNull);
      await store.save(SetupUse.homelab);
      expect(prefs.getString('setup_use'), 'homelab');
    });

    test('round trips every answer', () async {
      final prefs = await prefsWith({});
      final store = SharedPrefsSetupUseStore(prefs);
      for (final use in SetupUse.values) {
        await store.save(use);
        expect(store.read(), use);
      }
    });

    test('an unknown value reads as null', () async {
      for (final bad in ['Servers', '', 'skipped', 'nope']) {
        final store = SharedPrefsSetupUseStore(
          await prefsWith({'setup_use': bad}),
        );
        expect(store.read(), isNull, reason: bad);
      }
    });

    test('a value of the wrong type reads as null', () async {
      final store = SharedPrefsSetupUseStore(await prefsWith({'setup_use': 3}));
      expect(store.read(), isNull);
    });

    test('a prefs throw reads as null', () {
      expect(SharedPrefsSetupUseStore(_ThrowingPrefs()).read(), isNull);
    });

    test('clear removes the answer', () async {
      final prefs = await prefsWith({'setup_use': 'jobs'});
      final store = SharedPrefsSetupUseStore(prefs);
      expect(store.read(), SetupUse.jobs);
      await store.clear();
      expect(store.read(), isNull);
      expect(prefs.containsKey('setup_use'), isFalse);
    });
  });

  group('SetupUseReplay', () {
    test('holds a pick until cleared', () {
      final replay = SetupUseReplay();
      expect(replay.pick, isNull);
      replay.set(SetupUse.home);
      expect(replay.pick, SetupUse.home);
      replay.clear();
      expect(replay.pick, isNull);
    });
  });

  group('setupUseFor', () {
    test('in a replay the replay pick comes first', () {
      final store = _MemoryStore(SetupUse.servers);
      final replay = SetupUseReplay()..set(SetupUse.home);
      expect(
        setupUseFor(isReplay: true, store: store, replay: replay),
        SetupUse.home,
      );
    });

    test('outside a replay the saved answer is read, not the pick', () {
      final store = _MemoryStore(SetupUse.servers);
      final replay = SetupUseReplay()..set(SetupUse.home);
      expect(
        setupUseFor(isReplay: false, store: store, replay: replay),
        SetupUse.servers,
      );
    });

    test('a replay with no pick yet reads the saved answer', () {
      final store = _MemoryStore(SetupUse.jobs);
      expect(
        setupUseFor(isReplay: true, store: store, replay: SetupUseReplay()),
        SetupUse.jobs,
      );
    });

    test('null when there is neither', () {
      final replay = SetupUseReplay();
      expect(
        setupUseFor(isReplay: true, store: _MemoryStore(), replay: replay),
        isNull,
      );
      expect(
        setupUseFor(isReplay: false, store: _MemoryStore(), replay: replay),
        isNull,
      );
    });

    test('reading never saves, and a pick never reaches the prefs', () async {
      final prefs = await prefsWith({});
      final store = SharedPrefsSetupUseStore(prefs);
      final replay = SetupUseReplay()..set(SetupUse.home);
      expect(
        setupUseFor(isReplay: true, store: store, replay: replay),
        SetupUse.home,
      );
      expect(prefs.containsKey('setup_use'), isFalse);
      expect(store.read(), isNull);

      final counting = _MemoryStore();
      setupUseFor(isReplay: true, store: counting, replay: replay);
      expect(counting.saves, 0);
    });
  });
}
