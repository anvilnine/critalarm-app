import 'dart:async';

import 'package:critalarm/app/state/incidents_cubit.dart';
import 'package:critalarm/core/failures/failure.dart';
import 'package:critalarm/core/result/result.dart';
import 'package:critalarm/features/incidents/domain/entities/incident.dart';
import 'package:critalarm/features/incidents/domain/setup_test_kind.dart';
import 'package:critalarm/features/incidents/domain/usecases/acknowledge_incident_usecase.dart';
import 'package:critalarm/features/incidents/domain/usecases/close_incident_usecase.dart';
import 'package:critalarm/features/incidents/domain/usecases/get_incident_usecase.dart';
import 'package:critalarm/features/incidents/domain/usecases/get_incidents_usecase.dart';
import 'package:critalarm/features/incidents/presentation/cubits/critical_alarm_cubit.dart';
import 'package:critalarm/features/incidents/presentation/cubits/critical_alarm_state.dart';
import 'package:critalarm/features/onboarding/domain/usecases/end_setup_test_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../core/alarm/fake_alarm_host.dart';
import '../onboarding/support/fake_setup_test_ring.dart';

class _MockGetIncident extends Mock implements GetIncidentUsecase {}

class _MockGetIncidents extends Mock implements GetIncidentsUsecase {}

class _MockAck extends Mock implements AcknowledgeIncidentUsecase {}

class _MockClose extends Mock implements CloseIncidentUsecase {}

