import 'package:critalarm/features/reliability/data/shared_prefs_proof_log_store.dart';
import 'package:critalarm/features/reliability/domain/proof/proof_entry.dart';
import 'package:critalarm/features/reliability/domain/proof/proof_log.dart';
import 'package:critalarm/features/reliability/domain/proof/proof_log_store.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MemoryStore implements ProofLogStore {
  List<ProofEntry> entries = [];
  int writes = 0;

  @override
  List<ProofEntry> read() => entries;

  @override
  Future<void> write(List<ProofEntry> next) async {
    writes++;
    // A slow disk, so two writes that overlap would lose one.
    await Future<void>.delayed(Duration.zero);
    entries = next;
  }

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

void main() {
  final now = DateTime(2026, 10, 7, 9); // Wednesday, week of 2026-10-05

  test('a scripted sequence leaves one mark per week', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final log = ProofLog(SharedPrefsProofLogStore(prefs), now: () => now);

    await log.markRang(DateTime(2026, 9, 16, 10)); // week of 09-14
    await log.markFailed(DateTime(2026, 9, 23, 10)); // week of 09-21
    await log.markFailed(DateTime(2026, 9, 30, 10)); // week of 09-28
    await log.markRang(DateTime(2026, 10, 1, 10)); // rang wins in 09-28
    await log.markRang(DateTime(2026, 10, 6, 10)); // this week
    await log.markFailed(DateTime(2026, 10, 7, 8)); // does not undo it

    final weeks = log.weeks(now);
    debugPrint('proof_log = ${prefs.getString('proof_log')}');
    for (final week in weeks) {
      debugPrint('${proofWeekKey(week.monday)} ${week.mark.name}');
    }
    expect(weeks.map((w) => w.mark), [
      ProofMark.none, // 08-17
      ProofMark.none, // 08-24
      ProofMark.none, // 08-31
      ProofMark.none, // 09-07
      ProofMark.rang, // 09-14
      ProofMark.failed, // 09-21
      ProofMark.rang, // 09-28
      ProofMark.rang, // 10-05
    ]);
    expect(log.newestRangAt(), DateTime(2026, 10, 6, 10));
  });

  test('the log never grows past 12 weeks', () async {
    final store = _MemoryStore();
    final log = ProofLog(store, now: () => now);
    for (var i = 0; i < 20; i++) {
      await log.markRang(DateTime(2026, 1, 5 + 7 * i, 9));
    }
    expect(store.entries, hasLength(12));
  });

  test('a mark that adds nothing writes nothing', () async {
    final store = _MemoryStore();
    final log = ProofLog(store, now: () => now);
    await log.markRang(DateTime(2026, 10, 6, 10));
    await log.markRang(DateTime(2026, 10, 6, 10));
    await log.markRang(DateTime(2026, 10, 5, 10)); // earlier, same week
    expect(store.writes, 1);
  });

  test('marks that arrive together both land', () async {
    final store = _MemoryStore();
    final log = ProofLog(store, now: () => now);
    await Future.wait([
      log.markRang(DateTime(2026, 9, 30, 10)),
      log.markFailed(DateTime(2026, 9, 23, 10)),
      log.markRang(DateTime(2026, 10, 6, 10)),
    ]);
    expect(store.entries.map((e) => e.key), [
      '2026-09-21',
      '2026-09-28',
      '2026-10-05',
    ]);
  });

  test('changes fires after a write and after clear', () async {
    final log = ProofLog(_MemoryStore(), now: () => now);
    var fired = 0;
    final sub = log.changes.listen((_) => fired++);
    addTearDown(sub.cancel);
    await log.markRang(DateTime(2026, 10, 6, 10));
    await Future<void>.delayed(Duration.zero);
    expect(fired, 1);
    await log.clear();
    await Future<void>.delayed(Duration.zero);
    expect(fired, 2);
    expect(log.weeks(now).every((w) => w.mark == ProofMark.none), isTrue);
  });

  test('a time after now does not become the newest rang', () async {
    final log = ProofLog(_MemoryStore(), now: () => now);
    await log.markRang(DateTime(2026, 10, 6, 10));
    await log.markRang(DateTime(2026, 10, 20, 10));
    expect(log.newestRangAt(), DateTime(2026, 10, 6, 10));
  });

  test('a throwing store reaches the caller and the log goes on', () async {
    final log = ProofLog(_ThrowingStore(), now: () => now);
    await expectLater(log.markRang(now), throwsStateError);
    await expectLater(log.markFailed(now), throwsStateError);
    await expectLater(log.clear(), throwsStateError);
  });
}
