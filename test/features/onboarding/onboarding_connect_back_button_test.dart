import 'dart:async';

import 'package:critalarm/app/di.dart';
import 'package:critalarm/app/router.dart';
import 'package:critalarm/design/components/buttons.dart';
import 'package:critalarm/design/components/glyphs.dart';
import 'package:critalarm/design/theme/theme.dart';
import 'package:critalarm/features/onboarding/presentation/onboarding_connect_screen.dart';
import 'package:critalarm/features/settings/presentation/cubits/theme_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/alarm/fake_alarm_host.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    FakeAlarmHost();
    await configureDependencies(useMockApi: true);
  });

  group('OnboardingConnectScreen Back Button Fix', () {
    testWidgets(
      'onboarding has no back button; opened on top of another screen it '
      'uses GlyphType.back with common_back aria label',
      (tester) async {
        tester.view.physicalSize = const Size(390 * 2, 844 * 2);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(tester.view.reset);

        final router = buildRouter();
        await tester.pumpWidget(
          BlocProvider<ThemeCubit>.value(
            value: getIt<ThemeCubit>(),
            child: MaterialApp.router(
              theme: buildLightTheme(),
              routerConfig: router,
            ),
          ),
        );

        final backButtonFinder = find.descendant(
          of: find.byType(OnboardingConnectScreen),
          matching: find.byWidgetPredicate(
            (w) => w is AppIconButton && w.glyph == GlyphType.back,
          ),
        );

        // Reached by going forward through onboarding: nothing to go back to.
        router.go('/onboarding/connect');
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.byType(OnboardingConnectScreen), findsOneWidget);
        expect(backButtonFinder, findsNothing);

        // Pushed on top of another screen, the way Settings opens it.
        unawaited(router.push('/onboarding/connect'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 600));

        expect(backButtonFinder.last, findsOneWidget);
        final backBtn = tester.widget<AppIconButton>(backButtonFinder.last);
        expect(backBtn.ariaLabel, 'Back');
      },
    );
  });
}
