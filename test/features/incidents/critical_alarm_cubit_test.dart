import 'package:critalarm/app/state/incidents_cubit.dart';
import 'package:critalarm/core/api/mock_api_client.dart';
import 'package:critalarm/core/api/mock_server.dart';
import 'package:critalarm/core/result/result.dart';
import 'package:critalarm/design/faces/face_state.dart';
import 'package:critalarm/design/tokens/colors.dart';
import 'package:critalarm/features/incidents/data/repositories/in_memory_incident_repository.dart';
import 'package:critalarm/features/incidents/domain/entities/incident.dart';
import 'package:critalarm/features/incidents/domain/repositories/incident_repository.dart';
import 'package:critalarm/features/incidents/domain/usecases/acknowledge_incident_usecase.dart';
import 'package:critalarm/features/incidents/domain/usecases/close_incident_usecase.dart';
import 'package:critalarm/features/incidents/domain/usecases/get_incident_usecase.dart';
import 'package:critalarm/features/incidents/domain/usecases/get_incidents_usecase.dart';
import 'package:critalarm/features/incidents/presentation/cubits/critical_alarm_cubit.dart';
import 'package:critalarm/features/incidents/presentation/cubits/critical_alarm_state.dart';
import 'package:critalarm/features/onboarding/domain/repositories/onboarding_progress_repository.dart';
import 'package:critalarm/features/onboarding/domain/usecases/get_onboarding_completed_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockOnboardingProgressRepository extends Mock
    implements OnboardingProgressRepository {}

