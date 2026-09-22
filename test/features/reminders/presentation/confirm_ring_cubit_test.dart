import 'package:critalarm/core/failures/failure.dart';
import 'package:critalarm/core/models/incident.dart';
import 'package:critalarm/core/models/topic.dart';
import 'package:critalarm/core/result/result.dart';
import 'package:critalarm/features/reminders/data/shared_prefs_reminder_store.dart';
import 'package:critalarm/features/reminders/domain/ring_failure.dart';
import 'package:critalarm/features/reminders/presentation/cubits/confirm_ring_cubit.dart';
import 'package:critalarm/features/reminders/presentation/cubits/confirm_ring_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late SharedPrefsReminderStore store;
  final now = DateTime(2026, 10, 3, 10);
  const topics = [
    Topic(name: 'db-2', critical: true),
    Topic(name: 'prod-db', critical: true),
    Topic(name: 'backups'),
  ];

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = SharedPrefsReminderStore(await SharedPreferences.getInstance());
    await store.markTested('prod-db', DateTime(2026, 8, 30, 10));
    await store.markTested('db-2', DateTime(2026, 9, 21, 10));
  });

  ConfirmRingCubit build({
    Future<AppResult<String>> Function(String topic)? trigger,
    bool canTestNormalTopics = false,
    List<Topic>? readTopics = topics,
    List<Incident>? incidents = const [],
  }) => ConfirmRingCubit(
    readTopics: () async => readTopics,
    readIncidents: () async => incidents,
    triggerTest:
        trigger ?? (topic) async => const Success<String, Failure>('inc_t1'),
    store: store,
    canTestNormalTopics: canTestNormalTopics,
    now: () => now,
  );

  test(
    'lists critical topics tested longest ago first, and picks it',
    () async {
      final cubit = build();
      await cubit.load();
      expect(cubit.state.status, ConfirmRingStatus.ready);
      expect(cubit.state.critical.map((r) => r.name), ['prod-db', 'db-2']);
      expect(cubit.state.critical.first.daysSinceTest, 34);
      expect(cubit.state.selected, 'prod-db');
      expect(cubit.state.normal, isEmpty);
    },
  );

  test('hides topics with an open or acked incident', () async {
    final cubit = build(
      canTestNormalTopics: true,
      incidents: const [
        Incident(id: 'i1', topic: 'prod-db', state: 'acked'),
        Incident(id: 'i2', topic: 'backups'),
        Incident(id: 'i3', topic: 'db-2', state: 'closed'),
      ],
    );
    await cubit.load();
    expect(cubit.state.critical.map((r) => r.name), ['db-2']);
    expect(cubit.state.normal, isEmpty);
    expect(cubit.state.selected, 'db-2');
  });

  test('lists every topic when incidents cannot be read', () async {
    final cubit = build(incidents: null);
    await cubit.load();
    expect(cubit.state.critical.map((r) => r.name), ['prod-db', 'db-2']);
  });

  test('a failed topics load is a load failure, not an empty list', () async {
    final cubit = build(readTopics: null);
    await cubit.load();
    expect(cubit.state.status, ConfirmRingStatus.loadFailed);
    expect(cubit.state.critical, isEmpty);
    expect(cubit.state.selected, isNull);
  });

  test('lists normal topics only once the server can test them', () async {
    final cubit = build(canTestNormalTopics: true);
    await cubit.load();
    expect(cubit.state.normal.single.name, 'backups');
    expect(cubit.state.normal.single.daysSinceTest, isNull);
  });

  test('a sent test ends in sent', () async {
    final cubit = build();
    await cubit.load();
    await cubit.send();
    expect(cubit.state.status, ConfirmRingStatus.sent);
    expect(store.readLastTestFailedAt(), isNull);
  });

  test('a 409 shows the error here and records a failed test', () async {
    final cubit = build(
      trigger: (topic) async =>
          const Failure.api(statusCode: 409).toFailure<String>(),
    );
    await cubit.load();
    await cubit.send();
    expect(cubit.state.status, ConfirmRingStatus.ready);
    expect(cubit.state.failure, RingFailure.notCritical);
    expect(store.readLastTestFailedAt(), now);
  });

  test('a 500 shows an error but is not a failed test', () async {
    final cubit = build(
      trigger: (topic) async =>
          const Failure.api(statusCode: 500).toFailure<String>(),
    );
    await cubit.load();
    await cubit.send();
    expect(cubit.state.failure, RingFailure.other);
    expect(store.readLastTestFailedAt(), isNull);
  });

  test('select moves the choice', () async {
    final cubit = build();
    await cubit.load();
    cubit.select('db-2');
    expect(cubit.state.selected, 'db-2');
  });
}
