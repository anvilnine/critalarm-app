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
      () => ring.firstToolIncidentId,
      ring.forgetFirstTool,
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

  test('a throw in the read still loads the alarm', () async {
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
      () => throw StateError('prefs'),
    );
    addTearDown(throwing.close);

    await throwing.load(incidentId: realId);

    expect(throwing.state.status, CriticalAlarmStatus.ringing);
    expect(throwing.state.incident?.id, realId);
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
