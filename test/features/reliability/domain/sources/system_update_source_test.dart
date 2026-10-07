import 'package:critalarm/core/device/os_version_reader.dart';
import 'package:critalarm/features/reliability/domain/entities/reliability_fix.dart';
import 'package:critalarm/features/reliability/domain/entities/reliability_state.dart';
import 'package:critalarm/features/reliability/domain/os_version_store.dart';
import 'package:critalarm/features/reliability/domain/sources/system_update_source.dart';
import 'package:flutter_test/flutter_test.dart';

class _MemoryStore implements OsVersionStore {
  OsVersionRecord record = const OsVersionRecord();

  @override
  OsVersionRecord read() => record;

  @override
  Future<void> write(OsVersionRecord next) async => record = next;
}

class _Clock {
  DateTime now = DateTime.utc(2026, 10, 7, 9);
  DateTime call() => now;
}

class _Os implements OsVersionReader {
  _Os(this.value);

  int? value;

  @override
  Future<int?> major() async => value;
}

void main() {
  late _MemoryStore store;
  late _Clock clock;
  late _Os os;
  DateTime? lastTest;

  SystemUpdateSource build() => SystemUpdateSource(
    os: os,
    store: store,
    lastTestAt: () async => lastTest,
    testRouteName: 'testRing',
    now: clock.call,
  );

  setUp(() {
    store = _MemoryStore();
    clock = _Clock();
    os = _Os(17);
    lastTest = null;
  });

  group('state rule', () {
    final changed = DateTime.utc(2026, 10, 7, 9);

    test('no change is fine', () {
      final check = SystemUpdateSource.systemUpdateCheckFor(
        changedAt: null,
        lastTestAt: null,
        testRouteName: 'testRing',
      );
      expect(check.state, ReliabilityState.fine);
    });

    test('a change with no test ever needs a look, and offers a test', () {
      final check = SystemUpdateSource.systemUpdateCheckFor(
        changedAt: changed,
        lastTestAt: null,
        testRouteName: 'testRing',
      );
      expect(check.state, ReliabilityState.needsLook);
      expect(check.reason, 'os_changed');
      expect(check.fix, const OpenRouteFix('testRing'));
    });

    test('a test from before the change does not count', () {
      final check = SystemUpdateSource.systemUpdateCheckFor(
        changedAt: changed,
        lastTestAt: changed.subtract(const Duration(days: 3)),
        testRouteName: 'testRing',
      );
      expect(check.state, ReliabilityState.needsLook);
    });

    test('a test at the very moment of the change does not count', () {
      final check = SystemUpdateSource.systemUpdateCheckFor(
        changedAt: changed,
        lastTestAt: changed,
        testRouteName: 'testRing',
      );
      expect(check.state, ReliabilityState.needsLook);
    });

    test('a test one second after the change clears it', () {
      final check = SystemUpdateSource.systemUpdateCheckFor(
        changedAt: changed,
        lastTestAt: changed.add(const Duration(seconds: 1)),
        testRouteName: 'testRing',
      );
      expect(check.state, ReliabilityState.fine);
      expect(check.fix, isNull);
    });
  });

  group('source', () {
    test('first run stores the version and is fine', () async {
      final check = (await build().read()).single;
      expect(check.state, ReliabilityState.fine);
      expect(store.record.major, 17);
      expect(store.record.changedAt, isNull);
    });

    test('first run is fine even if a test was never rung', () async {
      lastTest = null;
      expect((await build().read()).single.state, ReliabilityState.fine);
    });

    test('the same version on a later run stays fine', () async {
      await build().read();
      clock.now = clock.now.add(const Duration(days: 30));
      expect((await build().read()).single.state, ReliabilityState.fine);
      expect(store.record.changedAt, isNull);
    });

    test('a changed version needs a look and is stamped when seen', () async {
      await build().read();
      os.value = 18;
      clock.now = DateTime.utc(2026, 10, 20, 8);
      final check = (await build().read()).single;
      expect(check.state, ReliabilityState.needsLook);
      expect(store.record.major, 18);
      expect(store.record.changedAt, DateTime.utc(2026, 10, 20, 8));
    });

    test('the stamp does not move on later reads of the same change', () async {
      await build().read();
      os.value = 18;
      clock.now = DateTime.utc(2026, 10, 20, 8);
      await build().read();
      clock.now = DateTime.utc(2026, 10, 25, 8);
      await build().read();
      expect(store.record.changedAt, DateTime.utc(2026, 10, 20, 8));
    });

    test('a change followed by a test is fine again', () async {
      await build().read();
      os.value = 18;
      clock.now = DateTime.utc(2026, 10, 20, 8);
      expect((await build().read()).single.state, ReliabilityState.needsLook);

      lastTest = DateTime.utc(2026, 10, 20, 9);
      final check = (await build().read()).single;
      expect(check.state, ReliabilityState.fine);
      expect(check.lastKnownGood, lastTest);
    });

    test('a test from before the update does not clear it', () async {
      lastTest = DateTime.utc(2026, 10);
      await build().read();
      os.value = 18;
      clock.now = DateTime.utc(2026, 10, 20, 8);
      expect((await build().read()).single.state, ReliabilityState.needsLook);
    });

    test('a second update after a test needs a look again', () async {
      await build().read();
      os.value = 18;
      clock.now = DateTime.utc(2026, 10, 20, 8);
      await build().read();
      lastTest = DateTime.utc(2026, 10, 20, 9);
      expect((await build().read()).single.state, ReliabilityState.fine);

      os.value = 19;
      clock.now = DateTime.utc(2027, 9, 20, 8);
      expect((await build().read()).single.state, ReliabilityState.needsLook);
    });

    test('a version that cannot be read is not on this phone', () async {
      os.value = null;
      final check = (await build().read()).single;
      expect(check.state, ReliabilityState.notOnThisPhone);
      expect(store.record.major, isNull);
    });

    test('recordVersion alone stamps a change at launch', () async {
      await build().recordVersion();
      os.value = 18;
      clock.now = DateTime.utc(2026, 10, 20, 8);
      await build().recordVersion();
      expect(store.record.changedAt, DateTime.utc(2026, 10, 20, 8));
    });
  });
}
