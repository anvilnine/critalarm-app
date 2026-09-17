import 'package:critalarm/core/api/mock_api_client.dart';
import 'package:critalarm/core/api/mock_server.dart';
import 'package:critalarm/features/incidents/data/repositories/in_memory_incident_repository.dart';
import 'package:critalarm/features/incidents/domain/repositories/incident_repository.dart';
import 'package:critalarm/features/incidents/domain/usecases/acknowledge_incident_usecase.dart';
import 'package:critalarm/features/incidents/domain/usecases/close_incident_usecase.dart';
import 'package:critalarm/features/incidents/domain/usecases/get_incident_usecase.dart';
import 'package:critalarm/features/incidents/domain/usecases/get_incidents_usecase.dart';
import 'package:critalarm/features/incidents/presentation/cubits/critical_alarm_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../core/alarm/fake_alarm_host.dart';

void main() {
  late MockServer server;
  late IncidentRepository repository;
  late CriticalAlarmCubit cubit;
  late FakeAlarmHost alarm;

  setUp(() {
    server = MockServer()..seedAlarmed();
    repository = InMemoryIncidentRepository(MockApiClient(server));
    alarm = FakeAlarmHost();
    cubit = CriticalAlarmCubit(
      GetIncidentUsecase(repository),
      GetIncidentsUsecase(repository),
      AcknowledgeIncidentUsecase(repository),
      CloseIncidentUsecase(repository),
      null,
      alarm.host,
    );
  });

  tearDown(() => alarm.dispose());

  List<Object?> cancelled() =>
      alarm.argsTo('cancelAlarm').map((a) => a['incident_id']).toList();

  List<Object?> handedOver() => alarm
      .argsTo('cancelAlarm')
      .map((a) => a['hand_over_to_status_card'])
      .toList();

  group('the alarm screen stops the ring', () {
    test('acknowledge cancels the alarm for the incident on screen', () async {
      await cubit.load();
      final id = cubit.state.incident!.id;

      await cubit.acknowledge();

      expect(cancelled(), contains(id));
    });

    test('the alarm is cancelled before the acknowledge goes out', () async {
      await cubit.load();
      final id = cubit.state.incident!.id;
      alarm.calls.clear();

      await cubit.acknowledge();

      expect(alarm.calls.first.method, 'cancelAlarm');
      expect(alarm.argsTo('cancelAlarm').first['incident_id'], id);
    });

    test('acknowledge never asks for a stop with no id on it', () async {
      // One alarm service for the whole app. stopRinging names no incident,
      // so acking the incident on screen used to silence whatever else was
      // ringing, un-acknowledged, with its card still up.
      await cubit.load();
      alarm.calls.clear();

      await cubit.acknowledge();

      expect(alarm.callsTo('stopRinging'), isEmpty);
    });

    test('closing never asks for a stop with no id on it', () async {
      await cubit.load();
      alarm.calls.clear();

      await cubit.closeIncident();

      expect(alarm.callsTo('stopRinging'), isEmpty);
    });

    test('closing cancels the alarm too', () async {
      await cubit.load();
      final id = cubit.state.incident!.id;
      alarm.calls.clear();

      await cubit.closeIncident();

      expect(cancelled(), contains(id));
    });

    test('the card that takes over is handed the text on screen', () async {
      await cubit.load();
      final title = cubit.state.title;
      final body = cubit.state.body;
      alarm.calls.clear();

      await cubit.acknowledge();

      final args = alarm.argsTo('cancelAlarm').single;
      // Without these the acked card reads "Critical incident" for as long as
      // its own fetch keeps failing, while the screen behind it says what
      // actually happened.
      expect(title, isNotEmpty);
      expect(args['title'], title);
      expect(args['body'], body);
    });

    test('acknowledge hands the card over to the acked one', () async {
      await cubit.load();
      alarm.calls.clear();

      await cubit.acknowledge();

      expect(handedOver(), [true]);
    });

    test('closing leaves no card behind', () async {
      // The acked card is ongoing, so it cannot be swiped away, and its Done
      // button would POST a close the server answers with 409.
      await cubit.load();
      alarm.calls.clear();

      await cubit.closeIncident();

      expect(handedOver(), [false]);
    });

    test('the demo alarm leaves no card behind', () async {
      // inc_demo is not on the server. A card for it would sit there for good.
      await cubit.load(incidentId: 'inc_demo');
      alarm.calls.clear();

      await cubit.acknowledge();

      expect(cancelled(), ['inc_demo']);
      expect(handedOver(), [false]);
    });

    test('a cubit with no alarm host still acknowledges', () async {
      final bare = CriticalAlarmCubit(
        GetIncidentUsecase(repository),
        GetIncidentsUsecase(repository),
        AcknowledgeIncidentUsecase(repository),
        CloseIncidentUsecase(repository),
      );
      await bare.load();

      await expectLater(bare.acknowledge(), completes);
      expect(bare.state.isAcknowledged, isTrue);
    });
  });
}
