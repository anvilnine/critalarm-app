import 'package:critalarm/app/di.dart';
import 'package:critalarm/app/router.dart';
import 'package:critalarm/design/theme/theme.dart';
import 'package:critalarm/features/settings/presentation/cubits/theme_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
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

  group('Privacy and Terms links', () {
    testWidgets('About lists both pages with their URLs', (tester) async {
      tester.view.physicalSize = const Size(390 * 2, 844 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);

      final router = buildRouter();
      await tester.pumpWidget(buildTestApp(router));

      router.go('/settings/about');
      await tester.pumpAndSettle();

      expect(find.text('Privacy'), findsOneWidget);
      expect(find.text('https://critalarm.app/privacy'), findsOneWidget);
      expect(find.text('Terms'), findsOneWidget);
      expect(find.text('https://critalarm.app/terms'), findsOneWidget);
    });

    testWidgets('the paywall shows both under Restore purchases', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390 * 2, 844 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);

      final router = buildRouter();
      await tester.pumpWidget(buildTestApp(router));

      router.go('/paywall');
      await tester.pumpAndSettle();

      expect(find.text('Restore purchases'), findsOneWidget);
      expect(find.text('Terms'), findsOneWidget);
      expect(find.text('Privacy'), findsOneWidget);
    });
  });
}
