import 'package:bloc_test/bloc_test.dart';
import 'package:critalarm/app/di.dart';
import 'package:critalarm/app/router.dart';
import 'package:critalarm/app/state/topics_cubit.dart';
import 'package:critalarm/core/models/message.dart';
import 'package:critalarm/core/platform/platform_capabilities.dart';
import 'package:critalarm/design/components/buttons.dart';
import 'package:critalarm/design/theme/theme.dart';
import 'package:critalarm/design/tokens/colors.dart';
import 'package:critalarm/features/incidents/domain/entities/incident.dart';
import 'package:critalarm/features/incidents/domain/setup_test_kind.dart';
import 'package:critalarm/features/incidents/presentation/alarm_loudness_screen.dart';
import 'package:critalarm/features/incidents/presentation/critical_alarm_screen.dart';
import 'package:critalarm/features/incidents/presentation/cubits/critical_alarm_cubit.dart';
import 'package:critalarm/features/incidents/presentation/cubits/critical_alarm_state.dart';
import 'package:critalarm/features/local_reminders/domain/incident_kinds.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockAlarmCubit extends MockCubit<CriticalAlarmState>
    implements CriticalAlarmCubit {}

/// "Loud enough?" on the acknowledged screen of a test alarm, built straight
/// from [AcknowledgedScreen] with a state the test controls.
void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await configureDependencies(useMockApi: true);
  });

  Future<void> runOn(TargetPlatform platform) async {
    await getIt.unregister<PlatformCapabilities>();
    getIt.registerSingleton<PlatformCapabilities>(
      PlatformCapabilities(isWeb: false, platform: platform),
    );
  }

  tearDown(() => runOn(defaultTargetPlatform));

  final now = DateTime.now();

  // The setup test the server sent, acknowledged, on a flow with the real
  // ring step.
  final setupTest = CriticalAlarmState(
    status: CriticalAlarmStatus.acknowledged,
    incident: Incident(
      id: 'inc_setup',
      topic: 'prod-db',
      openedAt: now.subtract(const Duration(minutes: 1)),
      ackedAt: now,
    ),
    topic: 'prod-db',
    isAcknowledged: true,
    setupTestIncidentIds: const {'inc_setup'},
    setupFlowHasRealRing: true,
  );

  // The test sent from the test ring screen after a phone update. Setup is
  // long done, so it ends on the exits of an incident.
  CriticalAlarmState afterUpdateTest({String? title}) => CriticalAlarmState(
    status: CriticalAlarmStatus.acknowledged,
    incident: Incident(
      id: 'inc_test',
      topic: 'prod-db',
      openedAt: now.subtract(const Duration(minutes: 1)),
      ackedAt: now,
      messages: [
        Message(
          id: 'm_1',
          topic: 'prod-db',
          title: title ?? IncidentKinds.testAlarmTitle,
          priority: 5,
        ),
      ],
    ),
    topic: 'prod-db',
    isAcknowledged: true,
    isOnboardingDone: true,
  );

  // The phone-only test run again after setup.
  final retest = CriticalAlarmState(
    status: CriticalAlarmStatus.acknowledged,
    incident: Incident(
      id: phoneOnlyTestIncidentId,
      topic: phoneOnlyTestTopic,
      openedAt: now.subtract(const Duration(minutes: 1)),
      ackedAt: now,
    ),
    topic: phoneOnlyTestTopic,
    isAcknowledged: true,
    isOnboardingDone: true,
  );

  late _MockAlarmCubit cubit;

  Future<GoRouter> pump(WidgetTester tester, CriticalAlarmState state) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    cubit = _MockAlarmCubit();
    when(() => cubit.state).thenReturn(state);
    when(() => cubit.closeSetupTests(any())).thenAnswer((_) async => true);
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, _) => AcknowledgedScreen(
            state: state,
            colors: context.appColors,
          ),
        ),
        GoRoute(
          path: '/alarm-loudness',
          name: AppRoute.alarmLoudness,
          builder: (_, _) =>
              AlarmLoudnessScreen(openSettings: () async => true),
        ),
        GoRoute(
          path: '/ring',
          name: AppRoute.testRing,
          builder: (_, _) => const Text('test ring screen'),
        ),
        GoRoute(
          path: '/onboarding/real-ring',
          builder: (_, _) => const Text('real ring step'),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<TopicsCubit>.value(value: getIt<TopicsCubit>()),
          BlocProvider<CriticalAlarmCubit>.value(value: cubit),
        ],
        child: MaterialApp.router(
          theme: buildLightTheme(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    return router;
  }

  Finder question() => find.text('Loud enough?');

  Future<void> tapButton(WidgetTester tester, String label) async {
    await tester.tap(find.widgetWithText(AppButton, label));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  group('after the setup test ring', () {
    testWidgets('an iPhone asks Loud enough? above Continue', (tester) async {
      await runOn(TargetPlatform.iOS);
      await pump(tester, setupTest);

      expect(tester.takeException(), isNull);
      expect(question(), findsOneWidget);
      expect(find.widgetWithText(AppButton, 'Yes'), findsOneWidget);
      expect(find.widgetWithText(AppButton, 'No'), findsOneWidget);
      expect(find.widgetWithText(AppButton, 'Continue'), findsOneWidget);
      expect(
        tester.getRect(question()).bottom,
        lessThan(
          tester.getRect(find.widgetWithText(AppButton, 'Continue')).top,
        ),
      );
    });

    testWidgets('Android does not ask', (tester) async {
      await runOn(TargetPlatform.android);
      await pump(tester, setupTest);

      expect(question(), findsNothing);
      expect(find.widgetWithText(AppButton, 'Continue'), findsOneWidget);
    });

    testWidgets('Yes takes the question away and setup goes on', (
      tester,
    ) async {
      await runOn(TargetPlatform.iOS);
      await pump(tester, setupTest);

      await tapButton(tester, 'Yes');

      expect(question(), findsNothing);
      expect(find.text('Make it louder'), findsNothing);
      expect(find.widgetWithText(AppButton, 'Continue'), findsOneWidget);
    });

    testWidgets('No opens the screen with the two steps', (tester) async {
      await runOn(TargetPlatform.iOS);
      await pump(tester, setupTest);

      await tapButton(tester, 'No');

      expect(find.text('Make it louder'), findsOneWidget);
      expect(
        find.text(
          'In Settings, open Sounds & Haptics and turn Ringtone and Alerts '
          'all the way up.',
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          'Turn off Change with Buttons, so the volume buttons cannot turn '
          'the alarm down.',
        ),
        findsOneWidget,
      );
      expect(find.widgetWithText(AppButton, 'Open Settings'), findsOneWidget);
      expect(find.widgetWithText(AppButton, 'Ring again'), findsOneWidget);
    });
  });

  testWidgets('Ring again after the setup test ends that test and goes '
      'back to the step that sends it', (tester) async {
    await runOn(TargetPlatform.iOS);
    await pump(tester, setupTest);
    await tapButton(tester, 'No');

    await tapButton(tester, 'Ring again');

    verify(() => cubit.closeSetupTests('inc_setup')).called(1);
    expect(find.text('real ring step'), findsOneWidget);
  });

  group('after the post-update test ring', () {
    testWidgets('an iPhone asks Loud enough? above the exits', (tester) async {
      await runOn(TargetPlatform.iOS);
      await pump(tester, afterUpdateTest());

      expect(tester.takeException(), isNull);
      expect(question(), findsOneWidget);
      expect(find.widgetWithText(AppButton, 'Back to topics'), findsOneWidget);
    });

    testWidgets('No opens the two steps there too', (tester) async {
      await runOn(TargetPlatform.iOS);
      await pump(tester, afterUpdateTest());

      await tapButton(tester, 'No');

      expect(find.text('Make it louder'), findsOneWidget);
      expect(find.widgetWithText(AppButton, 'Ring again'), findsOneWidget);
    });

    testWidgets('a real alarm is never asked', (tester) async {
      await runOn(TargetPlatform.iOS);
      await pump(tester, afterUpdateTest(title: 'Backup failed'));

      expect(question(), findsNothing);
      expect(find.widgetWithText(AppButton, 'At my desk'), findsOneWidget);
    });

    testWidgets('Android does not ask', (tester) async {
      await runOn(TargetPlatform.android);
      await pump(tester, afterUpdateTest());

      expect(question(), findsNothing);
    });
  });

  group('the two-step screen', () {
    testWidgets('Open Settings says where Sounds & Haptics is', (tester) async {
      await runOn(TargetPlatform.iOS);
      await pump(tester, retest);
      await tapButton(tester, 'No');

      await tapButton(tester, 'Open Settings');

      expect(
        find.text(
          'Settings opens on the Crit Alarm page. Go back one step for '
          'Sounds & Haptics.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('Ring again offers the test ring again', (tester) async {
      await runOn(TargetPlatform.iOS);
      await pump(tester, retest);
      await tapButton(tester, 'No');

      await tapButton(tester, 'Ring again');

      expect(find.text('test ring screen'), findsOneWidget);
    });
  });
}
