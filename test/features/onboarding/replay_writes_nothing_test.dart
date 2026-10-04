import 'package:critalarm/core/api/api_session.dart';
import 'package:critalarm/core/models/server_info.dart';
import 'package:critalarm/features/incidents/domain/usecases/trigger_test_alarm_usecase.dart';
import 'package:critalarm/features/onboarding/data/repositories/shared_prefs_onboarding_progress_repository.dart';
import 'package:critalarm/features/onboarding/domain/flow/onboarding_replay_rules.dart';
import 'package:critalarm/features/onboarding/domain/usecases/establish_api_session_usecase.dart';
import 'package:critalarm/features/onboarding/domain/usecases/get_server_info_usecase.dart';
import 'package:critalarm/features/onboarding/domain/usecases/onboarding_draft_usecases.dart';
import 'package:critalarm/features/onboarding/domain/usecases/save_connection_usecase.dart';
import 'package:critalarm/features/onboarding/presentation/cubits/onboarding_connect_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockGetServerInfo extends Mock implements GetServerInfoUsecase {}

class _MockSaveConnection extends Mock implements SaveConnectionUsecase {}

class _MockTriggerTestAlarm extends Mock implements TriggerTestAlarmUsecase {}

class _MockEstablishSession extends Mock
    implements EstablishApiSessionUsecase {}

void main() {
  group('what a replay may write', () {
    test('a replay saves no form draft, a real run does', () {
      expect(onboardingSavesFormDraft(isReplay: true), isFalse);
      expect(onboardingSavesFormDraft(isReplay: false), isTrue);
    });

    test('a replay makes no topic, a real run does', () {
      expect(onboardingCreatesTopic(isReplay: true), isFalse);
      expect(onboardingCreatesTopic(isReplay: false), isTrue);
    });
  });

  group('the connect form on a replay', () {
    late SharedPreferences prefs;
    late SharedPrefsOnboardingProgressRepository progress;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      progress = SharedPrefsOnboardingProgressRepository(prefs);
    });

    OnboardingConnectCubit build() => OnboardingConnectCubit(
      _MockGetServerInfo(),
      _MockSaveConnection(),
      _MockTriggerTestAlarm(),
      establishSession: _MockEstablishSession(),
      readDraft: ReadOnboardingDraftUsecase(progress),
      saveDraft: SaveOnboardingDraftUsecase(progress),
    );

    test('typing writes no draft', () async {
      final cubit = build();
      await cubit.loadConnection(isReplay: true);

      cubit
        ..toggleSelfHosting()
        ..serverUrlChanged('https://alerts.mybox.local')
        ..adminTokenChanged('ad_secret');
      await pumpEventQueue();

      expect(prefs.getKeys(), isEmpty);
      expect(cubit.state.serverUrl, 'https://alerts.mybox.local');
      await cubit.close();
    });

    test('typing on a real run still writes the draft', () async {
      final cubit = build();
      await cubit.loadConnection();

      cubit.serverUrlChanged('https://alerts.mybox.local');
      await pumpEventQueue();

      expect(
        (await progress.readDraft()).getOrNull()!.serverUrl,
        'https://alerts.mybox.local',
      );
      await cubit.close();
    });
  });
}
