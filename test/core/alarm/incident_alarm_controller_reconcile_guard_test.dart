import 'package:critalarm/core/alarm/alarm_host.dart';
import 'package:critalarm/core/alarm/alarm_trigger_path.dart';
import 'package:critalarm/core/alarm/incident_alarm_controller.dart';
import 'package:critalarm/core/api/api_exception.dart';
import 'package:critalarm/core/api/mock_api_client.dart';
import 'package:critalarm/core/api/mock_server.dart';
import 'package:critalarm/core/models/incident.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_alarm_host.dart';

/// Notes how many native calls had gone out when each question was asked,
/// so a test can see the ring generation was read first.
class _OrderedApiClient extends MockApiClient {
  _OrderedApiClient(super.server, this.fake);

  final FakeAlarmHost fake;
  final List<int> nativeCallsBeforeAsk = [];

  @override
  Future<Incident> getIncident(String id) {
    nativeCallsBeforeAsk.add(fake.calls.length);
    return super.getIncident(id);
  }
}

class _GoneApiClient extends MockApiClient {
  _GoneApiClient(super.server, this.statusCode);

  final int statusCode;

  @override
  Future<Incident> getIncident(String id) async =>
      throw ApiException(statusCode: statusCode, message: 'gone');
}

/// Launch reconcile on a phone that keeps ring generations. A reopen can arm
/// a ring while the question is out, so a finished answer may only end the
/// card through the guarded native step, and a 404 never stops a live ring.
void main() {
  late FakeAlarmHost fake;
  late MockServer server;

  setUp(() {
    fake = FakeAlarmHost();
    server = MockServer();
    fake.answers['ringGeneration'] = 3;
  });

  tearDown(() => fake.dispose());

  void seedClosed(String id) => server.seedState(
    incidents: [
      Incident(
        id: id,
        topic: 'prod',
        state: IncidentStates.closed,
        openedAt: DateTime.utc(2026, 9, 13),
      ),
    ],
  );

  IncidentAlarmController build(MockApiClient api, {List<Incident>? applied}) =>
      IncidentAlarmController(
        host: fake.host,
        api: api,
        path: AlarmTriggerPath.appBackgroundPush,
        wait: (_) async {},
        applyIncident: applied?.add,
      );

  test('a finished incident goes through the guarded native step', () async {
    seedClosed('inc_done');
    fake.answers['showingIncidentIds'] = <String>['inc_done'];
    fake.answers['applyRemoteState'] = 'nothing';
    final api = _OrderedApiClient(server, fake);
    final applied = <Incident>[];

    await build(api, applied: applied).reconcile();

    expect(fake.callsTo('cancelAlarm'), isEmpty);
    expect(fake.callsTo('endActivity'), isEmpty);
    final args = fake.argsOnce('applyRemoteState');
    expect(args['incident_id'], 'inc_done');
    expect(args['state'], 'closed');
    expect(args['generation'], 3);
    expect(args['apply_when_nothing'], isTrue);
    expect(args.containsKey('keep_live'), isFalse);
    expect(applied.map((i) => i.id), ['inc_done']);
  });

  test('the generation is read before the question goes out', () async {
    seedClosed('inc_done');
    fake.answers['showingIncidentIds'] = <String>['inc_done'];
    fake.answers['applyRemoteState'] = 'stopped';
    final api = _OrderedApiClient(server, fake);

    await build(api).reconcile();

    final readAt = fake.calls.indexWhere((c) => c.method == 'ringGeneration');
    expect(readAt, isNonNegative);
    expect(api.nativeCallsBeforeAsk.single, greaterThan(readAt));
  });

  test('a refused answer leaves the ring and the card alone', () async {
    seedClosed('inc_done');
    fake.answers['showingIncidentIds'] = <String>['inc_done'];
    fake.answers['applyRemoteState'] = 'refused';
    final applied = <Incident>[];

    await build(MockApiClient(server), applied: applied).reconcile();

    expect(fake.callsTo('cancelAlarm'), isEmpty);
    expect(fake.callsTo('endActivity'), isEmpty);
    expect(applied, isEmpty);
  });

  for (final status in [404, 410]) {
    test('a $status never stops a live ring', () async {
      fake.answers['showingIncidentIds'] = <String>['inc_gone'];
      fake.answers['applyRemoteState'] = 'refused';

      await build(_GoneApiClient(server, status)).reconcile();

      expect(fake.callsTo('cancelAlarm'), isEmpty);
      expect(fake.callsTo('endActivity'), isEmpty);
      final args = fake.argsOnce('applyRemoteState');
      expect(args['state'], 'expired');
      expect(args['generation'], 3);
      expect(args['keep_live'], isTrue);
      expect(args['apply_when_nothing'], isTrue);
    });
  }

  test('a generation that cannot be read leaves the card up', () async {
    seedClosed('inc_done');
    fake.answers['showingIncidentIds'] = <String>['inc_done'];
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel(AlarmHost.channelName), (
          call,
        ) async {
          calls.add(call);
          if (call.method == 'ringGeneration') {
            throw PlatformException(code: 'broken');
          }
          return fake.answers[call.method];
        });

    await build(MockApiClient(server)).reconcile();

    final methods = calls.map((c) => c.method);
    expect(methods, isNot(contains('cancelAlarm')));
    expect(methods, isNot(contains('endActivity')));
    expect(methods, isNot(contains('applyRemoteState')));
  });
}
