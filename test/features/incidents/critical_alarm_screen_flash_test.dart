import 'package:critalarm/core/alarm/alarm_signals.dart';
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

/// The iPhone's flash follows the alarm screen. These run the screen's cubit
/// against a fake channel and read the calls it makes.
void main() {
  late IncidentRepository repository;
  late FakeAlarmHost alarm;
  late String ringingTopic;

  CriticalAlarmCubit build({AlarmSignals Function()? screenFlashSignals}) =>
      CriticalAlarmCubit(
        GetIncidentUsecase(repository),
        GetIncidentsUsecase(repository),
        AcknowledgeIncidentUsecase(repository),
        CloseIncidentUsecase(repository),
        null,
        alarm.host,
        const Duration(seconds: 1),
        null,
        null,
        null,
        null,
        null,
        null,
        null,
        // No proof log and no setup answer: neither is looked at here.
        null,
        null,
        screenFlashSignals,
      );

  List<Object?> flashCalls() =>
      alarm.argsTo('setScreenFlash').map((a) => a['on']).toList();

  setUp(() async {
    repository = InMemoryIncidentRepository(
      MockApiClient(MockServer()..seedAlarmed()),
    );
    alarm = FakeAlarmHost();
    // Which topic the seeded alarm is on, read the way the screen reads it.
    final probe = build();
    await probe.load();
    ringingTopic = probe.state.topic;
    await probe.close();
    alarm.calls.clear();
  });

  tearDown(() => alarm.dispose());

  test('the seeded alarm rings on a named topic', () {
    expect(ringingTopic, isNotEmpty);
  });

  test('a ringing topic with the flash on starts the flash', () async {
    final cubit = build(
      screenFlashSignals: () => AlarmSignals(flashTopics: {ringingTopic}),
    );

    await cubit.load();

    expect(cubit.state.status, CriticalAlarmStatus.ringing);
    expect(flashCalls(), [true]);
    expect(alarm.argsOnce('setScreenFlash')['topics'], [ringingTopic]);
    await cubit.close();
  });

  test('the ringing line redrawing does not start it again', () async {
    final cubit = build(
      screenFlashSignals: () => AlarmSignals(flashTopics: {ringingTopic}),
    );
    await cubit.load();

    cubit
      ..emit(cubit.state.copyWith(subtext: 'Ringing 1 s.'))
      ..emit(cubit.state.copyWith(subtext: 'Ringing 2 s.'));

    expect(flashCalls(), [true]);
    await cubit.close();
  });

  test('acknowledging stops the flash', () async {
    final cubit = build(
      screenFlashSignals: () => AlarmSignals(flashTopics: {ringingTopic}),
    );
    await cubit.load();

    await cubit.acknowledge();

    expect(cubit.state.isAcknowledged, isTrue);
    expect(flashCalls(), [true, false]);
    await cubit.close();
  });

  test('the screen leaving while it rings stops the flash', () async {
    final cubit = build(
      screenFlashSignals: () => AlarmSignals(flashTopics: {ringingTopic}),
    );
    await cubit.load();

    await cubit.close();

    expect(flashCalls(), [true, false]);
  });

  test('a ringing topic with the flash off never touches it', () async {
    final cubit = build(
      screenFlashSignals: () =>
          const AlarmSignals(flashTopics: {'some-other-topic'}),
    );

    await cubit.load();
    await cubit.acknowledge();
    await cubit.close();

    expect(alarm.callsTo('setScreenFlash'), isEmpty);
  });

  test('where the flash does not follow the screen, nothing is sent', () async {
    // Android: the alarm service blinks the flash, so the screen stays out
    // of it even when the topic has the flash on.
    final cubit = build();

    await cubit.load();
    await cubit.acknowledge();
    await cubit.close();

    expect(alarm.callsTo('setScreenFlash'), isEmpty);
  });
}
