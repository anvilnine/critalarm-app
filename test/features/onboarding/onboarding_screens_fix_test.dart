import 'package:critalarm/app/di.dart';
import 'package:critalarm/app/router.dart';
import 'package:critalarm/core/result/result.dart';
import 'package:critalarm/design/faces/face_widget.dart';
import 'package:critalarm/design/theme/theme.dart';
import 'package:critalarm/features/onboarding/domain/entities/notification_permission_status.dart';
import 'package:critalarm/features/onboarding/domain/flow/onboarding_flow_engine.dart';
import 'package:critalarm/features/onboarding/domain/repositories/notification_permission_repository.dart';
import 'package:critalarm/features/onboarding/presentation/onboarding_connect_screen.dart';
import 'package:critalarm/features/onboarding/presentation/onboarding_permissions_screen.dart';
import 'package:critalarm/features/onboarding/presentation/widgets/connect_routes_picture.dart';
import 'package:critalarm/features/onboarding/presentation/widgets/setup_tracker.dart';
import 'package:critalarm/features/settings/presentation/cubits/theme_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/alarm/fake_alarm_host.dart';

class FakeNotificationPermissionRepository
    implements NotificationPermissionRepository {
  @override
  Future<AppResult<NotificationPermissionStatus>> checkPermission() async =>
      const Success(NotificationPermissionStatus.notDetermined);

  @override
  Future<AppResult<NotificationPermissionStatus>> requestPermission() async =>
      const Success(NotificationPermissionStatus.granted);

  @override
  Future<AppResult<bool>> openSettings() async => const Success(true);
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    FakeAlarmHost();
    await configureDependencies(useMockApi: true);
    if (getIt.isRegistered<NotificationPermissionRepository>()) {
      await getIt.unregister<NotificationPermissionRepository>();
    }
    getIt.registerLazySingleton<NotificationPermissionRepository>(
      FakeNotificationPermissionRepository.new,
    );
  });

  Widget buildTestApp(GoRouter router) {
    return BlocProvider<ThemeCubit>.value(
      value: getIt<ThemeCubit>(),
      child: MaterialApp.router(
        theme: buildLightTheme(),
        routerConfig: router,
      ),
    );
  }

  group('OnboardingPermissionsScreen tracker and hero', () {
    testWidgets(
      'shows the setup tracker, no step count text, and FaceWidget has Hero '
      'tag',
      (tester) async {
        tester.view.physicalSize = const Size(390 * 2, 844 * 2);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(tester.view.reset);

        final router = buildRouter();
        await tester.pumpWidget(buildTestApp(router));

        router.go('/onboarding/permissions');
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.byType(OnboardingPermissionsScreen), findsOneWidget);
        // Where setup stands is three bars with one label for a screen
        // reader. The permissions are the second step of the second part.
        expect(find.byType(SetupTracker), findsOneWidget);
        expect(find.bySemanticsLabel('Set up, part 2 of 3'), findsOneWidget);
        expect(find.textContaining('Step 1 of'), findsNothing);

        final heroFinder = find.ancestor(
          of: find.byType(FaceWidget),
          matching: find.byType(Hero),
        );
        expect(heroFinder, findsWidgets);
        final hero = tester.widget<Hero>(heroFinder.first);
        expect(hero.tag, 'onboarding-face');
      },
    );
  });

  group('OnboardingConnectScreen fixes', () {
    testWidgets(
      'scrolls only when the card does not fit, Set this up later is '
      'TextButton, and draws the '
      'two routes',
      (tester) async {
        tester.view.physicalSize = const Size(390 * 2, 844 * 2);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(tester.view.reset);

        final router = buildRouter();
        await tester.pumpWidget(buildTestApp(router));

        // Back only opens a step that was on screen in this run, so the
        // run walks to connect the way a user does.
        await tester.runAsync(() async {
          final engine = getIt<OnboardingFlowEngine>();
          await engine.finishStep('welcome');
          await engine.finishStep('how_it_rings');
        });

        router.go('/onboarding/connect');
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.byType(OnboardingConnectScreen), findsOneWidget);

        // 1. The page is still while the card fits and scrolls when it does
        // not (ClampingScrollPhysics), so a large text size never puts the
        // card out of reach.
        final scrollView = tester.widget<CustomScrollView>(
          find.descendant(
            of: find.byType(OnboardingConnectScreen),
            matching: find.byType(CustomScrollView),
          ),
        );
        expect(scrollView.physics, isA<ClampingScrollPhysics>());

        // 2. Check Set this up later is a TextButton
        final skipButtonFinder = find.widgetWithText(
          TextButton,
          'Set this up later',
        );
        expect(skipButtonFinder, findsOneWidget);

        // 3. The middle area draws the two routes, and Back is there:
        // connect goes back to how it rings.
        expect(find.byType(ConnectRoutesPicture), findsOneWidget);
        expect(find.bySemanticsLabel('Back'), findsOneWidget);

        // 4. Check Crit Alarm Cloud card is present
        // Its name is there twice: on the card and in the picture.
        expect(find.text('Crit Alarm Cloud'), findsNWidgets(2));
        expect(find.text('EASIEST'), findsOneWidget);
        expect(
          find.text('We run the server. Nothing to set up.'),
          findsOneWidget,
        );
        expect(
          find.text('Use Crit Alarm Cloud'),
          findsOneWidget,
        );
      },
    );
  });
}
