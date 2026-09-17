import 'package:critalarm/core/models/server_info.dart';
import 'package:critalarm/core/usecase/usecase.dart';
import 'package:critalarm/features/incidents/domain/usecases/trigger_test_alarm_usecase.dart';
import 'package:critalarm/features/onboarding/domain/entities/server_connection.dart';
import 'package:critalarm/features/onboarding/domain/usecases/establish_api_session_usecase.dart';
import 'package:critalarm/features/onboarding/domain/usecases/get_server_info_usecase.dart';
import 'package:critalarm/features/onboarding/domain/usecases/save_connection_usecase.dart';
import 'package:critalarm/features/onboarding/presentation/cubits/onboarding_connect_cubit.dart';
import 'package:critalarm/features/onboarding/presentation/cubits/onboarding_connect_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../core/alarm/fake_alarm_host.dart';

class _MockGetServerInfo extends Mock implements GetServerInfoUsecase {}

class _MockSaveConnection extends Mock implements SaveConnectionUsecase {}

class _MockTriggerTestAlarm extends Mock implements TriggerTestAlarmUsecase {}

class _MockEstablishSession extends Mock
    implements EstablishApiSessionUsecase {}

/// The onboarding demo alarm has to reach the speaker.
///
/// Android reads `server` back out of the alarm intent and drops the whole
/// start when it is not an http or https URL. Passing an empty string meant
/// the service stopped itself while the countdown on screen ran to the end
/// and reported success. The user was congratulated for a ring that never
/// happened, which is the one thing this screen exists to prove.
void main() {
  late FakeAlarmHost alarm;

  setUpAll(() {
    registerFallbackValue(Uri.parse('https://api.critalarm.app'));
    registerFallbackValue(const NoParams());
    registerFallbackValue(
      const ServerConnection(serverUrl: '', adminToken: ''),
    );
    registerFallbackValue(
      const ServerInfo(
        version: '0.1.0',
        baseUrl: 'https://api.critalarm.app',
        relayUrl: 'https://relay.critalarm.app',
      ),
    );
  });

  setUp(() => alarm = FakeAlarmHost());
  tearDown(() => alarm.dispose());

  OnboardingConnectCubit build() => OnboardingConnectCubit(
    _MockGetServerInfo(),
    _MockSaveConnection(),
    _MockTriggerTestAlarm(),
    establishSession: _MockEstablishSession(),
    alarmHost: alarm.host,
  );

  test('the demo alarm is scheduled against the connected server', () async {
    final cubit = build()..serverUrlChanged('https://alerts.example.com');

    await cubit.startLocalTestAlarm();

    expect(
      alarm.argsOnce('scheduleAlarm')['server'],
      'https://alerts.example.com',
    );
    expect(cubit.state.testAlarmStatus, TestAlarmStatus.ringing);
    await cubit.close();
  });

  test('surrounding whitespace is trimmed off the server', () async {
    final cubit = build()..serverUrlChanged('  https://alerts.example.com  ');

    await cubit.startLocalTestAlarm();

    expect(
      alarm.argsOnce('scheduleAlarm')['server'],
      'https://alerts.example.com',
    );
    await cubit.close();
  });

  test('with no server the alarm is not scheduled and says so', () async {
    final cubit = build();

    await cubit.startLocalTestAlarm();

    expect(alarm.callsTo('scheduleAlarm'), isEmpty);
    expect(cubit.state.testAlarmStatus, TestAlarmStatus.failure);
    expect(cubit.state.isCountingDown, isFalse);
    await cubit.close();
  });
}
