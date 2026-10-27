import 'package:critalarm/app/state/incidents_cubit.dart';
import 'package:critalarm/core/models/message.dart';
import 'package:critalarm/core/result/result.dart';
import 'package:critalarm/features/incidents/domain/entities/incident.dart';
import 'package:critalarm/features/incidents/domain/usecases/acknowledge_incident_usecase.dart';
import 'package:critalarm/features/incidents/domain/usecases/close_incident_usecase.dart';
import 'package:critalarm/features/incidents/domain/usecases/get_incident_usecase.dart';
import 'package:critalarm/features/incidents/domain/usecases/get_incidents_usecase.dart';
import 'package:critalarm/features/incidents/presentation/cubits/critical_alarm_cubit.dart';
import 'package:critalarm/features/incidents/presentation/cubits/critical_alarm_state.dart';
import 'package:critalarm/features/local_reminders/domain/incident_kinds.dart';
import 'package:critalarm/features/reliability/domain/proof/proof_entry.dart';
import 'package:critalarm/features/reliability/domain/proof/proof_log.dart';
import 'package:critalarm/features/reliability/domain/proof/proof_log_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockGetIncident extends Mock implements GetIncidentUsecase {}

class _MockGetIncidents extends Mock implements GetIncidentsUsecase {}

class _MockAck extends Mock implements AcknowledgeIncidentUsecase {}

class _MockClose extends Mock implements CloseIncidentUsecase {}

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

/// A test alarm the server sent is written into the proof log when the
/// alarm screen loads it. Nothing else is, and the log never stops the
/// alarm.
void main() {
  final now = DateTime(2026, 10, 7, 9);
  late _MockGetIncident getIncident;
  late _MockGetIncidents getIncidents;
  late _MockAck ack;
  late _MockClose close;
  late IncidentsCubit incidents;
  final cubits = <CriticalAlarmCubit>[];

  Incident incident(
    String id, {
    String? title,
    String state = IncidentStates.open,
  }) => Incident(
    id: id,
    topic: 'prod-db',
    state: state,
    openedAt: now,
    lastMessageAt: now,
    messages: [
      Message(id: 'm_$id', topic: 'prod-db', title: title, priority: 5),
    ],
  );

  CriticalAlarmCubit build(ProofLogStore store) {
    final cubit = CriticalAlarmCubit(
      getIncident,
      getIncidents,
      ack,
      close,
      incidents,
      null,
      const Duration(seconds: 1),
      () => now,
      null,
      null,
      null,
      null,
      null,
      null,
      ProofLog(store, now: () => now),
    );
    cubits.add(cubit);
    return cubit;
  }

  setUpAll(() => registerFallbackValue(const GetIncidentsParams()));

  setUp(() {
    getIncident = _MockGetIncident();
    getIncidents = _MockGetIncidents();
    ack = _MockAck();
    close = _MockClose();
    when(() => getIncidents(any())).thenAnswer(
      (_) async => <Incident>[].toSuccess(),
    );
    incidents = IncidentsCubit(getIncidents);
  });

  tearDown(() async {
    for (final cubit in cubits) {
      await cubit.close();
    }
    cubits.clear();
    await incidents.close();
  });

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  void serve(Incident served) {
    when(() => getIncident(served.id)).thenAnswer(
      (_) async => served.toSuccess(),
    );
  }

  test('the server test marks this week as rang', () async {
    final store = _MemoryStore();
    serve(incident('inc_t', title: IncidentKinds.testAlarmTitle));
    await build(store).load(incidentId: 'inc_t');
    await settle();
    expect(store.entries.single.key, '2026-10-05');
    expect(store.entries.single.rangAt, now);
  });

  test('the open list works the same way', () async {
    final store = _MemoryStore();
    when(() => getIncidents(any())).thenAnswer(
      (_) async => [
        incident('inc_t', title: IncidentKinds.testAlarmTitle),
      ].toSuccess(),
    );
    await build(store).load();
    await settle();
    expect(store.entries.single.rangAt, now);
  });

  test('the onboarding demo marks nothing', () async {
    final store = _MemoryStore();
    await build(store).load(incidentId: IncidentKinds.demoIncidentId);
    await settle();
    expect(store.entries, isEmpty);
  });

  test('a real incident marks nothing', () async {
    final store = _MemoryStore();
    serve(incident('inc_r', title: 'Database is down'));
    await build(store).load(incidentId: 'inc_r');
    await settle();
    expect(store.entries, isEmpty);
  });

  test('a test that is already closed marks nothing', () async {
    final store = _MemoryStore();
    serve(
      incident(
        'inc_c',
        title: IncidentKinds.testAlarmTitle,
        state: IncidentStates.closed,
      ),
    );
    await build(store).load(incidentId: 'inc_c');
    await settle();
    expect(store.entries, isEmpty);
  });

  test('a throwing log still loads the alarm', () async {
    serve(incident('inc_t', title: IncidentKinds.testAlarmTitle));
    final cubit = build(_ThrowingStore());
    await cubit.load(incidentId: 'inc_t');
    await settle();
    expect(cubit.state.status, isNot(CriticalAlarmStatus.failure));
    expect(cubit.state.incident?.id, 'inc_t');
  });
}