/// Continue on the acknowledged screen of a setup test closes the test on
/// the server. A real alarm must never be closed, silenced or walked away
/// from by that.
void main() {
  const testId = 'inc_test';
  const realId = 'inc_real';
  final openedAt = DateTime(2026, 10, 4, 21, 45);

  Incident incident(String id, {String state = IncidentStates.open}) =>
      Incident(id: id, topic: 'prod-db', openedAt: openedAt, state: state);

  late _MockGetIncident getIncident;
  late _MockGetIncidents getIncidents;
  late _MockAck ack;
  late _MockClose close;
  late FakeAlarmHost alarm;
  late FakeSetupTestRing ring;
  late IncidentsCubit incidents;
  late CriticalAlarmCubit cubit;

  setUpAll(() {
    registerFallbackValue(const GetIncidentsParams());
  });

  setUp(() {
    getIncident = _MockGetIncident();
    getIncidents = _MockGetIncidents();
    ack = _MockAck();
    close = _MockClose();
    alarm = FakeAlarmHost();
    ring = FakeSetupTestRing([testId]);
    when(() => getIncidents(any())).thenAnswer(
      (_) async => <Incident>[].toSuccess(),
    );
    incidents = IncidentsCubit(getIncidents);
    when(() => getIncident(any())).thenAnswer(
      (i) async => incident(i.positionalArguments[0] as String).toSuccess(),
    );
    when(() => ack(any())).thenAnswer(
      (i) async => incident(
        i.positionalArguments[0] as String,
        state: IncidentStates.acked,
      ).toSuccess(),
    );
    when(() => close(any())).thenAnswer(
      (i) async => incident(
        i.positionalArguments[0] as String,
        state: IncidentStates.closed,
      ).toSuccess(),
    );
    cubit = CriticalAlarmCubit(
      getIncident,
      getIncidents,
      ack,
      close,
      incidents,
      alarm.host,
      const Duration(seconds: 1),
      null,
      null,
      null,
      () => ring.incidentIds,
      () => true,
      EndSetupTestUsecase(ring, ack, close),
    );
  });

  tearDown(() async {
    await cubit.close();
    await incidents.close();
    alarm.dispose();
  });

  /// The setup test rang and the user tapped I'm up.
  Future<void> ackTheTest() async {
    await cubit.load(incidentId: testId);
    await cubit.acknowledge();
    expect(cubit.state.isAcknowledged, isTrue);
    expect(cubit.state.setupTest, SetupTestKind.serverSent);
    alarm.calls.clear();
    clearInteractions(ack);
    clearInteractions(close);
  }

  List<Object?> cancelledIds() => [
    for (final args in alarm.argsTo('cancelAlarm')) args['incident_id'],
  ];

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  test('Continue closes the setup test and may move on', () async {
    await ackTheTest();

    final mayContinue = await cubit.closeSetupTests(testId);

    expect(mayContinue, isTrue);
    verify(() => close(testId)).called(1);
    // The user already acknowledged it on the alarm screen.
    verifyNever(() => ack(any()));
    expect(cancelledIds(), [testId]);
    expect(ring.unclosedIds, isEmpty);
  });

  test('a real alarm that arrives during the close is not walked away from, '
      'closed or silenced', () async {
    await ackTheTest();
    final answer = Completer<AppResult<Incident>>();
    when(() => close(testId)).thenAnswer((_) => answer.future);

    final closing = cubit.closeSetupTests(testId);
    await settle();
    // A real alarm lands while the server is being asked. The cubit hands
    // the screen to it.
    incidents.applyIncident(incident(realId));
    await settle();
    expect(cubit.state.incident?.id, realId);
    answer.complete(
      incident(testId, state: IncidentStates.closed).toSuccess(),
    );

    expect(await closing, isFalse, reason: 'setup must not navigate away');
    expect(cubit.state.incident?.id, realId);
    expect(cubit.state.status, CriticalAlarmStatus.ringing);
    expect(cubit.state.isAcknowledged, isFalse);
    verifyNever(() => close(realId));
    verifyNever(() => ack(realId));
    expect(cancelledIds(), isNot(contains(realId)));
    expect(alarm.callsTo('stopRinging'), isEmpty);
  });

  test('a real alarm that took the screen over before the tap is left '
      'alone', () async {
    await ackTheTest();
    incidents.applyIncident(incident(realId));
    await settle();
    expect(cubit.state.incident?.id, realId);

    // The button was drawn for the test and still says so.
    final mayContinue = await cubit.closeSetupTests(testId);

    expect(mayContinue, isFalse);
    verifyNever(() => close(any()));
    verifyNever(() => ack(any()));
    expect(alarm.callsTo('cancelAlarm'), isEmpty);
    expect(alarm.callsTo('stopRinging'), isEmpty);
    expect(cubit.state.incident?.id, realId);
    expect(cubit.state.status, CriticalAlarmStatus.ringing);
  });

  test('an id that is not a stored setup test is never closed', () async {
    ring = FakeSetupTestRing();
    await cubit.load(incidentId: realId);
    await cubit.acknowledge();
    clearInteractions(close);
    alarm.calls.clear();

    expect(await cubit.closeSetupTests(realId), isFalse);

    verifyNever(() => close(any()));
    expect(alarm.callsTo('cancelAlarm'), isEmpty);
  });

  test('every test of the run is ended, the unanswered ones too', () async {
    // Try again sent a second test. The first never rang here and is still
    // open on the server.
    ring = FakeSetupTestRing(['inc_first', testId]);
    await ackTheTest();

    expect(await cubit.closeSetupTests(testId), isTrue);

    verify(() => close(testId)).called(1);
    verify(() => ack('inc_first')).called(1);
    verify(() => close('inc_first')).called(1);
    verifyNever(() => ack(testId));
    expect(cancelledIds(), [testId, 'inc_first']);
  });

  test('a close that fails is tried once more, then kept for later', () async {
    await ackTheTest();
    when(() => close(testId)).thenAnswer(
      (_) async => const Failure.api(statusCode: 503).toFailure(),
    );

    final mayContinue = await cubit.closeSetupTests(testId);

    verify(() => close(testId)).called(2);
    expect(ring.unclosedIds, {testId});
    // No longer a setup test: a later ring from it proves nothing.
    expect(ring.incidentIds, isNot(contains(testId)));
    expect(
      setupTestKind(
        incidentId: testId,
        setupTestIncidentIds: ring.incidentIds,
      ),
      SetupTestKind.none,
    );
    // Setup is not held up by it.
    expect(mayContinue, isTrue);
  });

  test('a close that works the second time leaves nothing behind', () async {
    await ackTheTest();
    var calls = 0;
    when(() => close(testId)).thenAnswer((_) async {
      calls++;
      return calls == 1
          ? const Failure.unexpected(message: 'SocketException').toFailure()
          : incident(testId, state: IncidentStates.closed).toSuccess();
    });

    await cubit.closeSetupTests(testId);

    expect(calls, 2);
    expect(ring.unclosedIds, isEmpty);
    expect(ring.incidentIds, contains(testId));
  });

  group('the next app open', () {
    test('closes what was left, acknowledging first', () async {
      ring = FakeSetupTestRing();
      await ring.markUnclosed(testId);
      final end = EndSetupTestUsecase(ring, ack, close);

      await end.closeLeftovers();

      verifyInOrder([() => ack(testId), () => close(testId)]);
      expect(ring.unclosedIds, isEmpty);
    });

    test('keeps the id when the server still cannot be reached', () async {
      ring = FakeSetupTestRing();
      await ring.markUnclosed(testId);
      when(() => ack(testId)).thenAnswer(
        (_) async =>
            const Failure.unexpected(message: 'SocketException').toFailure(),
      );

      await EndSetupTestUsecase(ring, ack, close).closeLeftovers();

      verifyNever(() => close(any()));
      expect(ring.unclosedIds, {testId});
    });

    test(
      'drops an id the server no longer knows or already finished',
      () async {
        for (final status in [404, 410]) {
          ring = FakeSetupTestRing();
          await ring.markUnclosed(testId);
          when(() => ack(testId)).thenAnswer(
            (_) async => Failure.api(statusCode: status).toFailure(),
          );
          await EndSetupTestUsecase(ring, ack, close).closeLeftovers();
          expect(ring.unclosedIds, isEmpty, reason: '$status');
        }
        // Already acknowledged (409 on the ack), already closed (409 on the
        // close).
        ring = FakeSetupTestRing();
        await ring.markUnclosed(testId);
        when(() => ack(testId)).thenAnswer(
          (_) async => const Failure.api(statusCode: 409).toFailure(),
        );
        when(() => close(testId)).thenAnswer(
          (_) async => const Failure.api(statusCode: 409).toFailure(),
        );
        await EndSetupTestUsecase(ring, ack, close).closeLeftovers();
        expect(ring.unclosedIds, isEmpty);
      },
    );

    test('with nothing left it calls nothing', () async {
      ring = FakeSetupTestRing([testId]);
      await EndSetupTestUsecase(ring, ack, close).closeLeftovers();
      verifyNever(() => ack(any()));
      verifyNever(() => close(any()));
    });
  });

  group('loading an alarm during setup', () {
    CriticalAlarmCubit build({
      Set<String> Function()? ids,
      Future<bool> Function()? ownsTopic,
    }) => CriticalAlarmCubit(
      getIncident,
      getIncidents,
      ack,
      close,
      null,
      null,
      const Duration(seconds: 1),
      null,
      null,
      ownsTopic,
      ids,
      () => true,
    );

    test(
      'a throw while reading the stored ids still loads the alarm',
      () async {
        final loading = build(ids: () => throw StateError('prefs'));
        addTearDown(loading.close);

        await loading.load(incidentId: realId);

        expect(loading.state.status, CriticalAlarmStatus.ringing);
        expect(loading.state.incident?.id, realId);
        expect(loading.state.setupTest, SetupTestKind.none);
      },
    );

    test('a throw in the setup reads still loads the alarm', () async {
      final loading = build(
        ids: () => {testId},
        ownsTopic: () async => throw StateError('engine'),
      );
      addTearDown(loading.close);

      await loading.load(incidentId: realId);

      expect(loading.state.status, CriticalAlarmStatus.ringing);
      expect(loading.state.incident?.id, realId);
    });
  });
}
