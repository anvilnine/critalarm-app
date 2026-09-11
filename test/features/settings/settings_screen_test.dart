import 'package:critalarm/app/di.dart';
import 'package:critalarm/app/router.dart';
import 'package:critalarm/core/api/mock_server.dart';
import 'package:critalarm/design/theme/theme.dart';
import 'package:critalarm/features/settings/presentation/cubits/theme_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await configureDependencies();
  });

  testWidgets('SettingsScreen displays Device permissions row and reaches '
      '/settings/permissions', (tester) async {
    tester.view.physicalSize = const Size(390 * 2, 844 * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    getIt<MockServer>().seedCalm();

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

    router.go('/settings');
    await tester.pumpAndSettle();

    expect(find.text('Settings'), findsOneWidget);
    // Header and row name
    expect(find.text('Device permissions'), findsNWidgets(2));
    expect(find.text('Notifications, lock screen, battery'), findsOneWidget);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -350));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Notifications, lock screen, battery'));
    await tester.pumpAndSettle();

    // Verify it navigated to Device Permissions screen
    expect(find.text('Critical Alarm Capabilities'), findsOneWidget);
  });
}
