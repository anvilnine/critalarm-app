import 'package:critalarm/core/api/mock_api_client.dart';
import 'package:critalarm/core/api/mock_server.dart';
import 'package:critalarm/features/incidents/data/repositories/in_memory_incident_repository.dart';
import 'package:critalarm/features/incidents/domain/usecases/get_incidents_usecase.dart';
import 'package:critalarm/features/incidents/presentation/cubits/lock_screen_cubit.dart';
import 'package:critalarm/features/incidents/presentation/cubits/lock_screen_state.dart';
import 'package:flutter_test/flutter_test.dart';

/// The clock on the lock screen used to be read once in `load()` and never
/// again, so it showed the time the screen opened for as long as it stayed
/// open.
void main() {
  late GetIncidentsUsecase getIncidents;

  setUp(() {
    final server = MockServer()..seedAlarmed();
    getIncidents = GetIncidentsUsecase(
      InMemoryIncidentRepository(MockApiClient(server)),
    );
  });

  group('LockScreenCubit clock', () {
    test('waits for the minute boundary, not a fixed minute', () {
      expect(
        LockScreenCubit.untilNextMinute(DateTime(2026, 9, 17, 10, 30)),
        const Duration(minutes: 1),
      );
      expect(
        LockScreenCubit.untilNextMinute(DateTime(2026, 9, 17, 10, 30, 59)),
        const Duration(seconds: 1),
      );
      expect(
        LockScreenCubit.untilNextMinute(
          DateTime(2026, 9, 17, 10, 30, 30, 250),
        ),
        const Duration(seconds: 29, milliseconds: 750),
      );
    });

    test('the time on screen moves when the minute does', () async {
      var now = DateTime(2026, 9, 17, 10, 30, 59, 980);
      final cubit = LockScreenCubit(getIncidents, now: () => now);
      addTearDown(cubit.close);

      await cubit.load();
      expect(cubit.state.timeText, '10:30');

      now = DateTime(2026, 9, 17, 10, 31);
      await Future<void>.delayed(const Duration(milliseconds: 120));

      expect(cubit.state.timeText, '10:31');
      expect(cubit.state.status, LockScreenStatus.success);
    });

    test('the date moves too, so midnight is not stale', () async {
      var now = DateTime(2026, 9, 17, 23, 59, 59, 980);
      final cubit = LockScreenCubit(getIncidents, now: () => now);
      addTearDown(cubit.close);

      await cubit.load();
      expect(cubit.state.dateText, 'Thursday 17 September');

      now = DateTime(2026, 9, 18);
      await Future<void>.delayed(const Duration(milliseconds: 120));

      expect(cubit.state.dateText, 'Friday 18 September');
      expect(cubit.state.timeText, '00:00');
    });

    test('close stops the timer', () async {
      var now = DateTime(2026, 9, 17, 10, 30, 59, 980);
      final cubit = LockScreenCubit(getIncidents, now: () => now);

      await cubit.load();
      await cubit.close();

      // A timer that outlived close would emit on a closed cubit, which throws
      // out of the timer callback and fails this test.
      now = DateTime(2026, 9, 17, 10, 31);
      await Future<void>.delayed(const Duration(milliseconds: 120));

      expect(cubit.state.timeText, '10:30');
    });
  });
}
