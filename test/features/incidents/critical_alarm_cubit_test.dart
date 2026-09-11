import 'package:critalarm/core/api/mock_api_client.dart';
import 'package:critalarm/core/api/mock_server.dart';
import 'package:critalarm/design/faces/face_state.dart';
import 'package:critalarm/design/tokens/colors.dart';
import 'package:critalarm/features/incidents/data/repositories/in_memory_incident_repository.dart';
import 'package:critalarm/features/incidents/domain/repositories/incident_repository.dart';
import 'package:critalarm/features/incidents/domain/usecases/acknowledge_incident_usecase.dart';
import 'package:critalarm/features/incidents/domain/usecases/close_incident_usecase.dart';
import 'package:critalarm/features/incidents/domain/usecases/get_incident_usecase.dart';
import 'package:critalarm/features/incidents/domain/usecases/get_incidents_usecase.dart';
import 'package:critalarm/features/incidents/presentation/cubits/critical_alarm_cubit.dart';
import 'package:critalarm/features/incidents/presentation/cubits/critical_alarm_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late MockServer server;
  late MockApiClient apiClient;
  late IncidentRepository repository;
  late GetIncidentUsecase getIncidentUsecase;
  late GetIncidentsUsecase getIncidentsUsecase;
  late AcknowledgeIncidentUsecase acknowledgeIncidentUsecase;
  late CloseIncidentUsecase closeIncidentUsecase;
  late CriticalAlarmCubit cubit;

  setUp(() {
    server = MockServer()..seedAlarmed();
    apiClient = MockApiClient(server);
    repository = InMemoryIncidentRepository(apiClient);
    getIncidentUsecase = GetIncidentUsecase(repository);
    getIncidentsUsecase = GetIncidentsUsecase(repository);
    acknowledgeIncidentUsecase = AcknowledgeIncidentUsecase(repository);
    closeIncidentUsecase = CloseIncidentUsecase(repository);

    cubit = CriticalAlarmCubit(
      getIncidentUsecase,
      getIncidentsUsecase,
      acknowledgeIncidentUsecase,
      closeIncidentUsecase,
    );
  });

  tearDown(() async {
    await cubit.close();
  });

  group('CriticalAlarmCubit', () {
    test('initial state has default critical alarm values', () {
      final state = cubit.state;
      expect(state.status, CriticalAlarmStatus.initial);
      expect(state.topic, 'prod-db');
      expect(state.word, 'CRITICAL');
      expect(state.severityMode, SeverityMode.crit);
      expect(state.faceState, FaceState.alarmed);
      expect(state.isLive, isTrue);
      expect(state.isAcknowledged, isFalse);
      expect(state.title, 'Primary database down');
    });

    test(
      'load with specific incidentId fetches and applies open incident',
      () async {
        await cubit.load(incidentId: 'inc_alarmed_proddb');

        final state = cubit.state;
        expect(state.status, CriticalAlarmStatus.ringing);
        expect(state.topic, 'prod-db');
        expect(state.title, 'Primary database down');
        expect(state.severityMode, SeverityMode.crit);
        expect(state.faceState, FaceState.alarmed);
        expect(state.isLive, isTrue);
        expect(state.isAcknowledged, isFalse);
        expect(state.incident, isNotNull);
        expect(state.incident!.id, 'inc_alarmed_proddb');
      },
    );

    test(
      'load without incidentId finds open critical incident from server',
      () async {
        await cubit.load();

        final state = cubit.state;
        expect(state.status, CriticalAlarmStatus.ringing);
        expect(state.topic, 'prod-db');
        expect(state.severityMode, SeverityMode.crit);
        expect(state.faceState, FaceState.alarmed);
        expect(state.isLive, isTrue);
      },
    );

    test(
      'load with acknowledged incident applies acknowledged state',
      () async {
        server.seedAcked();
        await cubit.load(incidentId: 'inc_acked_proddb');

        final state = cubit.state;
        expect(state.status, CriticalAlarmStatus.acknowledged);
        expect(state.severityMode, SeverityMode.ack);
        expect(state.faceState, FaceState.acked);
        expect(state.isLive, isFalse);
        expect(state.isAcknowledged, isTrue);
        expect(state.word, 'ACKNOWLEDGED');
        expect(state.subtext, contains('Acknowledged at'));
        expect(state.subtext, contains('by Z'));
      },
    );

    test(
      'acknowledge transitions incident on mock server and updates state',
      () async {
        await cubit.load(incidentId: 'inc_alarmed_proddb');
        expect(cubit.state.isAcknowledged, isFalse);

        await cubit.acknowledge();

        final state = cubit.state;
        expect(state.status, CriticalAlarmStatus.acknowledged);
        expect(state.isAcknowledged, isTrue);
        expect(state.isAcknowledging, isFalse);
        expect(state.severityMode, SeverityMode.ack);
        expect(state.faceState, FaceState.acked);
        expect(state.isLive, isFalse);
        expect(state.word, 'ACKNOWLEDGED');
        expect(state.subtext, contains('Acknowledged at'));
        expect(state.subtext, contains('by Z'));
        expect(state.feedbackMessage, contains('Acknowledged at'));

        // Verify on mock server
        final serverInc = server.getIncident('inc_alarmed_proddb');
        expect(serverInc.isAcked, isTrue);
      },
    );

    test('acknowledge does nothing if already acknowledged', () async {
      await cubit.load(incidentId: 'inc_alarmed_proddb');
      await cubit.acknowledge();

      final firstAckState = cubit.state;
      await cubit.acknowledge();
      expect(cubit.state, equals(firstAckState));
    });

    test('snooze sets isSnoozed and feedbackMessage', () {
      cubit.snooze();

      expect(cubit.state.isSnoozed, isTrue);
      expect(cubit.state.feedbackMessage, 'Alarm snoozed for 10 min');
    });

    test(
      'closeIncident closes acknowledged incident and sets calm face',
      () async {
        await cubit.load(incidentId: 'inc_alarmed_proddb');
        await cubit.acknowledge();

        await cubit.closeIncident();

        final state = cubit.state;
        expect(state.status, CriticalAlarmStatus.closed);
        expect(state.word, 'CLOSED');
        expect(state.faceState, FaceState.calm);
        expect(state.severityMode, SeverityMode.none);
        expect(state.isLive, isFalse);

        // Verify on mock server
        final serverInc = server.getIncident('inc_alarmed_proddb');
        expect(serverInc.isClosed, isTrue);
      },
    );
  });
}
