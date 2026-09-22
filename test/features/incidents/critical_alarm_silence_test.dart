import 'package:critalarm/core/api/mock_api_client.dart';
import 'package:critalarm/core/api/mock_server.dart';
import 'package:critalarm/features/incidents/data/repositories/in_memory_incident_repository.dart';
import 'package:critalarm/features/incidents/domain/repositories/incident_repository.dart';
import 'package:critalarm/features/incidents/domain/usecases/acknowledge_incident_usecase.dart';
import 'package:critalarm/features/incidents/domain/usecases/close_incident_usecase.dart';
import 'package:critalarm/features/incidents/domain/usecases/get_incident_usecase.dart';
import 'package:critalarm/features/incidents/domain/usecases/get_incidents_usecase.dart';
import 'package:critalarm/features/incidents/presentation/cubits/critical_alarm_cubit.dart';
import 'package:critalarm/features/incidents/presentation/cubits/critical_alarm_state.dart';
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
    alarm.answers['rearmAlarm'] = 30;
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

  group('Silence on the ringing screen', () {
    test('asks the phone to set its own next ring for the same id', () async {
      await cubit.load();
      final id = cubit.state.incident!.id;

      await cubit.silence();

      expect(alarm.argsOnce('rearmAlarm')['incident_id'], id);
    });

    test('never acknowledges: no ack, no mark, no cancel', () async {
      await cubit.load();
      alarm.calls.clear();

      await cubit.silence();

      expect(alarm.callsTo('markAcked'), isEmpty);
      expect(alarm.callsTo('cancelAlarm'), isEmpty);
      expect(cubit.state.isAcknowledged, isFalse);
      expect(cubit.state.status, CriticalAlarmStatus.ringing);
    });

    test('says when the next ring lands', () async {
      await cubit.load();

      await cubit.silence();

      expect(cubit.state.feedbackMessage, contains('30'));
    });

    test('says nothing when the phone refused to re-arm', () async {
      alarm.answers['rearmAlarm'] = null;
      await cubit.load();

      await cubit.silence();

      expect(cubit.state.feedbackMessage, isNull);
    });
  });

  group("I'm up on the ringing screen", () {
    test('marks the incident acked here and stops the ring', () async {
      await cubit.load();
      final id = cubit.state.incident!.id;

      await cubit.acknowledge();

      expect(alarm.argsOnce('markAcked')['incident_id'], id);
      expect(alarm.callsTo('rearmAlarm'), isEmpty);
      expect(cubit.state.isAcknowledged, isTrue);
    });
  });
}
