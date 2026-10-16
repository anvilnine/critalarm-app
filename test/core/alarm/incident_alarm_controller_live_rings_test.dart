import 'dart:io';

import 'package:critalarm/core/alarm/incident_alarm_controller.dart';
import 'package:critalarm/core/api/mock_api_client.dart';
import 'package:critalarm/core/api/mock_server.dart';
import 'package:critalarm/core/models/incident.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_alarm_host.dart';

/// Answers `GET /v1/incidents/{id}` from [states], and fails for an id with
/// no entry.
class _StatesApiClient extends MockApiClient {
  _StatesApiClient(super.server, this.states);

  final Map<String, String> states;
  final asked = <String>[];

  @override
  Future<Incident> getIncident(String id) async {
    asked.add(id);
    final state = states[id];
    if (state == null) throw const SocketException('no route');
    return Incident(id: id, topic: 'prod-db', state: state);
  }
}

void main() {
  late FakeAlarmHost fake;
  late _StatesApiClient api;
  late List<Incident> applied;

  IncidentAlarmController build() => IncidentAlarmController(
    host: fake.host,
    api: api,
    applyIncident: applied.add,
    wait: (_) async {},
  );

  setUp(() {
    fake = FakeAlarmHost();
    applied = [];
  });

  tearDown(() => fake.dispose());

  List<Map<String, Object?>> told() => fake.argsTo('applyRemoteState');

  test('a ring another device acknowledged is stopped', () async {
    fake.answers['liveIncidentIds'] = <String>['inc_1'];
    fake.answers['applyRemoteState'] = true;
    api = _StatesApiClient(MockServer(), {'inc_1': 'acked'});

    await build().stopRingsHandledElsewhere();

    expect(told().single, {'incident_id': 'inc_1', 'state': 'acked'});
    expect(applied.single.isAcked, isTrue);
  });

  test('closed and expired stop it too', () async {
    fake.answers['liveIncidentIds'] = <String>['inc_1', 'inc_2'];
    api = _StatesApiClient(MockServer(), {
      'inc_1': 'closed',
      'inc_2': 'expired',
    });

    await build().stopRingsHandledElsewhere();

    expect(told().map((a) => a['state']), ['closed', 'expired']);
  });

  test('an open incident keeps ringing', () async {
    fake.answers['liveIncidentIds'] = <String>['inc_1'];
    api = _StatesApiClient(MockServer(), {'inc_1': 'open'});

    await build().stopRingsHandledElsewhere();

    expect(told(), isEmpty);
    expect(applied, isEmpty);
  });

  test('a check that fails never stops a ring', () async {
    fake.answers['liveIncidentIds'] = <String>['inc_1'];
    api = _StatesApiClient(MockServer(), {});

    await build().stopRingsHandledElsewhere();

    expect(api.asked, ['inc_1']);
    expect(told(), isEmpty);
  });

  test('the incident on the alarm screen is left to that screen', () async {
    fake.answers['liveIncidentIds'] = <String>['inc_1', 'inc_2'];
    api = _StatesApiClient(MockServer(), {
      'inc_1': 'acked',
      'inc_2': 'acked',
    });

    await build().stopRingsHandledElsewhere(skip: (id) => id == 'inc_1');

    expect(api.asked, ['inc_2']);
    expect(told().single['incident_id'], 'inc_2');
  });

  test('nothing ringing asks the server nothing', () async {
    api = _StatesApiClient(MockServer(), {'inc_1': 'acked'});

    await build().stopRingsHandledElsewhere();

    expect(api.asked, isEmpty);
    expect(told(), isEmpty);
  });

  test('at most a handful of rings are checked in one run', () async {
    final ids = [for (var i = 0; i < 9; i++) 'inc_$i'];
    fake.answers['liveIncidentIds'] = ids;
    api = _StatesApiClient(MockServer(), {for (final id in ids) id: 'open'});

    await build().stopRingsHandledElsewhere();

    expect(api.asked, hasLength(IncidentAlarmController.liveCheckLimit));
  });
}
