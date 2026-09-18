import 'package:critalarm/app/di.dart';
import 'package:critalarm/app/router.dart';
import 'package:critalarm/app/shell/shell_cubit.dart';
import 'package:critalarm/core/alarm/alarm_host.dart';
import 'package:critalarm/core/result/result.dart';
import 'package:critalarm/core/usecase/usecase.dart';
import 'package:critalarm/design/components/buttons.dart';
import 'package:critalarm/design/components/glyphs.dart';
import 'package:critalarm/design/faces/face_state.dart';
import 'package:critalarm/design/faces/face_widget.dart';
import 'package:critalarm/design/theme/theme.dart';
import 'package:critalarm/features/onboarding/presentation/onboarding_connect_screen.dart';
import 'package:critalarm/features/permissions/domain/entities/device_permission_item.dart';
import 'package:critalarm/features/permissions/domain/entities/device_permission_status.dart';
import 'package:critalarm/features/permissions/domain/entities/device_permission_type.dart';
import 'package:critalarm/features/permissions/domain/usecases/get_device_permissions_usecase.dart';
import 'package:critalarm/features/permissions/presentation/widgets/setup_health_banner.dart';
import 'package:critalarm/features/prompts/domain/repositories/home_prompt_repository.dart';
import 'package:critalarm/features/prompts/presentation/cubits/home_prompt_cubit.dart';
import 'package:critalarm/features/prompts/presentation/cubits/home_prompt_state.dart';
import 'package:critalarm/features/prompts/presentation/widgets/account_prompt_card.dart';
import 'package:critalarm/features/prompts/presentation/widgets/home_prompt_slot.dart';
import 'package:critalarm/features/prompts/presentation/widgets/no_server_prompt_card.dart';
import 'package:critalarm/features/prompts/presentation/widgets/pro_prompt_card.dart';
import 'package:critalarm/features/settings/presentation/cubits/theme_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/alarm/fake_alarm_host.dart';

