import 'package:critalarm/core/models/weekly_check.dart';
import 'package:critalarm/features/reliability/domain/proof/proof_entry.dart';
import 'package:critalarm/features/reliability/domain/proof/proof_log.dart';
import 'package:critalarm/features/reliability/domain/proof/proof_log_store.dart';
import 'package:critalarm/features/weekly_check/domain/weekly_check_access.dart';
import 'package:critalarm/features/weekly_check/domain/weekly_check_monitor.dart';
import 'package:flutter_test/flutter_test.dart';

import 'weekly_check_fakes.dart';

class _MemoryStore implements ProofLogStore {
  List<ProofEntry> entries = [];

  @override
  List<ProofEntry> read() => entries;

  @override
  Future<void> write(List<ProofEntry> next) async => entries = next;

  @override
  Future<void> clear() async => entries = [];
}

class _ThrowingStore implements ProofLogStore {
  @override
  List<ProofEntry> read() => throw StateError('unreadable');

  @override
  Future<void> write(List<ProofEntry> entries) async =>
      throw StateError('full');

  @override
  Future<void> clear() async => throw StateError('full');
}

int _seconds(DateTime at) => at.millisecondsSinceEpoch ~/ 1000;

/// The weekly check writes what the relay reports into the proof log, and
/// never lets the log stop it from recording.
void main() {
  final now = DateTime(2026, 10, 8, 9); // Thursday, week of 2026-10-05
  late FakeWeeklyCheckApi api;
  late MemoryWeeklyCheckStore store;

  WeeklyCheckMonitor monitor(ProofLog? log) => WeeklyCheckMonitor(
    api: api,
    store: store,
    readDeviceId: () async => 'dev_1',
    readAccess: () => WeeklyCheckAccess.open,
    onTierRefused: () async {},
    proofLog: log,
    now: () => now,
  );

  setUp(() {
    api = FakeWeeklyCheckApi();
    store = MemoryWeeklyCheckStore();
  });

  test('a received check marks rang for the week of that second', () async {
    final proof = _MemoryStore();
    api.check = WeeklyCheck(
      enabled: true,
      state: WeeklyCheckState.received,
      lastSentAt: _seconds(DateTime(2026, 10, 6, 9)),
      lastReceivedAt: _seconds(DateTime(2026, 10, 6, 9, 0, 4)),
    );
    await monitor(ProofLog(proof, now: () => now)).refresh(force: true);
    expect(proof.entries, hasLength(1));
    expect(proof.entries.single.key, '2026-10-05');
    expect(proof.entries.single.rangAt, DateTime(2026, 10, 6, 9, 0, 4));
  });

  test(
    'misses with a lastSentAt mark failed for the week of lastSentAt',
    () async {
      final proof = _MemoryStore();
      api.check = WeeklyCheck(
        enabled: true,
        state: WeeklyCheckState.missedOnce,
        misses: 1,
        lastSentAt: _seconds(DateTime(2026, 9, 30, 9)),
      );
      await monitor(ProofLog(proof, now: () => now)).refresh(force: true);
      expect(proof.entries.single.key, '2026-09-28');
      expect(proof.entries.single.failedAt, DateTime(2026, 9, 30, 9));
      expect(proof.entries.single.rangAt, isNull);
    },
  );

  test('misses in a week that already rang stay rang', () async {
    final proof = _MemoryStore();
    final log = ProofLog(proof, now: () => now);
    api.check = WeeklyCheck(
      enabled: true,
      state: WeeklyCheckState.received,
      lastReceivedAt: _seconds(DateTime(2026, 10, 6, 9)),
    );
    final subject = monitor(log);
    await subject.refresh(force: true);
    api.check = WeeklyCheck(
      enabled: true,
      state: WeeklyCheckState.missedOnce,
      misses: 1,
      lastSentAt: _seconds(DateTime(2026, 10, 7, 9)),
      lastReceivedAt: _seconds(DateTime(2026, 10, 6, 9)),
    );
    await subject.refresh(force: true);
    expect(log.weeks(now).last.mark, ProofMark.rang);
    expect(proof.entries, hasLength(1));
  });

  test('a read that changes nothing writes nothing new', () async {
    final proof = _MemoryStore();
    api.check = WeeklyCheck(
      enabled: true,
      state: WeeklyCheckState.received,
      lastReceivedAt: _seconds(DateTime(2026, 10, 6, 9)),
    );
    final subject = monitor(ProofLog(proof, now: () => now));
    await subject.refresh(force: true);
    final first = proof.entries;
    await subject.refresh(force: true);
    expect(identical(proof.entries, first), isTrue);
  });

  test('an answer with nothing to record leaves the log empty', () async {
    final proof = _MemoryStore();
    api.check = const WeeklyCheck(
      enabled: true,
      state: WeeklyCheckState.waiting,
    );
    await monitor(ProofLog(proof, now: () => now)).refresh(force: true);
    expect(proof.entries, isEmpty);
  });

  test('a throwing log still lets the check record and announce', () async {
    api.check = WeeklyCheck(
      enabled: true,
      state: WeeklyCheckState.received,
      lastReceivedAt: _seconds(DateTime(2026, 10, 6, 9)),
    );
    final subject = monitor(ProofLog(_ThrowingStore(), now: () => now));
    var announced = 0;
    final sub = subject.changes.listen((_) => announced++);
    addTearDown(sub.cancel);
    await subject.refresh(force: true);
    await Future<void>.delayed(Duration.zero);
    expect(subject.check!.state, WeeklyCheckState.received);
    expect(store.kept, isNotNull);
    expect(announced, greaterThan(0));
  });

  test('with no log the check works as before', () async {
    api.check = WeeklyCheck(
      enabled: true,
      state: WeeklyCheckState.received,
      lastReceivedAt: _seconds(DateTime(2026, 10, 6, 9)),
    );
    final subject = monitor(null);
    await subject.refresh(force: true);
    expect(subject.check!.state, WeeklyCheckState.received);
  });
}
