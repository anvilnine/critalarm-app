import 'package:critalarm/core/api/mock_api_client.dart';
import 'package:critalarm/core/api/mock_server.dart';
import 'package:critalarm/features/incidents/data/repositories/in_memory_incident_repository.dart';
import 'package:critalarm/features/incidents/domain/repositories/incident_repository.dart';
import 'package:critalarm/features/incidents/domain/usecases/get_incidents_usecase.dart';
import 'package:critalarm/features/incidents/presentation/cubits/lock_screen_cubit.dart';
import 'package:critalarm/features/incidents/presentation/cubits/lock_screen_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late MockServer server;
  late MockApiClient apiClient;
  late IncidentRepository repository;
  late GetIncidentsUsecase getIncidentsUsecase;
  late LockScreenCubit cubit;

  setUp(() {
    server = MockServer()..seedAlarmed();
    apiClient = MockApiClient(server);
    repository = InMemoryIncidentRepository(apiClient);
    getIncidentsUsecase = GetIncidentsUsecase(repository);
    cubit = LockScreenCubit(getIncidentsUsecase);
  });

  tearDown(() async {
    await cubit.close();
  });

  group('LockScreenCubit', () {
    test('initial state has default date, time, and mockup notifications', () {
      final state = cubit.state;
      expect(state.status, LockScreenStatus.initial);
      expect(state.dateText, 'Thursday 10 September');
      expect(state.timeText, '03:12');
      expect(state.notifications.length, 2);

      final critNotif = state.notifications.first;
      expect(critNotif.isCrit, isTrue);
      expect(critNotif.topic, 'prod-db');
      expect(critNotif.title, 'Primary database down');
      expect(
        critNotif.ringingPillText,
        'Ringing. Tap to acknowledge.',
      );
      expect(critNotif.timeText, 'now');

      final quietNotif = state.notifications[1];
      expect(quietNotif.isQuiet, isTrue);
      expect(quietNotif.topic, 'nas-backup');
      expect(quietNotif.title, 'Backup finished');
      expect(quietNotif.body, '412 GB copied in 43 min.');
      expect(quietNotif.timeText, '02:04');
    });

    test(
      'load populates notifications from open incidents on server',
      () async {
        await cubit.load();

        final state = cubit.state;
        expect(state.status, LockScreenStatus.success);
        expect(state.notifications.isNotEmpty, isTrue);

        final critItem = state.notifications.firstWhere((n) => n.isCrit);
        expect(critItem.topic, 'prod-db');
        expect(critItem.title, 'Primary database down');
        expect(
          critItem.ringingPillText,
          'Ringing. Tap to acknowledge.',
        );
      },
    );

    test(
      'load with empty incidents keeps default mockup notifications',
      () async {
        server.reset();
        await cubit.load();

        final state = cubit.state;
        expect(state.status, LockScreenStatus.success);
        expect(state.notifications.length, 2);
        expect(state.notifications.first.topic, 'prod-db');
        expect(state.notifications.last.topic, 'nas-backup');
      },
    );
  });
}