class StubHomePromptCubit extends Cubit<HomePromptState>
    implements HomePromptCubit {
  StubHomePromptCubit(super.initialState);

  int dismissCalls = 0;
  int resumedCalls = 0;
  int refreshCalls = 0;

  @override
  Future<void> dismissCurrent() async {
    dismissCalls++;
    emit(state.copyWith(isDismissing: true));
  }

  @override
  Future<void> onAppResumed() async {
    resumedCalls++;
  }

  @override
  Future<void> refresh() async {
    refreshCalls++;
  }

  @override
  Future<void> load() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakePermissionsUsecase implements GetDevicePermissionsUsecase {
  List<DevicePermissionItem> items = [];

  @override
  Future<AppResult<List<DevicePermissionItem>>> call(NoParams input) async =>
      Success(items);
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    FakeAlarmHost();
    await configureDependencies(useMockApi: true);
  });

  Widget wrapWithTheme(Widget child, {ShellCubit? shellCubit}) {
    final permissionsUsecase = FakePermissionsUsecase();
    final effectiveShell = shellCubit ?? ShellCubit(permissionsUsecase);

    return BlocProvider<ThemeCubit>.value(
      value: getIt<ThemeCubit>(),
      child: BlocProvider<ShellCubit>.value(
        value: effectiveShell,
        child: MaterialApp(
          theme: buildLightTheme(),
          home: Scaffold(body: child),
        ),
      ),
    );
  }

  group('NoServerPromptCard', () {
    testWidgets('renders critical blocker error styling and text',
        (tester) async {
      await tester.pumpWidget(wrapWithTheme(const NoServerPromptCard()));
      await tester.pumpAndSettle();

      expect(find.text('No server connected'), findsOneWidget);
      expect(
        find.text(
          'Crit Alarm cannot receive alarms without a server. '
          'Connect to Crit Alarm Cloud or point to your own.',
        ),
        findsOneWidget,
      );
      expect(find.text('Connect server'), findsOneWidget);

      final face = tester.widget<FaceWidget>(find.byType(FaceWidget));
      expect(face.state, FaceState.worried);
    });
  });

  group('SetupHealthBanner Battery Warning vs Critical Error', () {
    testWidgets(
        'renders warning orange with watching face when only battery opt off',
        (tester) async {
      final fakePerms = FakePermissionsUsecase();
      fakePerms.items = [
        const DevicePermissionItem(
          type: DevicePermissionType.batteryOptimization,
          status: DevicePermissionStatus.denied,
          title: 'Battery optimization',
          description: 'May delay alarms',
          canFix: true,
        ),
      ];

      final shellCubit = ShellCubit(fakePerms);
      await shellCubit.refresh();

      await tester.pumpWidget(
        wrapWithTheme(const SetupHealthBanner(), shellCubit: shellCubit),
      );
      await tester.pumpAndSettle();

      expect(find.text('Pages may arrive late'), findsOneWidget);
      expect(
        find.text(
          'Battery optimization is on. '
          'Turn off to receive alarms without delay.',
        ),
        findsOneWidget,
      );
      expect(find.text('Fix this'), findsOneWidget);

      final face = tester.widget<FaceWidget>(find.byType(FaceWidget));
      expect(face.state, FaceState.watching);
    });

    testWidgets('renders critical error with worried face when notifications denied',
        (tester) async {
      final fakePerms = FakePermissionsUsecase();
      fakePerms.items = [
        const DevicePermissionItem(
          type: DevicePermissionType.notifications,
          status: DevicePermissionStatus.denied,
          title: 'Notifications',
          description: 'Required for alarms',
          canFix: true,
        ),
      ];

      final shellCubit = ShellCubit(fakePerms);
      await shellCubit.refresh();

      await tester.pumpWidget(
        wrapWithTheme(const SetupHealthBanner(), shellCubit: shellCubit),
      );
      await tester.pumpAndSettle();

      expect(find.text('Crit Alarm cannot reach you yet'), findsOneWidget);
      expect(find.text('Notifications is off.'), findsOneWidget);

      final face = tester.widget<FaceWidget>(find.byType(FaceWidget));
      expect(face.state, FaceState.worried);
    });
  });

  group('AccountPromptCard', () {
    testWidgets('renders account backup copy and dismiss button calls cubit',
        (tester) async {
      final stubCubit = StubHomePromptCubit(
        const HomePromptState(promptType: HomePromptType.accountBackup),
      );

      await tester.pumpWidget(
        wrapWithTheme(
          BlocProvider<HomePromptCubit>.value(
            value: stubCubit,
            child: const AccountPromptCard(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Back up your topics'), findsOneWidget);
      expect(
        find.text(
          'Sign in to keep your topics safe if you switch or lose your device.',
        ),
        findsOneWidget,
      );
      expect(find.text('Sign in'), findsOneWidget);

      final face = tester.widget<FaceWidget>(find.byType(FaceWidget));
      expect(face.state, FaceState.calm);

      // Tap close button (X)
      final closeButton = find.byType(AppIconButton);
      expect(closeButton, findsOneWidget);
      await tester.tap(closeButton);
      await tester.pump();

      expect(stubCubit.dismissCalls, 1);
    });
  });

  group('ProPromptCard (Bulleted)', () {
    testWidgets('renders title, PRO badge, 3 bullet points, and dismiss button',
        (tester) async {
      final stubCubit = StubHomePromptCubit(
        const HomePromptState(promptType: HomePromptType.proSupport),
      );

      await tester.pumpWidget(
        wrapWithTheme(
          BlocProvider<HomePromptCubit>.value(
            value: stubCubit,
            child: const ProPromptCard(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Support Crit Alarm Pro'), findsOneWidget);
      expect(find.text('PRO'), findsOneWidget);
      expect(
        find.text('Support solo development and remove limits:'),
        findsOneWidget,
      );

      // Verify the 3 bullets requested by user
      expect(
        find.text('Unlimited critical topics (raise your limits)'),
        findsOneWidget,
      );
      expect(
        find.text('Rings repeatedly until acknowledged'),
        findsOneWidget,
      );
      expect(
        find.text('Support independent development'),
        findsOneWidget,
      );

      expect(find.text('See Pro plans'), findsOneWidget);

      // Verify checkmark glyphs
      final checkGlyphs = find.byWidgetPredicate(
        (w) => w is AppGlyph && w.glyph == GlyphType.check,
      );
      expect(checkGlyphs, findsNWidgets(3));

      // Tap close button
      final closeButton = find.byType(AppIconButton);
      expect(closeButton, findsOneWidget);
      await tester.tap(closeButton);
      await tester.pump();

      expect(stubCubit.dismissCalls, 1);
    });
  });

  group('HomePromptSlot', () {
    testWidgets('renders active prompt and collapses when none',
        (tester) async {
      final stubCubit = StubHomePromptCubit(
        const HomePromptState(promptType: HomePromptType.noServer),
      );

      await tester.pumpWidget(
        wrapWithTheme(
          BlocProvider<HomePromptCubit>.value(
            value: stubCubit,
            child: const HomePromptSlot(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(NoServerPromptCard), findsOneWidget);

      // Switch to none
      stubCubit.emit(const HomePromptState(promptType: HomePromptType.none));
      await tester.pumpAndSettle();

      expect(find.byType(NoServerPromptCard), findsNothing);
      expect(find.byType(AccountPromptCard), findsNothing);
    });
  });

  group('OnboardingConnectScreen Back Button Fix', () {
    testWidgets('uses GlyphType.back pointing left with common_back aria label',
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

      router.go('/onboarding/connect');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(OnboardingConnectScreen), findsOneWidget);

      // Verify back button is AppIconButton with GlyphType.back
      final backButtonFinder = find.descendant(
        of: find.byType(OnboardingConnectScreen),
        matching: find.byWidgetPredicate(
          (w) => w is AppIconButton && w.glyph == GlyphType.back,
        ),
      );
      expect(backButtonFinder, findsOneWidget);

      final backBtn = tester.widget<AppIconButton>(backButtonFinder);
      expect(backBtn.ariaLabel, 'Back');
    });
  });
}
