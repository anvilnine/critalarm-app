import 'package:critalarm/app/di.dart';
import 'package:critalarm/core/result/result.dart';
import 'package:critalarm/core/usecase/usecase.dart';
import 'package:critalarm/design/theme/theme.dart';
import 'package:critalarm/features/permissions/domain/entities/device_permission_item.dart';
import 'package:critalarm/features/permissions/domain/entities/device_permission_status.dart';
import 'package:critalarm/features/permissions/domain/entities/device_permission_type.dart';
import 'package:critalarm/features/permissions/domain/usecases/get_device_permissions_usecase.dart';
import 'package:critalarm/features/permissions/domain/usecases/open_permission_settings_usecase.dart';
import 'package:critalarm/features/permissions/presentation/cubits/device_permissions_cubit.dart';
import 'package:critalarm/features/permissions/presentation/device_permissions_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockGetDevicePermissionsUsecase extends Mock
    implements GetDevicePermissionsUsecase {}

class MockOpenPermissionSettingsUsecase extends Mock
    implements OpenPermissionSettingsUsecase {}

void main() {
  late MockGetDevicePermissionsUsecase mockGetPermissions;
  late MockOpenPermissionSettingsUsecase mockOpenSettings;

  final samplePermissions = [
    const DevicePermissionItem(
      type: DevicePermissionType.notifications,
      title: 'Notifications',
      description: 'Allows Crit Alarm to deliver alert banners and play sound.',
      status: DevicePermissionStatus.granted,
      canFix: false,
    ),
    const DevicePermissionItem(
      type: DevicePermissionType.fullScreenIntent,
      title: 'Full-screen intent',
      description:
          'Allows critical alerts to turn on and display over the lock screen '
          'even when phone is sleeping.',
      status: DevicePermissionStatus.denied,
      canFix: true,
    ),
    const DevicePermissionItem(
      type: DevicePermissionType.batteryOptimization,
      title: 'Battery optimization exemption',
      description:
          'Prevents Android from killing background alarm sync and delayed '
          'delivery.',
      status: DevicePermissionStatus.restricted,
      canFix: true,
    ),
  ];

  setUpAll(() {
    registerFallbackValue(const NoParams());
    registerFallbackValue(DevicePermissionType.notifications);
  });

  setUp(() async {
    mockGetPermissions = MockGetDevicePermissionsUsecase();
    mockOpenSettings = MockOpenPermissionSettingsUsecase();

    when(
      () => mockGetPermissions(any()),
    ).thenAnswer((_) async => samplePermissions.toSuccess());

    when(
      () => mockOpenSettings(any()),
    ).thenAnswer((_) async => true.toSuccess());

    await getIt.reset();
    getIt
      ..registerLazySingleton<GetDevicePermissionsUsecase>(
        () => mockGetPermissions,
      )
      ..registerLazySingleton<OpenPermissionSettingsUsecase>(
        () => mockOpenSettings,
      )
      ..registerFactory(
        () => DevicePermissionsCubit(
          getIt<GetDevicePermissionsUsecase>(),
          getIt<OpenPermissionSettingsUsecase>(),
        ),
      );
  });

  tearDown(() async {
    await getIt.reset();
  });

  Widget buildTestWidget() {
    return MaterialApp(
      theme: buildLightTheme(),
      home: const DevicePermissionsScreen(),
    );
  }

  group('DevicePermissionsScreen', () {
    testWidgets(
      'renders the Health screen with one row per permission',
      (tester) async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        // The screen is titled Health, and the permission list sits under
        // its own header.
        expect(find.text('Health'), findsOneWidget);
        expect(find.text('Device permissions'), findsOneWidget);

        expect(find.text('Notifications'), findsOneWidget);
        expect(find.text('Full-screen intent'), findsOneWidget);
        expect(find.text('Battery optimization exemption'), findsOneWidget);

        // Granted reads as a chip. The two that are off each offer a way in.
        expect(find.text('allowed'), findsOneWidget);
        expect(find.text('Turn on'), findsNWidgets(2));
        expect(find.text('Not allowed'), findsNWidgets(2));
      },
    );

    testWidgets(
      'shows the test action without fabricated server diagnostics',
      (tester) async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        expect(find.text('Send a test alarm'), findsOneWidget);
        expect(find.text('api.critalarm.app'), findsNothing);
        expect(find.text('09:45:02'), findsNothing);
        expect(find.textContaining('prod-db'), findsNothing);
        expect(find.textContaining('03:12:04'), findsNothing);
      },
    );

    testWidgets(
      'tapping Turn on calls openPermissionSettings usecase',
      (tester) async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        final turnOnButtons = find.text('Turn on');
        expect(turnOnButtons, findsNWidgets(2));

        await tester.tap(turnOnButtons.first);
        await tester.pumpAndSettle();

        verify(
          () => mockOpenSettings(DevicePermissionType.fullScreenIntent),
        ).called(1);
      },
    );

    testWidgets('re-checks permissions on app lifecycle resumed', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Initial check during loadPermissions
      verify(() => mockGetPermissions(any())).called(1);

      // Simulate app pause and resume
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      // Should have been called a second time upon resume
      verify(() => mockGetPermissions(any())).called(1);
    });
  });
}
