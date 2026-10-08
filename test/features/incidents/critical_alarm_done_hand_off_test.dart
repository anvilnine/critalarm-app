import 'package:critalarm/app/state/incidents_cubit.dart';
import 'package:critalarm/core/alarm/alarm_host.dart';
import 'package:critalarm/core/failures/failure.dart';
import 'package:critalarm/core/models/send_result.dart';
import 'package:critalarm/core/result/result.dart';
import 'package:critalarm/features/incidents/domain/done_hand_off.dart';
import 'package:critalarm/features/incidents/domain/entities/incident.dart';
import 'package:critalarm/features/incidents/domain/entities/message.dart';
import 'package:critalarm/features/incidents/domain/repositories/incident_repository.dart';
import 'package:critalarm/features/incidents/domain/usecases/acknowledge_incident_usecase.dart';
import 'package:critalarm/features/incidents/domain/usecases/close_incident_usecase.dart';
import 'package:critalarm/features/incidents/domain/usecases/get_incident_usecase.dart';
import 'package:critalarm/features/incidents/domain/usecases/get_incidents_usecase.dart';
import 'package:critalarm/features/incidents/presentation/cubits/critical_alarm_cubit.dart';
import 'package:critalarm/features/incidents/presentation/cubits/critical_alarm_state.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../core/alarm/fake_alarm_host.dart';

// A native Done button opens the app, in place of closing, while its topic
// owes a wake-up challenge. With no signal the app cannot load the incident,
// and must still let the person close it. The app decides nothing about the
// incident on that path: it hands the close back to native.

const _offline = Failure.unexpected(message: 'SocketException');

Failure _status(int code) => Failure.api(statusCode: code, message: 'no');

final _acked = Incident(
  id: 'inc_1',
  topic: 'prod-db',
  state: IncidentStates.acked,
  openedAt: DateTime.utc(2026, 10, 8, 3),
  ackedAt: DateTime.utc(2026, 10, 8, 3, 2),
);

final _ringing = Incident(
  id: 'inc_2',
  topic: 'nas',
  openedAt: DateTime.utc(2026, 10, 8, 4),
);

/// A server that answers what the test tells it to.
class _Server implements IncidentRepository {
  /// What `GET /v1/incidents/{id}` answers. Null hands the incident over.
  Failure? getFails;

  List<Incident> listed = const [];
  final List<String> closes = [];

  @override
  Future<AppResult<Incident>> getIncident(String id) async =>
      getFails?.toFailure() ?? _acked.toSuccess();

  @override
  Future<AppResult<Incident>> closeIncident(String id) async {
    closes.add(id);
    return _acked.copyWith(state: IncidentStates.closed).toSuccess();
  }

  @override
  Future<AppResult<List<Incident>>> getIncidents({
    required int limit,
    String? state,
    String? topic,
    DateTime? since,
    bool fullRefresh = false,
  }) async => listed.toSuccess();

  @override
  Future<AppResult<Incident>> ackIncident(String id) async =>
      _acked.toSuccess();

  @override
  Future<void> saveIncident(Incident incident) async {}

  @override
  Future<AppResult<String>> triggerTest({required String topic}) async =>
      throw UnimplementedError();

  @override
  Future<AppResult<SendResult>> publishMessage(
    String topic, {
    required String message,
    String? title,
    int priority = 3,
    List<String>? tags,
  }) async => throw UnimplementedError();

  @override
  Future<AppResult<List<Message>>> pollMessages(
    String topic, {
    required int poll,
    String? since,
  }) async => throw UnimplementedError();
}

