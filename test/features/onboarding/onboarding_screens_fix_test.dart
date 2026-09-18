import 'package:critalarm/app/di.dart';
import 'package:critalarm/app/router.dart';
import 'package:critalarm/core/result/result.dart';
import 'package:critalarm/design/faces/face_state.dart';
import 'package:critalarm/design/faces/face_widget.dart';
import 'package:critalarm/design/theme/theme.dart';
import 'package:critalarm/features/onboarding/domain/entities/notification_permission_status.dart';
import 'package:critalarm/features/onboarding/domain/repositories/notification_permission_repository.dart';
import 'package:critalarm/features/onboarding/presentation/onboarding_connect_screen.dart';
import 'package:critalarm/features/onboarding/presentation/onboarding_permissions_screen.dart';
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

  group('OnboardingPermissionsScreen step count and hero', () {
    testWidgets(
      'shows Step 1 of 2 and FaceWidget has Hero tag',
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
        expect(find.text('Step 1 of 2'), findsOneWidget);

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
      'is not scrollable, Set this up later is TextButton, and contains Hero '
      'face',
      (tester) async {
        tester.view.physicalSize = const Size(390 * 2, 844 * 2);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(tester.view.reset);

        final router = buildRouter();
        await tester.pumpWidget(buildTestApp(router));

        router.go('/onboarding/connect');
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.byType(OnboardingConnectScreen), findsOneWidget);

        // 1. Check screen is not scrollable (NeverScrollableScrollPhysics)
        final scrollView = tester.widget<CustomScrollView>(
          find.descendant(
            of: find.byType(OnboardingConnectScreen),
            matching: find.byType(CustomScrollView),
          ),
        );
        expect(scrollView.physics, isA<NeverScrollableScrollPhysics>());

        // 2. Check Set this up later is a TextButton
        final skipButtonFinder = find.widgetWithText(
          TextButton,
          'Set this up later',
        );
        expect(skipButtonFinder, findsOneWidget);

        // 3. Check face is present in middle area with Hero tag
        final heroFinder = find.byWidgetPredicate(
          (widget) => widget is Hero && widget.tag == 'onboarding-face',
        );
        expect(heroFinder, findsOneWidget);

        final faceFinder = find.descendant(
          of: heroFinder,
          matching: find.byType(FaceWidget),
        );
        expect(faceFinder, findsOneWidget);
        final face = tester.widget<FaceWidget>(faceFinder);
        expect(face.state, FaceState.watching);
        expect(face.size, 80);

        // 4. Check Crit Alarm Cloud card is present
        expect(find.text('Crit Alarm Cloud'), findsOneWidget);
        expect(find.text('EASIEST'), findsOneWidget);
        expect(
          find.text('We run the server. Nothing to set up.'),
          findsOneWidget,
        );
        expect(
          find.text('Continue with Crit Alarm Cloud'),
          findsOneWidget,
        );
      },
    );
  });
}
