import 'package:critalarm/app/di.dart';
import 'package:critalarm/app/router.dart';
import 'package:critalarm/core/api/mock_server.dart';
import 'package:critalarm/design/components/switches.dart';
import 'package:critalarm/design/theme/theme.dart';
import 'package:critalarm/features/settings/data/repositories/shared_prefs_ring_settings_repository.dart';
import 'package:critalarm/features/settings/domain/entities/ring_settings.dart';
import 'package:critalarm/features/settings/presentation/cubits/theme_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('SharedPrefsRingSettingsRepository', () {
    test('both switches start on', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      expect(
        SharedPrefsRingSettingsRepository(prefs).read(),
        const RingSettings(),
      );
      expect(const RingSettings().brightScreen, isTrue);
      expect(const RingSettings().vibrate, isTrue);
    });

    test('keeps each switch under the key the alarm code reads', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repository = SharedPrefsRingSettingsRepository(prefs);
      await repository.setBrightScreen(on: false);
      expect(prefs.getBool('ring_bright_screen'), isFalse);
      expect(repository.read().vibrate, isTrue);
      await repository.setVibrate(on: false);
      expect(prefs.getBool('ring_vibrate'), isFalse);
      expect(
        SharedPrefsRingSettingsRepository(prefs).read(),
        const RingSettings(brightScreen: false, vibrate: false),
      );
    });
  });

  group('Settings ring switches', () {
    setUpAll(() async {
      SharedPreferences.setMockInitialValues({});
      await configureDependencies(useMockApi: true);
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

    AppSwitch switchIn(WidgetTester tester, String key) =>
        tester.widget<AppSwitch>(
          find.descendant(
            of: find.byKey(ValueKey(key)),
            matching: find.byType(AppSwitch),
          ),
        );

    testWidgets('both show, start on, and keep what was picked', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390 * 2, 844 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);
      getIt<MockServer>().seedCalm();

      final router = buildRouter();
      await tester.pumpWidget(buildTestApp(router));
      router.go('/settings');
      await tester.pumpAndSettle();

      expect(find.text('Bright screen when it rings'), findsOneWidget);
      expect(find.text('Vibrate with the alarm'), findsOneWidget);
      expect(switchIn(tester, 'settings-ring-bright-screen').value, isTrue);
      expect(switchIn(tester, 'settings-ring-vibrate').value, isTrue);

      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey('settings-ring-bright-screen')),
          matching: find.byType(AppSwitch),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey('settings-ring-vibrate')),
          matching: find.byType(AppSwitch),
        ),
      );
      await tester.pumpAndSettle();

      final prefs = getIt<SharedPreferences>();
      expect(prefs.getBool('ring_bright_screen'), isFalse);
      expect(prefs.getBool('ring_vibrate'), isFalse);

      // Leave Settings and come back: a fresh cubit reads them off disk.
      router.go('/settings/about');
      await tester.pumpAndSettle();
      router.go('/settings');
      await tester.pumpAndSettle();
      expect(switchIn(tester, 'settings-ring-bright-screen').value, isFalse);
      expect(switchIn(tester, 'settings-ring-vibrate').value, isFalse);
    });
  });
}
