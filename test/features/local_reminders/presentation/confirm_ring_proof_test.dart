import 'package:critalarm/core/failures/failure.dart';
import 'package:critalarm/core/models/topic.dart';
import 'package:critalarm/core/result/result.dart';
import 'package:critalarm/features/local_reminders/data/shared_prefs_local_reminder_store.dart';
import 'package:critalarm/features/local_reminders/presentation/cubits/confirm_ring_cubit.dart';
import 'package:critalarm/features/local_reminders/presentation/cubits/confirm_ring_state.dart';
import 'package:critalarm/features/reliability/domain/proof/proof_entry.dart';
import 'package:critalarm/features/reliability/domain/proof/proof_log.dart';
import 'package:critalarm/features/reliability/domain/proof/proof_log_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

/// A failed test is written into the proof log after the phone's own
/// failed-test stamp, and a log that fails changes nothing about the
/// screen.
void main() {
  final now = DateTime(2026, 10, 7, 9);
  late SharedPrefsLocalReminderStore store;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = SharedPrefsLocalReminderStore(
      await SharedPreferences.getInstance(),
    );
  });

  ConfirmRingCubit build(
    ProofLogStore proof,
    Future<AppResult<String>> Function(String topic) trigger,
  ) => ConfirmRingCubit(
    readTopics: () async => const [Topic(name: 'prod-db', critical: true)],
    readIncidents: () async => const [],
    triggerTest: trigger,
    store: store,
    canTestNormalTopics: false,
    now: () => now,
    proofLog: ProofLog(proof, now: () => now),
  );

  Future<AppResult<String>> conflict(String topic) async =>
      const Failure.api(statusCode: 409).toFailure<String>();

  test('a failed test marks this week as failed', () async {
    final proof = _MemoryStore();
    final cubit = build(proof, conflict);
    await cubit.load();
    await cubit.send();
    expect(proof.entries.single.key, '2026-10-05');
    expect(proof.entries.single.failedAt, now);
    expect(proof.entries.single.rangAt, isNull);
  });

  test('a test that was sent writes nothing', () async {
    final proof = _MemoryStore();
    final cubit = build(
      proof,
      (topic) async => const Success<String, Failure>('inc_t1'),
    );
    await cubit.load();
    await cubit.send();
    expect(proof.entries, isEmpty);
  });

  test('an error that is not a failed test writes nothing', () async {
    final proof = _MemoryStore();
    final cubit = build(
      proof,
      (topic) async => const Failure.api(statusCode: 500).toFailure<String>(),
    );
    await cubit.load();
    await cubit.send();
    expect(proof.entries, isEmpty);
  });

  test('a throwing log still stamps the failure and shows the error', () async {
    final cubit = build(_ThrowingStore(), conflict);
    await cubit.load();
    await cubit.send();
    expect(store.readLastTestFailedAt(), now);
    expect(cubit.state.status, ConfirmRingStatus.ready);
    expect(cubit.state.failure, isNotNull);
  });
}
