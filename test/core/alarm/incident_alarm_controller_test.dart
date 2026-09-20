import 'package:critalarm/core/alarm/alarm_trigger_path.dart';
import 'package:critalarm/core/alarm/incident_alarm_controller.dart';
import 'package:critalarm/core/alarm/quiet_hours.dart';
import 'package:critalarm/core/alarm/quiet_hours_store.dart';
import 'package:critalarm/core/api/api_exception.dart';
import 'package:critalarm/core/api/mock_api_client.dart';
import 'package:critalarm/core/api/mock_server.dart';
import 'package:critalarm/core/models/incident.dart';
import 'package:critalarm/core/push/incident_push.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_alarm_host.dart';

/// Answers `GET /v1/incidents/{id}` with one status, whatever is asked for.
/// [MockServer] only ever says 404 for an incident it does not hold, and 410
/// is the other answer a relay gives for one it has purged.
class GoneApiClient extends MockApiClient {
  GoneApiClient(super.server, this.statusCode);

  final int statusCode;

  @override
  Future<Incident> getIncident(String id) async =>
      throw ApiException(statusCode: statusCode, message: 'gone');
}

IncidentPush push(
  IncidentPushKind kind, {
  String id = 'inc_one',
  int? priority,
}) => IncidentPush(
  server: Uri.parse('https://alerts.example.com'),
  kind: kind,
  priority: priority ?? kind.impliedPriority,
  incidentId: kind == IncidentPushKind.p4 ? null : id,
  title: 'prod-db is down',
);

