import 'package:critalarm/features/incidents/domain/entities/incident.dart';
import 'package:critalarm/features/incidents/domain/usecases/acknowledge_incident_usecase.dart';
import 'package:critalarm/features/incidents/domain/usecases/close_incident_usecase.dart';
import 'package:critalarm/features/incidents/domain/usecases/get_incident_usecase.dart';
import 'package:critalarm/features/incidents/domain/usecases/get_incidents_usecase.dart';
import 'package:critalarm/features/incidents/presentation/cubits/critical_alarm_cubit.dart';
import 'package:critalarm/features/incidents/presentation/cubits/critical_alarm_state.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../core/alarm/fake_alarm_host.dart';
import '../../helpers/scripted_incident_repository.dart';

void main() {
  final opened = DateTime(2026, 9, 17, 10);

  late ScriptedIncidentRepository repository;
  late FakeAlarmHost alarm;
  late DateTime clock;
  late CriticalAlarmCubit cubit;

  setUp(() {
    repository = ScriptedIncidentRepository([
      Incident(id: 'inc_1', topic: 'prod-db', openedAt: opened),
    ]);
    alarm = FakeAlarmHost();
    clock = opened.add(const Duration(seconds: 30));
    cubit = CriticalAlarmCubit(
      GetIncidentUsecase(repository),
      GetIncidentsUsecase(repository),
      AcknowledgeIncidentUsecase(repository),
      CloseIncidentUsecase(repository),
      null,
      alarm.host,
      const Duration(milliseconds: 5),
      () => clock,
    );
  });

  tearDown(() async {
    await cubit.close();
    alarm.dispose();
  });

  group('a magic tap', () {
    test(
      'acknowledges while the alarm rings and the screen is in front',
      () async {
        await cubit.load(incidentId: 'inc_1');
        expect(cubit.state.status, CriticalAlarmStatus.ringing);

        final acted = await cubit.acknowledgeFromMagicTap(
          isRingingScreenInFront: true,
        );

        expect(acted, isTrue);
        expect(cubit.state.isAcknowledged, isTrue);
        expect(repository.sent, ['inc_1']);
        expect(alarm.argsTo('cancelAlarm').single['incident_id'], 'inc_1');
      },
    );

    test('takes the same path as the button', () async {
      await cubit.load(incidentId: 'inc_1');
      await cubit.acknowledgeFromMagicTap(isRingingScreenInFront: true);
      final fromTap = alarm.calls.map((c) => c.method).toList();
      final tapState = cubit.state;

      final other = FakeAlarmHost();
      final otherRepository = ScriptedIncidentRepository([
        Incident(id: 'inc_1', topic: 'prod-db', openedAt: opened),
      ]);
      final buttonCubit = CriticalAlarmCubit(
        GetIncidentUsecase(otherRepository),
        GetIncidentsUsecase(otherRepository),
        AcknowledgeIncidentUsecase(otherRepository),
        CloseIncidentUsecase(otherRepository),
        null,
        other.host,
        const Duration(milliseconds: 5),
        () => clock,
      );
      addTearDown(buttonCubit.close);
      await buttonCubit.load(incidentId: 'inc_1');
      await buttonCubit.acknowledge();

      expect(fromTap, other.calls.map((c) => c.method).toList());
      expect(tapState.status, buttonCubit.state.status);
      expect(otherRepository.sent, repository.sent);
    });

    test('does nothing while another screen or a sheet is in front', () async {
      await cubit.load(incidentId: 'inc_1');
      alarm.calls.clear();

      final acted = await cubit.acknowledgeFromMagicTap(
        isRingingScreenInFront: false,
      );

      expect(acted, isFalse);
      expect(cubit.state.status, CriticalAlarmStatus.ringing);
      expect(repository.sent, isEmpty);
      expect(alarm.callsTo('cancelAlarm'), isEmpty);
    });

    test('does nothing before an alarm is loaded', () async {
      final acted = await cubit.acknowledgeFromMagicTap(
        isRingingScreenInFront: true,
      );

      expect(acted, isFalse);
      expect(cubit.state.status, CriticalAlarmStatus.initial);
      expect(repository.sent, isEmpty);
    });

    test('does nothing once the alarm is acknowledged', () async {
      await cubit.load(incidentId: 'inc_1');
      await cubit.acknowledge();
      alarm.calls.clear();

      final acted = await cubit.acknowledgeFromMagicTap(
        isRingingScreenInFront: true,
      );

      expect(acted, isFalse);
      expect(repository.sent, ['inc_1']);
      expect(alarm.callsTo('cancelAlarm'), isEmpty);
    });

    test('a second tap right behind the first acknowledges once', () async {
      await cubit.load(incidentId: 'inc_1');

      // Neither is awaited before the other starts, so the second arrives
      // while the first acknowledge is still on its way.
      final first = cubit.acknowledgeFromMagicTap(isRingingScreenInFront: true);
      final second = cubit.acknowledgeFromMagicTap(
        isRingingScreenInFront: true,
      );

      expect(await first, isTrue);
      expect(await second, isFalse);
      expect(repository.sent, ['inc_1']);
      expect(alarm.callsTo('cancelAlarm'), hasLength(1));
    });

    test('does nothing when there is no alarm to show', () async {
      final empty = ScriptedIncidentRepository([]);
      final emptyCubit = CriticalAlarmCubit(
        GetIncidentUsecase(empty),
        GetIncidentsUsecase(empty),
        AcknowledgeIncidentUsecase(empty),
        CloseIncidentUsecase(empty),
      );
      addTearDown(emptyCubit.close);
      await emptyCubit.load();

      expect(
        await emptyCubit.acknowledgeFromMagicTap(isRingingScreenInFront: true),
        isFalse,
      );
      expect(empty.sent, isEmpty);
    });
  });

  group('the spoken ring time on the ringing state', () {
    test('is set when the alarm loads', () async {
      await cubit.load(incidentId: 'inc_1');

      expect(cubit.state.subtext, contains('30 s'));
      expect(cubit.state.ringTimeSpoken, 'Ringing for less than a minute');
    });

    test('holds still inside a minute and moves at the next one', () async {
      clock = opened.add(const Duration(minutes: 2, seconds: 5));
      await cubit.load(incidentId: 'inc_1');
      expect(cubit.state.ringTimeSpoken, 'Ringing for 2 minutes');

      clock = opened.add(const Duration(minutes: 2, seconds: 50));
      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(cubit.state.subtext, contains('2 min 50 s'));
      expect(cubit.state.ringTimeSpoken, 'Ringing for 2 minutes');

      clock = opened.add(const Duration(minutes: 3, seconds: 1));
      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(cubit.state.ringTimeSpoken, 'Ringing for 3 minutes');
    });
  });
}