Incident _openIncident({
  required String id,
  required String topic,
  required DateTime openedAt,
}) => Incident(id: id, topic: topic, openedAt: openedAt);

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

  group('the demo alarm and onboarding', () {
    CriticalAlarmCubit demoCubit({required bool completed}) {
      final repo = _MockOnboardingProgressRepository();
      when(repo.isCompleted).thenAnswer((_) async => completed.toSuccess());
      return CriticalAlarmCubit(
        getIncidentUsecase,
        getIncidentsUsecase,
        acknowledgeIncidentUsecase,
        closeIncidentUsecase,
        null,
        null,
        const Duration(seconds: 1),
        null,
        GetOnboardingCompletedUsecase(repo),
      );
    }

    test('a test alarm during onboarding leaves the flag off', () async {
      final demo = demoCubit(completed: false);
      addTearDown(demo.close);

      await demo.load(incidentId: 'inc_demo');

      expect(demo.state.isOnboardingDone, isFalse);
    });

    test('a test alarm after onboarding sets the flag', () async {
      final demo = demoCubit(completed: true);
      addTearDown(demo.close);

      await demo.load(incidentId: 'inc_demo');

      expect(demo.state.isOnboardingDone, isTrue);
      expect(demo.state.incident?.id, 'inc_demo');
    });

    test('the flag survives acknowledging the demo alarm', () async {
      final demo = demoCubit(completed: true);
      addTearDown(demo.close);

      await demo.load(incidentId: 'inc_demo');
      await demo.acknowledge();

      expect(demo.state.status, CriticalAlarmStatus.acknowledged);
      expect(demo.state.isOnboardingDone, isTrue);
    });

    test('a real incident never carries the flag', () async {
      final demo = demoCubit(completed: true);
      addTearDown(demo.close);

      await demo.load();

      expect(demo.state.isOnboardingDone, isFalse);
    });
  });

  group('CriticalAlarmCubit', () {
    test('initial state is empty and calm', () {
      final state = cubit.state;
      expect(state.status, CriticalAlarmStatus.initial);
      expect(state.topic, isEmpty);
      expect(state.word, isEmpty);
      expect(state.severityMode, SeverityMode.none);
      expect(state.faceState, FaceState.calm);
      expect(state.isLive, isFalse);
      expect(state.isAcknowledged, isFalse);
      expect(state.title, isEmpty);
      expect(state.body, isEmpty);
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

    test(
      'closeIncident applies the closed incident to the shared list',
      () async {
        final incidents = IncidentsCubit(getIncidentsUsecase);
        addTearDown(incidents.close);
        await incidents.ensureLoaded();

        final sharedCubit = CriticalAlarmCubit(
          getIncidentUsecase,
          getIncidentsUsecase,
          acknowledgeIncidentUsecase,
          closeIncidentUsecase,
          incidents,
        );
        addTearDown(sharedCubit.close);

        await sharedCubit.load(incidentId: 'inc_alarmed_proddb');
        await sharedCubit.acknowledge();
        await sharedCubit.closeIncident();

        final shared = incidents.state.incidents.firstWhere(
          (i) => i.id == 'inc_alarmed_proddb',
        );
        expect(
          shared.isClosed,
          isTrue,
          reason: 'History and the topic screen read this list',
        );
      },
    );

    test(
      'a failed close keeps status acked and surfaces the error message',
      () async {
        await cubit.load(incidentId: 'inc_alarmed_proddb');
        await cubit.acknowledge();

        // Close it out of band, so the cubit's own closeIncident() call
        // below hits the server's "already closed" guard and comes back
        // with a 409 instead of a fresh closed incident.
        server.closeIncident('inc_alarmed_proddb');

        await cubit.closeIncident();

        final state = cubit.state;
        expect(state.status, CriticalAlarmStatus.acknowledged);
        expect(state.errorMessage, isNotNull);
      },
    );

    test(
      'shows the newest open incident by openedAt, not list order',
      () async {
        final incidents = IncidentsCubit(getIncidentsUsecase);
        addTearDown(incidents.close);
        final shared = CriticalAlarmCubit(
          getIncidentUsecase,
          getIncidentsUsecase,
          acknowledgeIncidentUsecase,
          closeIncidentUsecase,
          incidents,
        );
        addTearDown(shared.close);

        final now = DateTime.now();
        final older = _openIncident(
          id: 'inc_older',
          topic: 'nas-backup',
          openedAt: now.subtract(const Duration(minutes: 5)),
        );
        final newer = _openIncident(
          id: 'inc_newer',
          topic: 'prod-db',
          openedAt: now,
        );

        // The older one arrives first, so the shared list holds it first.
        incidents.applyIncidents([newer, older]);
        await Future<void>.delayed(Duration.zero);

        expect(shared.state.incident?.id, 'inc_newer');
        expect(
          shared.state.openIncidents.map((i) => i.id).toList(),
          ['inc_newer', 'inc_older'],
        );
      },
    );

    test(
      'a second open incident on the shared stream swaps shown and lists two',
      () async {
        final incidents = IncidentsCubit(getIncidentsUsecase);
        addTearDown(incidents.close);
        final shared = CriticalAlarmCubit(
          getIncidentUsecase,
          getIncidentsUsecase,
          acknowledgeIncidentUsecase,
          closeIncidentUsecase,
          incidents,
        );
        addTearDown(shared.close);

        final now = DateTime.now();
        incidents.applyIncidents([
          _openIncident(
            id: 'inc_first',
            topic: 'prod-db',
            openedAt: now.subtract(const Duration(seconds: 10)),
          ),
        ]);
        await Future<void>.delayed(Duration.zero);
        expect(shared.state.incident?.id, 'inc_first');

        incidents.applyIncidents([
          _openIncident(
            id: 'inc_second',
            topic: 'nas-backup',
            openedAt: now,
          ),
        ]);
        await Future<void>.delayed(Duration.zero);

        expect(shared.state.incident?.id, 'inc_second');
        expect(shared.state.openIncidents, hasLength(2));
      },
    );

    test(
      'acknowledging with another open incident swaps to it, not acknowledged',
      () async {
        final now = DateTime.now();
        server
          ..reset()
          ..seedState(
            incidents: [
              _openIncident(
                id: 'inc_older',
                topic: 'nas-backup',
                openedAt: now.subtract(const Duration(minutes: 5)),
              ),
              _openIncident(
                id: 'inc_newer',
                topic: 'prod-db',
                openedAt: now,
              ),
            ],
          );

        await cubit.load();
        expect(cubit.state.incident?.id, 'inc_newer');

        await cubit.acknowledge();

        expect(cubit.state.incident?.id, 'inc_older');
        expect(cubit.state.status, CriticalAlarmStatus.ringing);
        expect(cubit.state.isAcknowledged, isFalse);
        expect(cubit.state.openIncidents.map((i) => i.id), ['inc_older']);
      },
    );

    test(
      'acknowledging the last open incident enters the acknowledged state',
      () async {
        await cubit.load(incidentId: 'inc_alarmed_proddb');

        await cubit.acknowledge();

        expect(cubit.state.status, CriticalAlarmStatus.acknowledged);
        expect(cubit.state.isAcknowledged, isTrue);
        expect(cubit.state.openIncidents, isEmpty);
      },
    );

    test('select swaps the shown incident', () async {
      final now = DateTime.now();
      server
        ..reset()
        ..seedState(
          incidents: [
            _openIncident(
              id: 'inc_older',
              topic: 'nas-backup',
              openedAt: now.subtract(const Duration(minutes: 5)),
            ),
            _openIncident(
              id: 'inc_newer',
              topic: 'prod-db',
              openedAt: now,
            ),
          ],
        );

      await cubit.load();
      expect(cubit.state.incident?.id, 'inc_newer');

      cubit.select('inc_older');

      expect(cubit.state.incident?.id, 'inc_older');
      expect(cubit.state.status, CriticalAlarmStatus.ringing);
      expect(
        cubit.state.openIncidents.map((i) => i.id).toList(),
        ['inc_newer', 'inc_older'],
      );
    });
  });
}