void main() {
  late _Server server;
  late FakeAlarmHost alarm;
  late IncidentsCubit incidents;
  late CriticalAlarmCubit cubit;

  setUp(() async {
    server = _Server()..listed = [_acked];
    alarm = FakeAlarmHost();
    incidents = IncidentsCubit(GetIncidentsUsecase(server));
    await incidents.ensureLoaded();
    cubit = CriticalAlarmCubit(
      GetIncidentUsecase(server),
      GetIncidentsUsecase(server),
      AcknowledgeIncidentUsecase(server),
      CloseIncidentUsecase(server),
      incidents,
      alarm.host,
    );
  });

  tearDown(() async {
    await cubit.close();
    await incidents.close();
    alarm.dispose();
  });

  Future<void> openFromDone(Failure? failure) {
    server.getFails = failure;
    return cubit.load(incidentId: 'inc_1', cameFromDone: true);
  }

  group('serverGaveNoAnswer', () {
    test('offline, a timeout, 429 and 5xx are no answer', () {
      expect(serverGaveNoAnswer(_offline), isTrue);
      for (final code in [408, 429, 500, 502, 503, 504]) {
        expect(serverGaveNoAnswer(_status(code)), isTrue, reason: '$code');
      }
    });

    test('any other answer is the server speaking', () {
      for (final code in [400, 401, 403, 404, 409, 410, 422]) {
        expect(serverGaveNoAnswer(_status(code)), isFalse, reason: '$code');
      }
      for (final failure in const [
        Failure.notFound(),
        Failure.conflict(),
        Failure.unauthorized(),
        Failure.badRequest(),
      ]) {
        expect(serverGaveNoAnswer(failure), isFalse, reason: '$failure');
      }
    });
  });

  group('"At my desk" on the failed screen is offered', () {
    for (final failure in [_offline, _status(503), _status(429)]) {
      test('from a Done button, when the server gives no answer '
          '($failure)', () async {
        await openFromDone(failure);
        expect(cubit.state.status, CriticalAlarmStatus.failure);
        expect(cubit.state.doneIncidentId, 'inc_1');
        expect(cubit.state.isDoneHandedOff, isFalse);
        // The load alone hands nothing over.
        expect(alarm.callsTo('closeFromDone'), isEmpty);
      });
    }

    for (final code in [400, 401, 403, 404, 409, 410]) {
      test('never when the server answered $code', () async {
        await openFromDone(_status(code));
        expect(cubit.state.status, CriticalAlarmStatus.failure);
        expect(cubit.state.doneIncidentId, isNull);
      });
    }

    test('never without the marker: a plain card tap that fails is the '
        'screen it always was', () async {
      server.getFails = _offline;
      await cubit.load(incidentId: 'inc_1');
      expect(cubit.state.status, CriticalAlarmStatus.failure);
      expect(cubit.state.errorMessage, 'SocketException');
      expect(cubit.state.doneIncidentId, isNull);

      await cubit.handCloseToNative();
      expect(alarm.callsTo('closeFromDone'), isEmpty);
    });

    test('never after a load that worked: the server decides, marker or '
        'not', () async {
      await openFromDone(null);
      expect(cubit.state.status, CriticalAlarmStatus.acknowledged);
      expect(cubit.state.doneIncidentId, isNull);

      await cubit.handCloseToNative();
      expect(alarm.callsTo('closeFromDone'), isEmpty);
    });

    test('never for a load that names no incident', () async {
      await cubit.load(cameFromDone: true);
      expect(cubit.state.doneIncidentId, isNull);
    });
  });

  group('the hand-off', () {
    test('calls native once, with the incident id and nothing else', () async {
      await openFromDone(_offline);
      alarm.calls.clear();
      final listBefore = incidents.state;

      await cubit.handCloseToNative();

      // One call in all: nothing stopped, cancelled, marked or re-armed.
      expect(alarm.calls.map((call) => call.method), ['closeFromDone']);
      expect(alarm.argsOnce('closeFromDone'), {'incident_id': 'inc_1'});
      // The shared list is as it was, and no close went out from Dart.
      expect(incidents.state, same(listBefore));
      expect(incidents.state.incidents.single.state, IncidentStates.acked);
      expect(server.closes, isEmpty);
    });

    test('then says the close is on its way, and offers nothing more to '
        'close', () async {
      await openFromDone(_offline);
      await cubit.handCloseToNative();

      expect(cubit.state.isDoneHandedOff, isTrue);
      expect(cubit.state.doneIncidentId, isNull);
      expect(cubit.state.errorMessage, isNull);
      expect(cubit.state.incident, isNull);

      await cubit.handCloseToNative();
      expect(alarm.callsTo('closeFromDone'), hasLength(1));
    });

    test('two taps at once hand over once', () async {
      await openFromDone(_offline);
      await Future.wait([
        cubit.handCloseToNative(),
        cubit.handCloseToNative(),
      ]);
      expect(alarm.callsTo('closeFromDone'), hasLength(1));
    });

    test('a native call that fails claims nothing and keeps the '
        'button', () async {
      await openFromDone(_offline);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel(AlarmHost.channelName),
            (call) async => throw PlatformException(code: 'bad_args'),
          );

      await cubit.handCloseToNative();

      expect(cubit.state.isDoneHandedOff, isFalse);
      expect(cubit.state.doneIncidentId, 'inc_1');
    });

    test('a platform with no such call claims nothing either', () async {
      await openFromDone(_offline);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel(AlarmHost.channelName),
            null,
          );

      await cubit.handCloseToNative();

      expect(cubit.state.isDoneHandedOff, isFalse);
      expect(cubit.state.doneIncidentId, 'inc_1');
    });
  });

  group('what a failed load left behind is cleared', () {
    test('the offer, when another incident takes the screen', () async {
      await openFromDone(_offline);
      incidents.applyIncident(_ringing);
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.status, CriticalAlarmStatus.ringing);
      expect(cubit.state.incident?.id, 'inc_2');
      expect(cubit.state.doneIncidentId, isNull);

      // Nothing can be handed over for the incident that is gone from
      // the screen.
      await cubit.handCloseToNative();
      expect(alarm.callsTo('closeFromDone'), isEmpty);
    });

    test('the "on its way" note, when another incident takes the '
        'screen', () async {
      await openFromDone(_offline);
      await cubit.handCloseToNative();
      incidents.applyIncident(_ringing);
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.status, CriticalAlarmStatus.ringing);
      expect(cubit.state.isDoneHandedOff, isFalse);
    });

    test('both, by the next load', () async {
      await openFromDone(_offline);
      server.getFails = null;
      await cubit.load(incidentId: 'inc_1');
      expect(cubit.state.doneIncidentId, isNull);
      expect(cubit.state.isDoneHandedOff, isFalse);
    });

    test('a try again that fails the same way keeps the offer', () async {
      await openFromDone(_offline);
      await openFromDone(_offline);
      expect(cubit.state.doneIncidentId, 'inc_1');
    });
  });
}
