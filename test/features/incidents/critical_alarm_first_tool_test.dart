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
import 'package:critalarm/features/onboarding/domain/real_ring/setup_test_ring.dart';
import 'package:critalarm/features/onboarding/domain/usecases/end_setup_test_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../core/alarm/fake_alarm_host.dart';
import '../onboarding/support/fake_setup_test_ring.dart';

class _MockGetIncident extends Mock implements GetIncidentUsecase {}

class _MockGetIncidents extends Mock implements GetIncidentsUsecase {}

class _MockAck extends Mock implements AcknowledgeIncidentUsecase {}

class _MockClose extends Mock implements CloseIncidentUsecase {}

/// The alarm the user's own tool sets off from the last setup step gets an
/// acknowledged screen of its own, with one button that ends that one
/// incident. Nothing about it may close, silence or walk away from any
/// other alarm, and while it rings it is a real alarm with every control.
void main() {
  const toolId = 'inc_tool';
  const realId = 'inc_real';
  final openedAt = DateTime(2026, 10, 4, 21, 45);

  Incident incident(
    String id, {
    String state = IncidentStates.open,
    DateTime? at,
  }) => Incident(
    id: id,
    topic: id == toolId ? 'setup-topic' : 'prod-db',
    openedAt: at ?? openedAt,
    // The server stamps every incident with its newest message.
    lastMessageAt: at ?? openedAt,
    state: state,
  );

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

  setUp(() async {
    getIncident = _MockGetIncident();
    getIncidents = _MockGetIncidents();
    ack = _MockAck();
    close = _MockClose();
    alarm = FakeAlarmHost();
    ring = FakeSetupTestRing();
    // The hook-up step heard the alarm and put it on record. Setup is
    // complete by the time its screen opens.
    await ring.holdFirstMessage(toolId);
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
      ring,
    );
  });

  tearDown(() async {
    await cubit.close();
    await incidents.close();
    alarm.dispose();
  });

  List<Object?> cancelledIds() => [
    for (final args in alarm.argsTo('cancelAlarm')) args['incident_id'],
  ];

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  /// The tool's alarm rang and the user tapped I'm up.
  Future<void> ackTheToolAlarm() async {
    await cubit.load(incidentId: toolId);
    await cubit.acknowledge();
    expect(cubit.state.isAcknowledged, isTrue);
    alarm.calls.clear();
    clearInteractions(ack);
    clearInteractions(close);
  }

  group('while it rings', () {
    test('it is a real alarm with every control, not a setup test', () async {
      await cubit.load(incidentId: toolId);

      expect(cubit.state.status, CriticalAlarmStatus.ringing);
      expect(cubit.state.isLive, isTrue);
      expect(cubit.state.setupTest, SetupTestKind.none);
      // The ringing screen keeps the way to the message for it.
      expect(cubit.state.ackedExits.isSetupTest, isFalse);
    });

    test("I'm up acknowledges it on the server like any alarm", () async {
      await cubit.load(incidentId: toolId);

      await cubit.acknowledge();

      verify(() => ack(toolId)).called(1);
      verifyNever(() => close(any()));
      expect(cubit.state.isAcknowledged, isTrue);
    });
  });

  group('its acknowledged screen', () {
    test('is the setup one', () async {
      await ackTheToolAlarm();

      expect(cubit.state.isFirstToolAlarm, isTrue);
      expect(cubit.state.ackedExits, AckedExits.firstToolAlarm);
    });

    test('the button closes that incident and may leave', () async {
      await ackTheToolAlarm();

      final mayLeave = await cubit.finishFirstToolAlarm(toolId);

      expect(mayLeave, isTrue);
      verify(() => close(toolId)).called(1);
      // Already acknowledged on the alarm screen.
      verifyNever(() => ack(any()));
      expect(cancelledIds(), [toolId]);
      expect(ring.firstToolIncidentId, isNull);
    });

    test('a close that fails still lets the user leave, and the incident '
        'is from then on an alarm like any other', () async {
      await ackTheToolAlarm();
      when(() => close(toolId)).thenAnswer(
        (_) async => const Failure.unexpected(message: 'offline').toFailure(),
      );

      expect(await cubit.finishFirstToolAlarm(toolId), isTrue);

      verify(() => close(toolId)).called(2);
      expect(ring.firstToolIncidentId, isNull);
    });
  });

  group('a real alarm from another topic', () {
    test('takes the screen over from the setup acknowledged screen and '
        'rings with every control', () async {
      await ackTheToolAlarm();

      incidents.applyIncident(incident(realId));
      await settle();

      expect(cubit.state.incident?.id, realId);
      expect(cubit.state.status, CriticalAlarmStatus.ringing);
      expect(cubit.state.isLive, isTrue);
      expect(cubit.state.isAcknowledged, isFalse);
      expect(cubit.state.ackedExits, AckedExits.incident);
      expect(cubit.state.ackedExits.isSetupTest, isFalse);
      // Nothing silenced it on the way.
      expect(cancelledIds(), isEmpty);
      verifyNever(() => close(any()));
    });

    test('that took the screen over before the tap is left alone', () async {
      await ackTheToolAlarm();
      incidents.applyIncident(incident(realId));
      await settle();

      // The tap lands on a button drawn for the tool alarm.
      final mayLeave = await cubit.finishFirstToolAlarm(toolId);

      expect(mayLeave, isFalse);
      verifyNever(() => close(any()));
      verifyNever(() => ack(any()));
      expect(cancelledIds(), isEmpty);
      expect(cubit.state.incident?.id, realId);
      expect(cubit.state.isLive, isTrue);
      // Still owed its own screen.
      expect(ring.firstToolIncidentId, toolId);
    });

    test('that arrives during the close is not closed, silenced or walked '
        'away from', () async {
      await ackTheToolAlarm();
      final answer = Completer<AppResult<Incident>>();
      when(() => close(toolId)).thenAnswer((_) => answer.future);

      final finishing = cubit.finishFirstToolAlarm(toolId);
      await settle();
      incidents.applyIncident(incident(realId));
      await settle();
      expect(cubit.state.incident?.id, realId);
      answer.complete(
        incident(toolId, state: IncidentStates.closed).toSuccess(),
      );

      expect(await finishing, isFalse);
      expect(cubit.state.incident?.id, realId);
      expect(cubit.state.isLive, isTrue);
      verifyNever(() => close(realId));
      expect(cancelledIds(), [toolId]);
    });

    test('acknowledged on its own gets the normal screen', () async {
      await cubit.load(incidentId: realId);
      await cubit.acknowledge();

      expect(cubit.state.isFirstToolAlarm, isFalse);
      expect(cubit.state.ackedExits, AckedExits.incident);
      expect(await cubit.finishFirstToolAlarm(realId), isFalse);
      verifyNever(() => close(any()));
    });
  });

  test('an id that is not the first tool alarm is never closed', () async {
    await ackTheToolAlarm();

    expect(await cubit.finishFirstToolAlarm(realId), isFalse);

    verifyNever(() => close(any()));
    expect(cancelledIds(), isEmpty);
  });

  test('with no first tool alarm on record, the same incident is a normal '
      'alarm', () async {
    await ring.forgetFirstTool();

    await cubit.load(incidentId: toolId);
    await cubit.acknowledge();

    expect(cubit.state.ackedExits, AckedExits.incident);
    expect(await cubit.finishFirstToolAlarm(toolId), isFalse);
    verifyNever(() => close(any()));
  });

  test('a store that throws still loads the alarm, as a normal one', () async {
    final throwing = CriticalAlarmCubit(
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
      null,
      null,
      null,
      _ThrowingRing(),
    );
    addTearDown(throwing.close);

    await throwing.load(incidentId: toolId);
    expect(throwing.state.status, CriticalAlarmStatus.ringing);
    expect(throwing.state.incident?.id, toolId);

    await throwing.acknowledge();
    expect(throwing.state.ackedExits, AckedExits.incident);
  });

  /// Everything a real alarm's acknowledged screen has: the normal exits,
  /// At my desk still to tap, and nothing of the setup screen.
  void expectNormalAckedScreen() {
    expect(cubit.state.isAcknowledged, isTrue);
    expect(cubit.state.status, CriticalAlarmStatus.acknowledged);
    expect(cubit.state.isFirstToolAlarm, isFalse);
    expect(cubit.state.ackedExits, AckedExits.incident);
    expect(cubit.state.ackedExits.isSetupTest, isFalse);
  }

  group('the same incident id later is a real alarm', () {
    /// The first ring was acknowledged and the user left without Finish.
    Future<void> ackAndLeave() async {
      await ackTheToolAlarm();
      expect(cubit.state.ackedExits, AckedExits.firstToolAlarm);
      expect(ring.firstTool?.wasAcked, isTrue);
      expect(ring.firstTool?.openedAt, openedAt);
    }

    test('a real alert joins it and the desk timer reopens it', () async {
      await ackAndLeave();
      // Ten minutes on the server reopened it under the same id, with a
      // new opened_at and the message that joined.
      final reopenedAt = openedAt.add(const Duration(minutes: 10));
      when(() => getIncident(toolId)).thenAnswer(
        (_) async => incident(
          toolId,
          at: reopenedAt,
        ).copyWith(lastMessageAt: reopenedAt).toSuccess(),
      );
      when(() => ack(toolId)).thenAnswer(
        (_) async => incident(
          toolId,
          state: IncidentStates.acked,
          at: reopenedAt,
        ).copyWith(lastMessageAt: reopenedAt).toSuccess(),
      );

      await cubit.load(incidentId: toolId);

      // It rings as a real alarm, and the record is gone for good.
      expect(cubit.state.status, CriticalAlarmStatus.ringing);
      expect(cubit.state.isLive, isTrue);
      expect(cubit.state.isFirstToolAlarm, isFalse);
      expect(ring.firstTool, isNull);

      await cubit.acknowledge();

      expectNormalAckedScreen();
      expect(await cubit.finishFirstToolAlarm(toolId), isFalse);
      verifyNever(() => close(any()));
    });

    test('the desk timer reopens it with nothing else changed', () async {
      await ackAndLeave();
      // Same opened_at, same messages: only "open again after the first
      // acknowledgement" tells it apart.

      await cubit.load(incidentId: toolId);

      expect(cubit.state.status, CriticalAlarmStatus.ringing);
      expect(ring.firstTool, isNull);
      await cubit.acknowledge();
      expectNormalAckedScreen();
    });

    test('a message joins it while it is still acknowledged', () async {
      await ackAndLeave();
      final joinedAt = openedAt.add(const Duration(minutes: 3));
      when(() => getIncident(toolId)).thenAnswer(
        (_) async => incident(
          toolId,
          state: IncidentStates.acked,
        ).copyWith(lastMessageAt: joinedAt).toSuccess(),
      );

      await cubit.load(incidentId: toolId);

      expectNormalAckedScreen();
      expect(ring.firstTool, isNull);
    });

    test('a reopen that reaches the screen through the shared list', () async {
      await ackAndLeave();

      incidents.applyIncident(
        incident(toolId, at: openedAt.add(const Duration(minutes: 10))),
      );
      await settle();

      expect(cubit.state.status, CriticalAlarmStatus.ringing);
      expect(cubit.state.isFirstToolAlarm, isFalse);
      expect(ring.firstTool, isNull);
    });

    test('the app was opened again after the first acknowledgement', () async {
      await ackAndLeave();

      // What main() does on launch, before any screen.
      await ring.settleFirstToolAtLaunch();
      expect(ring.firstTool, isNull);
      // Still acknowledged on the server, exactly as it was left.
      when(() => getIncident(toolId)).thenAnswer(
        (_) async => incident(toolId, state: IncidentStates.acked).toSuccess(),
      );
      await cubit.load(incidentId: toolId);

      expectNormalAckedScreen();
      expect(await cubit.finishFirstToolAlarm(toolId), isFalse);
      verifyNever(() => close(any()));
    });

    test('an opened_at later than the hook-up step heard it', () async {
      // Acknowledged from the notification, so the alarm screen never saw
      // the first ring. The reopen is still told apart by its time.
      when(() => getIncident(toolId)).thenAnswer(
        (_) async => incident(
          toolId,
          at: ring.heldAt.add(const Duration(minutes: 10)),
        ).toSuccess(),
      );

      await cubit.load(incidentId: toolId);
      await cubit.acknowledge();

      expectNormalAckedScreen();
      expect(ring.firstTool, isNull);
    });
  });

  test(
    'the alarm starting the app from cold is still the first ring',
    () async {
      // Not acknowledged yet, so launch keeps the record.
      await ring.settleFirstToolAtLaunch();

      await cubit.load(incidentId: toolId);
      await cubit.acknowledge();

      expect(cubit.state.ackedExits, AckedExits.firstToolAlarm);
    },
  );

  test('when the phone no longer holds the record, Finish gives way to the '
      'normal screen instead of doing nothing forever', () async {
    await ackTheToolAlarm();
    expect(cubit.state.ackedExits, AckedExits.firstToolAlarm);
    // Gone from the phone behind the screen's back.
    ring.firstTool = null;

    expect(await cubit.finishFirstToolAlarm(toolId), isFalse);

    expectNormalAckedScreen();
    verifyNever(() => close(any()));
    expect(cancelledIds(), isEmpty);
  });

  test('a look at the screen sends and saves nothing', () async {
    cubit.previewFirstToolAlarm();

    expect(cubit.state.ackedExits, AckedExits.firstToolAlarm);
    final id = cubit.state.incident!.id;
    expect(await cubit.finishFirstToolAlarm(id), isTrue);

    verifyNever(() => close(any()));
    verifyNever(() => ack(any()));
    expect(cancelledIds(), isEmpty);
    expect(ring.firstToolIncidentId, toolId);
  });
}

class _ThrowingRing extends FakeSetupTestRing {
  @override
  FirstToolAlarm? get firstTool => throw StateError('prefs');

  @override
  String? get firstToolIncidentId => throw StateError('prefs');
}
