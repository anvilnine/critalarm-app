import 'dart:async';

import 'package:critalarm/app/di.dart';
import 'package:critalarm/app/router.dart';
import 'package:critalarm/app/shell/shell_cubit.dart';
import 'package:critalarm/core/result/result.dart';
import 'package:critalarm/core/usecase/usecase.dart';
import 'package:critalarm/design/components/buttons.dart';
import 'package:critalarm/design/components/glyphs.dart';
import 'package:critalarm/design/faces/face_state.dart';
import 'package:critalarm/design/faces/face_widget.dart';
import 'package:critalarm/design/theme/theme.dart';
import 'package:critalarm/features/in_app_notices/presentation/cubits/in_app_notice_cubit.dart';
import 'package:critalarm/features/in_app_notices/presentation/cubits/in_app_notice_state.dart';
import 'package:critalarm/features/in_app_notices/presentation/widgets/in_app_notice_slot.dart';
import 'package:critalarm/features/in_app_notices/presentation/widgets/no_server_notice_card.dart';
import 'package:critalarm/features/onboarding/presentation/onboarding_connect_screen.dart';
import 'package:critalarm/features/permissions/domain/entities/device_permission_item.dart';
import 'package:critalarm/features/permissions/domain/entities/device_permission_status.dart';
import 'package:critalarm/features/permissions/domain/entities/device_permission_type.dart';
import 'package:critalarm/features/permissions/domain/usecases/get_device_permissions_usecase.dart';
import 'package:critalarm/features/permissions/presentation/widgets/setup_health_notice.dart';
import 'package:critalarm/features/settings/presentation/cubits/theme_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/alarm/fake_alarm_host.dart';

class StubInAppNoticeCubit extends Cubit<InAppNoticeState>
    implements InAppNoticeCubit {
  StubInAppNoticeCubit(super.initialState);

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

  group('NoServerNoticeCard', () {
    testWidgets('renders critical blocker error styling and text', (
      tester,
    ) async {
      await tester.pumpWidget(wrapWithTheme(const NoServerNoticeCard()));
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

  group('SetupHealthNotice Battery Warning vs Critical Error', () {
    testWidgets(
      'renders warning orange with watching face when only battery opt off',
      (tester) async {
        final fakePerms = FakePermissionsUsecase()
          ..items = [
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
          wrapWithTheme(const SetupHealthNotice(), shellCubit: shellCubit),
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
      },
    );

    testWidgets('renders critical error with worried face when '
        'notifications denied', (tester) async {
      final fakePerms = FakePermissionsUsecase()
        ..items = [
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
        wrapWithTheme(const SetupHealthNotice(), shellCubit: shellCubit),
      );
      await tester.pumpAndSettle();

      expect(find.text('Crit Alarm cannot reach you yet'), findsOneWidget);
      expect(find.text('Notifications is off.'), findsOneWidget);

      final face = tester.widget<FaceWidget>(find.byType(FaceWidget));
      expect(face.state, FaceState.worried);
    });
  });

  group('InAppNoticeSlot', () {
    testWidgets('renders active prompt and collapses when none', (
      tester,
    ) async {
      final stubCubit = StubInAppNoticeCubit(
        const InAppNoticeState(noticeType: InAppNoticeType.noServer),
      );

      await tester.pumpWidget(
        wrapWithTheme(
          BlocProvider<InAppNoticeCubit>.value(
            value: stubCubit,
            child: const InAppNoticeSlot(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(NoServerNoticeCard), findsOneWidget);

      // Switch to none
      stubCubit.emit(const InAppNoticeState());
      await tester.pumpAndSettle();

      expect(find.byType(NoServerNoticeCard), findsNothing);
    });
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