void main() {
  late FakeAlarmHost fake;
  late MockServer server;
  late MockApiClient api;

  IncidentAlarmController build({
    AlarmTriggerPath path = AlarmTriggerPath.appBackgroundPush,
  }) => IncidentAlarmController(host: fake.host, api: api, path: path);

  setUp(() {
    fake = FakeAlarmHost();
    server = MockServer();
    api = MockApiClient(server);
  });

  tearDown(() => fake.dispose());

  group('ringing', () {
    test('an open push schedules the alarm', () async {
      final controller = build();
      expect(await controller.onPush(push(IncidentPushKind.open)), isTrue);

      final args = fake.argsOnce('scheduleAlarm');
      expect(args['incident_id'], 'inc_one');
      expect(args['title'], 'prod-db is down');
      expect(args['server'], 'https://alerts.example.com');
    });

    test('a repeat rings again after the system auto-mute', () async {
      final controller = build();
      await controller.onPush(push(IncidentPushKind.open));
      await controller.onPush(push(IncidentPushKind.repeat));
      await controller.onPush(push(IncidentPushKind.repeat));

      expect(fake.callsTo('scheduleAlarm'), hasLength(3));
    });

    test('a reopen rings', () async {
      final controller = build();
      expect(await controller.onPush(push(IncidentPushKind.reopen)), isTrue);
    });

    test('a p4 forward never rings', () async {
      final controller = build();
      expect(await controller.onPush(push(IncidentPushKind.p4)), isFalse);
      expect(fake.callsTo('scheduleAlarm'), isEmpty);
    });

    test('on the extension path Dart does not schedule', () async {
      final controller = build(
        path: AlarmTriggerPath.notificationServiceExtension,
      );
      expect(await controller.onPush(push(IncidentPushKind.open)), isFalse);
      expect(fake.callsTo('scheduleAlarm'), isEmpty);
      // It still counts as ringing, which is what blocks a second card.
      expect(controller.alarmingIncidentIds, {'inc_one'});
    });
  });

  group('no second activity while the alarm is up', () {
    test('a ringing incident may not have our card started', () async {
      final controller = build();
      await controller.onPush(push(IncidentPushKind.open));

      expect(controller.mayStartActivity(incidentId: 'inc_one'), isFalse);
    });

    test('another incident is not blocked by the first one ringing', () async {
      final controller = build();
      await controller.onPush(push(IncidentPushKind.open));

      expect(controller.mayStartActivity(incidentId: 'inc_two'), isTrue);
    });

    test('after Stop the card may start', () async {
      final controller = build();
      await controller.onPush(push(IncidentPushKind.open));
      controller.onAlarmStopped('inc_one');

      expect(controller.mayStartActivity(incidentId: 'inc_one'), isTrue);
    });

    test('an alarm the native side set also blocks the card', () async {
      final controller = build();
      await controller.start();
      // What AppDelegate reports after a background push schedules an alarm
      // with no Dart involved.
      await fake.emitAlarmScheduled('inc_native');

      expect(controller.mayStartActivity(incidentId: 'inc_native'), isFalse);
      await controller.stop();
    });

    test('a card already showing is not started twice', () {
      final controller = build();
      expect(
        controller.mayStartActivity(
          incidentId: 'inc_one',
          showingIncidentIds: {'inc_one'},
        ),
        isFalse,
      );
    });
  });

  group('cancel on close', () {
    test('a finished incident cancels the alarm and ends the card', () async {
      final controller = build();
      await controller.onPush(push(IncidentPushKind.open));
      await controller.onIncidentFinished('inc_one');

      expect(fake.argsOnce('cancelAlarm')['incident_id'], 'inc_one');
      final end = fake.argsOnce('endActivity');
      expect(end['incident_id'], 'inc_one');
      expect(end['state'], 'closed');
      expect(controller.alarmingIncidentIds, isEmpty);
    });

    test('an expired incident ends the card as expired', () async {
      final controller = build();
      await controller.onIncidentFinished(
        'inc_one',
        state: IncidentState.expired,
      );

      expect(fake.argsOnce('endActivity')['state'], 'expired');
    });

    test('reconcile cancels cards the server has finished with', () async {
      server.seedState(
        incidents: [
          Incident(
            id: 'inc_done',
            topic: 'prod',
            state: IncidentStates.closed,
            openedAt: DateTime.utc(2026, 9, 13),
          ),
        ],
      );
      fake.answers['showingIncidentIds'] = <String>['inc_done'];

      await build().reconcile();

      expect(fake.callsTo('cancelAlarm'), hasLength(1));
      expect(fake.argsOnce('endActivity')['state'], 'closed');
    });

    test('reconcile leaves an open incident alone', () async {
      server.seedState(
        incidents: [
          Incident(
            id: 'inc_live',
            topic: 'prod',
            openedAt: DateTime.utc(2026, 9, 13),
          ),
        ],
      );
      fake.answers['showingIncidentIds'] = <String>['inc_live'];

      await build().reconcile();

      expect(fake.callsTo('cancelAlarm'), isEmpty);
      expect(fake.callsTo('endActivity'), isEmpty);
    });

    test('an unreachable server leaves the card up', () async {
      // A 503, not a 404. The server is there and cannot answer, so the card
      // stays: a stale card beats a missed incident.
      server.failIncidentFetch = true;
      fake.answers['showingIncidentIds'] = <String>['inc_unreachable'];

      await build().reconcile();

      expect(fake.callsTo('endActivity'), isEmpty);
      expect(fake.callsTo('cancelAlarm'), isEmpty);
    });

    test('an incident the server no longer has takes its card down', () async {
      // A relay purges incidents after its retention window, and then every
      // launch asked about the same id and got a 404 back. The id never left
      // the list, so the list only grew.
      fake.answers['showingIncidentIds'] = <String>['inc_purged'];

      await build().reconcile();

      expect(fake.argsOnce('cancelAlarm')['incident_id'], 'inc_purged');
      expect(fake.argsOnce('endActivity')['state'], 'expired');
    });

    test('a 410 takes the card down the same way a 404 does', () async {
      // A relay answers 410 for an incident it purged on purpose, and 404 for
      // one it has no record of. Both mean the card has nothing behind it.
      fake.answers['showingIncidentIds'] = <String>['inc_gone'];

      await IncidentAlarmController(
        host: fake.host,
        api: GoneApiClient(server, 410),
        path: AlarmTriggerPath.appBackgroundPush,
      ).reconcile();

      expect(fake.argsOnce('cancelAlarm')['incident_id'], 'inc_gone');
      expect(fake.argsOnce('endActivity')['state'], 'expired');
    });

    test('one launch checks at most the bound', () async {
      fake.answers['showingIncidentIds'] = List.generate(
        IncidentAlarmController.reconcileLimit + 5,
        (i) => 'inc_stale_$i',
      );

      await build().reconcile();

      expect(
        fake.callsTo('cancelAlarm'),
        hasLength(IncidentAlarmController.reconcileLimit),
      );
    });
  });

  group('quiet hours', () {
    /// 22:00 to 07:00, switched on, with critical ringing through. The
    /// saved defaults are off, so this window is spelled out.
    const night = QuietHours(
      isEnabled: true,
      startMinutes: QuietHours.defaultStartMinutes,
      endMinutes: QuietHours.defaultEndMinutes,
      criticalRingsThrough: true,
    );

    /// A page that does not open an incident on a critical topic. The relay
    /// sends priority 5 for the pager case, so anything under that is the
    /// non-critical side of the switch.
    IncidentPush quietPage() =>
        push(IncidentPushKind.open, priority: 4);

    IncidentPush criticalPage() => push(
      IncidentPushKind.open,
      priority: QuietHours.criticalPriority,
    );

    Future<QuietHoursStore> storeWith(QuietHours window) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = QuietHoursStore(prefs);
      await store.write(window);
      return store;
    }

    Future<IncidentAlarmController> controllerAt(
      DateTime now, {
      required QuietHours window,
    }) async => IncidentAlarmController(
      host: fake.host,
      api: api,
      path: AlarmTriggerPath.appBackgroundPush,
      quietHours: await storeWith(window),
      now: () => now,
    );

    test('a non-critical page inside the window does not ring', () async {
      final controller = await controllerAt(
        DateTime(2026, 9, 17, 23, 30),
        window: night.copyWith(criticalRingsThrough: false),
      );

      expect(await controller.onPush(quietPage()), isFalse);
      expect(fake.callsTo('scheduleAlarm'), isEmpty);
      // Nothing is ringing, so our card is free to be the acknowledge
      // surface.
      expect(controller.alarmingIncidentIds, isEmpty);
      expect(controller.mayStartActivity(incidentId: 'inc_one'), isTrue);
    });

    test('a non-critical page outside the window rings', () async {
      final controller = await controllerAt(
        DateTime(2026, 9, 17, 9),
        window: night.copyWith(criticalRingsThrough: false),
      );

      expect(await controller.onPush(quietPage()), isTrue);
      expect(fake.argsOnce('scheduleAlarm')['incident_id'], 'inc_one');
    });

    test('with quiet hours off a non-critical page rings', () async {
      final controller = await controllerAt(
        DateTime(2026, 9, 17, 23, 30),
        window: night.copyWith(
          isEnabled: false,
          criticalRingsThrough: false,
        ),
      );

      expect(await controller.onPush(quietPage()), isTrue);
    });

    test('a critical page rings through with the switch on', () async {
      final controller = await controllerAt(
        DateTime(2026, 9, 17, 23, 30),
        window: night,
      );

      expect(await controller.onPush(criticalPage()), isTrue);
      expect(fake.callsTo('scheduleAlarm'), hasLength(1));
    });

    test('a critical page is held with the switch off', () async {
      final controller = await controllerAt(
        DateTime(2026, 9, 17, 23, 30),
        window: night.copyWith(criticalRingsThrough: false),
      );

      expect(await controller.onPush(criticalPage()), isFalse);
      expect(fake.callsTo('scheduleAlarm'), isEmpty);
    });

    test('a window that wraps past midnight holds both sides', () async {
      final window = night.copyWith(criticalRingsThrough: false);

      final before = await controllerAt(
        DateTime(2026, 9, 17, 23, 30),
        window: window,
      );
      expect(await before.onPush(quietPage()), isFalse);

      final after = await controllerAt(
        DateTime(2026, 9, 18, 2),
        window: window,
      );
      expect(await after.onPush(quietPage()), isFalse);

      expect(fake.callsTo('scheduleAlarm'), isEmpty);
    });
  });
}
