import 'package:critalarm/app/di.dart';
import 'package:critalarm/app/router.dart';
import 'package:critalarm/core/api/api_session.dart';
import 'package:critalarm/core/api/mock_server.dart';
import 'package:critalarm/core/storage/api_session_store.dart';
import 'package:critalarm/core/version/app_version.dart';
import 'package:critalarm/design/components/dialogs.dart';
import 'package:critalarm/design/components/switches.dart';
import 'package:critalarm/design/theme/theme.dart';
import 'package:critalarm/features/onboarding/domain/entities/server_connection.dart';
import 'package:critalarm/features/onboarding/domain/usecases/save_connection_usecase.dart';
import 'package:critalarm/features/settings/domain/repositories/privacy_repository.dart';
import 'package:critalarm/features/settings/presentation/cubits/theme_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  group('SettingsScreen', () {
    testWidgets(
      'lists the rows that lead to each sub screen, and Health reaches '
      '/settings/permissions',
      (tester) async {
        tester.view.physicalSize = const Size(390 * 2, 844 * 2);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(tester.view.reset);

        getIt<MockServer>().seedCalm();

        final router = buildRouter();
        await tester.pumpWidget(buildTestApp(router));

        router.go('/settings');
        await tester.pumpAndSettle();

        expect(find.text('Settings'), findsOneWidget);
        expect(find.text('Health'), findsOneWidget);
        expect(find.text('Alarms'), findsOneWidget);
        expect(find.text('Server'), findsOneWidget);
        expect(find.text('Privacy'), findsOneWidget);
        expect(find.text('About'), findsOneWidget);
        expect(find.text('Redo onboarding'), findsOneWidget);

        // Both of these were dropped: priority is a per-message header, not a
        // topic setting, and Health already leads to permissions.
        expect(find.text('Per-topic priority'), findsNothing);
        expect(find.text('Device permissions'), findsNothing);

        await tester.tap(find.text('Health'));
        await tester.pumpAndSettle();

        // The permissions screen is titled Health and lists the permissions.
        expect(find.text('Health'), findsAtLeast(1));
        expect(find.text('Device permissions'), findsOneWidget);
      },
    );

    testWidgets(
      'displays connected server card with Edit and Disconnect buttons',
      (tester) async {
        tester.view.physicalSize = const Size(390 * 2, 844 * 2);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(tester.view.reset);

        // Save a connection so the server screen loads connected state
        await getIt<SaveConnectionUsecase>()(
          const ServerConnection(
            serverUrl: 'https://alerts.anvilnine.com',
            adminToken: 'admin_test_token',
          ),
        );

        // Seed a self-hosted session so the badge reads its real mode.
        await getIt<ApiSessionStore>().write(
          ApiSession(
            baseUri: Uri.parse('https://alerts.anvilnine.com'),
            relayUri: Uri.parse('https://relay.critalarm.app'),
            mode: ServerMode.selfhosted,
            managementCredential: 'admin_test_token',
          ),
        );

        getIt<MockServer>().seedCalm();

        final router = buildRouter();
        await tester.pumpWidget(buildTestApp(router));

        router.go('/settings/server');
        await tester.pumpAndSettle();

        expect(find.text('Server connection'), findsOneWidget);
        expect(find.text('Connected'), findsOneWidget);
        expect(find.text('Self-hosted'), findsOneWidget);
        expect(find.text('https://alerts.anvilnine.com'), findsOneWidget);
        expect(find.text('Edit'), findsOneWidget);
        expect(find.text('Disconnect'), findsOneWidget);
      },
    );

    testWidgets('a hosted server hides the Self-hosted badge', (tester) async {
      tester.view.physicalSize = const Size(390 * 2, 844 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);

      await getIt<SaveConnectionUsecase>()(
        const ServerConnection(
          serverUrl: 'https://alerts.anvilnine.com',
          adminToken: 'admin_test_token',
        ),
      );

      await getIt<ApiSessionStore>().write(
        ApiSession(
          baseUri: Uri.parse('https://alerts.anvilnine.com'),
          relayUri: Uri.parse('https://relay.critalarm.app'),
          mode: ServerMode.hosted,
          managementCredential: 'admin_test_token',
        ),
      );

      getIt<MockServer>().seedCalm();

      final router = buildRouter();
      await tester.pumpWidget(buildTestApp(router));

      router.go('/settings/server');
      await tester.pumpAndSettle();

      expect(find.text('Connected'), findsOneWidget);
      expect(find.text('Self-hosted'), findsNothing);
    });

    testWidgets('tapping Edit opens edit server connection bottom sheet', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390 * 2, 844 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);

      await getIt<SaveConnectionUsecase>()(
        const ServerConnection(
          serverUrl: 'https://alerts.anvilnine.com',
          adminToken: 'admin_test_token',
        ),
      );

      final router = buildRouter();
      await tester.pumpWidget(buildTestApp(router));

      router.go('/settings/server');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();

      expect(find.text('Edit server connection'), findsOneWidget);
      expect(find.text('SERVER URL'), findsOneWidget);
      expect(find.text('ADMIN TOKEN'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Edit server connection'), findsNothing);
    });

    testWidgets('tapping Disconnect asks confirmation, clears connection, and '
        'shows disconnected state', (tester) async {
      tester.view.physicalSize = const Size(390 * 2, 844 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);

      await getIt<SaveConnectionUsecase>()(
        const ServerConnection(
          serverUrl: 'https://alerts.anvilnine.com',
          adminToken: 'admin_test_token',
        ),
      );

      final router = buildRouter();
      await tester.pumpWidget(buildTestApp(router));

      router.go('/settings/server');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Disconnect'));
      await tester.pumpAndSettle();

      // Verify confirmation dialog
      expect(find.text('Disconnect server?'), findsOneWidget);
      expect(
        find.text(
          'You will stop receiving pages until you connect again.',
        ),
        findsOneWidget,
      );

      // Tap Confirm Disconnect
      final disconnectButton = find.descendant(
        of: find.byType(AppDialog),
        matching: find.text('Disconnect'),
      );
      await tester.tap(disconnectButton);
      await tester.pumpAndSettle();

      // Shows disconnected state with "Connect server" button
      expect(find.text('Disconnected'), findsOneWidget);
      expect(find.text('Connect server'), findsOneWidget);

      // Tapping Connect server navigates to /onboarding/connect
      await tester.tap(find.text('Connect server'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Connect your server?'), findsOneWidget);
    });

    testWidgets('privacy screen shows opt-in toggles OFF by default '
        'and 1-line explanations', (tester) async {
      tester.view.physicalSize = const Size(390 * 2, 844 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);

      // Ensure privacy repository is reset to false
      final privacyRepo = getIt<PrivacyRepository>();
      await privacyRepo.setAnalyticsEnabled(enabled: false);
      await privacyRepo.setCrashReportingEnabled(enabled: false);

      final router = buildRouter();
      await tester.pumpWidget(buildTestApp(router));

      router.go('/settings/privacy');
      await tester.pumpAndSettle();

      expect(find.text('Privacy'), findsAtLeast(1));
      expect(find.text('Share anonymous usage analytics'), findsOneWidget);
      expect(
        find.text(
          'Which screens you open. No topic names, no message content.',
        ),
        findsOneWidget,
      );
      expect(find.text('Send crash reports'), findsOneWidget);
      expect(
        find.text(
          'What the app was doing when it crashed, plus your device model.',
        ),
        findsOneWidget,
      );

      // Verify both switches are OFF by default
      final analyticsSwitchFinder = find.descendant(
        of: find.ancestor(
          of: find.text('Share anonymous usage analytics'),
          matching: find.byType(AppToggleRow),
        ),
        matching: find.byType(AppSwitch),
      );
      final analyticsSwitch = tester.widget<AppSwitch>(analyticsSwitchFinder);
      expect(analyticsSwitch.value, isFalse);

      final crashSwitchFinder = find.descendant(
        of: find.ancestor(
          of: find.text('Send crash reports'),
          matching: find.byType(AppToggleRow),
        ),
        matching: find.byType(AppSwitch),
      );
      final crashSwitch = tester.widget<AppSwitch>(crashSwitchFinder);
      expect(crashSwitch.value, isFalse);

      // Toggle analytics switch
      await tester.tap(analyticsSwitchFinder);
      await tester.pumpAndSettle();

      final updatedAnalytics = (await privacyRepo.getPrivacySettings())
          .getOrNull();
      expect(updatedAnalytics?.analyticsEnabled, isTrue);

      // Toggle crash reporting switch
      await tester.tap(crashSwitchFinder);
      await tester.pumpAndSettle();

      final updatedCrash = (await privacyRepo.getPrivacySettings()).getOrNull();
      expect(updatedCrash?.crashReportingEnabled, isTrue);
    });

    testWidgets(
      'about screen shows version, GPL-3.0 license, and links',
      (tester) async {
        tester.view.physicalSize = const Size(390 * 2, 844 * 2);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(tester.view.reset);

        // No url_launcher plugin answers under flutter_test, so stand in for
        // it: `launched` is what the platform reports back.
        var launched = true;
        final launchedUrls = <String>[];
        const launcherChannel = MethodChannel(
          'plugins.flutter.io/url_launcher',
        );
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(launcherChannel, (call) async {
              if (call.method == 'launch') {
                launchedUrls.add(
                  (call.arguments as Map<Object?, Object?>)['url']! as String,
                );
              }
              return launched;
            });
        addTearDown(
          () => TestDefaultBinaryMessengerBinding
              .instance
              .defaultBinaryMessenger
              .setMockMethodCallHandler(launcherChannel, null),
        );

        final router = buildRouter();
        await tester.pumpWidget(buildTestApp(router));

        router.go('/settings/about');
        await tester.pumpAndSettle();

        expect(find.text('About'), findsAtLeast(1));
        expect(find.text('Version'), findsOneWidget);
        expect(find.text('v$appVersion'), findsOneWidget);
        expect(find.text('License'), findsOneWidget);
        expect(find.text('GPL-3.0'), findsOneWidget);
        expect(find.text('Documentation'), findsOneWidget);
        expect(find.text('https://docs.critalarm.app'), findsOneWidget);
        expect(find.text('GitHub'), findsOneWidget);
        expect(
          find.text('https://github.com/critalarm/critalarm'),
          findsOneWidget,
        );
        expect(find.text('Issue Tracker'), findsOneWidget);
        expect(
          find.text('https://github.com/critalarm/critalarm/issues'),
          findsOneWidget,
        );

        // The browser opened, so nothing is copied and no toast appears.
        launched = true;
        await tester.tap(find.text('Documentation'));
        await tester.pumpAndSettle();
        expect(find.textContaining('Copied '), findsNothing);
        expect(launchedUrls, ['https://docs.critalarm.app']);

        // The browser refused, so the row copies the link instead.
        launched = false;
        await tester.tap(find.text('Documentation'));
        await tester.pumpAndSettle();
        expect(
          find.text('Copied https://docs.critalarm.app'),
          findsAtLeast(1),
        );

        // Let that toast time out, so the next one is the one on screen.
        await tester.pump(const Duration(seconds: 3));
        await tester.pumpAndSettle();

        // A long press copies whether or not the browser opened.
        await tester.longPress(find.text('GitHub'));
        await tester.pumpAndSettle();
        expect(
          find.text('Copied https://github.com/critalarm/critalarm'),
          findsAtLeast(1),
        );
      },
    );
  });
}
