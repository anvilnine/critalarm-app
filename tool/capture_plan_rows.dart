// Captures the screens that follow the feature table for the weekly
// delivery check, the app icons and Storage, off the device, with the mock
// API and the developer plan switches.
//
//   fvm flutter test tool/capture_plan_rows.dart \
//     --dart-define=MOCK=true --dart-define=SKIP_PAYWALL=true
//
// At 390 by 844, light and dark, it writes one PNG per state:
//   reliability_free     nothing held: the weekly check row is locked and
//                        offers Hosted
//   reliability_hosted   Hosted held: the switch, with a check received
//   reliability_pro      Pro held and no Hosted: locked, and still offers
//                        Hosted
//   reliability_own      a server of the user's own, with both held: one
//                        line saying the check is not available there
//   app_icon_pro         the App icon screen with Pro alone
//   app_icon_hosted      the App icon screen with Hosted alone
//   app_icon_free        the App icon screen with nothing held
//   settings_free        Settings with nothing held, scrolled to Storage
//   storage_free         the Storage page with nothing held
//
// Optional:
//   --dart-define=OUT=<folder>   where the PNGs go (default
//                                build/plan_rows_shots)
//   --dart-define=ONLY=<part>,<part>
//                                capture only the files whose name has one
//                                of these parts
//
// A capture fails when anything overflows.
//
// Developer tool testing mock setup.
// ignore_for_file: invalid_use_of_visible_for_testing_member
// Tool prints progress to stdout.
// ignore_for_file: avoid_print

import 'dart:io';
import 'dart:ui' as ui;

import 'package:critalarm/app/di.dart';
import 'package:critalarm/app/router.dart';
import 'package:critalarm/app/state/topics_cubit.dart';
import 'package:critalarm/core/access/access_override.dart';
import 'package:critalarm/core/access/dev_access_switches.dart';
import 'package:critalarm/core/access/feature_access.dart';
import 'package:critalarm/core/access/holding.dart';
import 'package:critalarm/core/api/mock_server.dart';
import 'package:critalarm/core/app_icon/app_icon.dart';
import 'package:critalarm/core/app_icon/app_icon_host.dart';
import 'package:critalarm/core/models/weekly_check.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/settings/presentation/cubits/theme_cubit.dart';
import 'package:critalarm/features/weekly_check/domain/weekly_check_monitor.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test/helpers/load_translations.dart';

const _out = String.fromEnvironment(
  'OUT',
  defaultValue: 'build/plan_rows_shots',
);
const _only = String.fromEnvironment('ONLY');

const _size = Size(390, 844);
const _topInset = 47.0;
const _bottomInset = 34.0;

Future<void> _loadFonts() async {
  Future<void> family(String name, List<String> files) async {
    final loader = FontLoader(name);
    for (final file in files) {
      loader.addFont(
        File('assets/fonts/$file').readAsBytes().then(
          (bytes) => ByteData.view(bytes.buffer),
        ),
      );
    }
    await loader.load();
  }

  await family('Bricolage Grotesque', [
    'BricolageGrotesque-Bold.ttf',
    'BricolageGrotesque-ExtraBold.ttf',
  ]);
  await family('Instrument Sans', [
    'InstrumentSans-Regular.ttf',
    'InstrumentSans-Medium.ttf',
    'InstrumentSans-SemiBold.ttf',
    'InstrumentSans-Bold.ttf',
  ]);
  await family('JetBrains Mono', [
    'JetBrainsMono-Medium.ttf',
    'JetBrainsMono-SemiBold.ttf',
    'JetBrainsMono-Bold.ttf',
  ]);
}

/// Puts the app in one plan state through the developer switches, the same
/// seam Developer options writes. The mock relay's tier follows the Hosted
/// switch by itself.
Future<void> _hold({
  required bool isHosted,
  required bool isPro,
  bool isOwnServer = false,
}) async {
  final switches = getIt<DevAccessSwitches>();
  await switches.force(
    Holding.hosted,
    isHosted ? HoldingState.held : HoldingState.notHeld,
  );
  await switches.force(
    Holding.pro,
    isPro ? HoldingState.held : HoldingState.notHeld,
  );
  await switches.setServerMode(
    isOwnServer ? ServerModeChoice.ownServer : ServerModeChoice.cloud,
  );
  await getIt<FeatureAccess>().ready;
}

bool _wanted(String name) =>
    _only.isEmpty || _only.split(',').any(name.contains);

Future<GlobalKey> _open(
  WidgetTester tester, {
  required String location,
  required ThemeMode mode,
}) async {
  const dpr = 2.0;
  tester.view.physicalSize = _size * dpr;
  tester.view.devicePixelRatio = dpr;
  tester.view.padding = const FakeViewPadding(
    top: _topInset * dpr,
    bottom: _bottomInset * dpr,
  );
  tester.view.viewPadding = tester.view.padding;
  addTearDown(tester.view.reset);
  final boundaryKey = GlobalKey();
  await tester.pumpWidget(
    MultiBlocProvider(
      providers: [
        BlocProvider<ThemeCubit>.value(value: getIt<ThemeCubit>()),
        BlocProvider<TopicsCubit>.value(value: getIt<TopicsCubit>()),
      ],
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        theme: buildLightTheme(),
        darkTheme: buildDarkTheme(),
        themeMode: mode,
        routerConfig: buildRouter(initialLocation: location),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: RepaintBoundary(key: boundaryKey, child: child),
        ),
      ),
    ),
  );
  for (var i = 0; i < 8; i++) {
    // Reads that go through real I/O land between the frames.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 60)),
    );
    await tester.pump(const Duration(milliseconds: 200));
  }
  return boundaryKey;
}

/// Scrolls what [finder] finds to the middle of the screen, clear of the
/// title above and the tab bar below.
Future<void> _show(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isEmpty) return;
  await Scrollable.ensureVisible(
    tester.element(finder.first),
    alignment: 0.5,
  );
  await tester.pump(const Duration(milliseconds: 200));
}

Future<void> _save(WidgetTester tester, GlobalKey boundaryKey, String name) =>
    tester.runAsync(() async {
      final boundary =
          boundaryKey.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('$_out/$name.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes!.buffer.asUint8List());
      print('SAVED ${file.path}');
    });

void main() {
  setUpAll(() async {
    await loadTestTranslations();
    // The first visit to the App icon screen with icons unlocked plays a
    // welcome line once. These shots are of the screen at rest.
    SharedPreferences.setMockInitialValues({'app_icon.welcomed': true});
    await configureDependencies();
    await _loadFonts();
    // The phone can change its icon and shows the standard one.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel(AppIconHost.channelName),
          (call) async =>
              call.method == 'current' ? AppIcon.standard.platformName : true,
        );
  });

  void capture(
    String name,
    Future<void> Function(WidgetTester tester) body,
  ) {
    if (!_wanted(name)) return;
    testWidgets('capture $name', (tester) async {
      final errors = <String>[];
      final oldHandler = FlutterError.onError;
      FlutterError.onError = (details) =>
          errors.add(details.exceptionAsString());
      debugDisableShadows = false;
      try {
        await body(tester);
        expect(errors, isEmpty, reason: errors.join('\n'));
      } finally {
        debugDisableShadows = true;
        FlutterError.onError = oldHandler;
        getIt<MockServer>().seedWeeklyCheck(WeeklyCheckState.off);
        getIt<MockServer>().weeklyCheckRounds.clear();
        await tester.runAsync(
          () => getIt<DevAccessSwitches>().apply(AccessPreset.real),
        );
      }
    });
  }

  const reliability = <(String, bool, bool, bool)>[
    // name, Hosted, Pro, own server
    ('free', false, false, false),
    ('hosted', true, false, false),
    ('pro', false, true, false),
    ('own', true, true, true),
  ];
  const icons = <(String, bool, bool)>[
    ('pro', false, true),
    ('hosted', true, false),
    ('free', false, false),
  ];

  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    for (final (name, isHosted, isPro, isOwnServer) in reliability) {
      capture('reliability_${name}_${mode.name}', (tester) async {
        await tester.runAsync(() async {
          await _hold(
            isHosted: isHosted,
            isPro: isPro,
            isOwnServer: isOwnServer,
          );
          if (isHosted && !isOwnServer) {
            // Enrolled, with the last round received.
            getIt<MockServer>().seedWeeklyCheck(WeeklyCheckState.received);
          }
          // A read may be out already, started by the switches. The second
          // call is the one sure to read after the seed.
          final monitor = getIt<WeeklyCheckMonitor>();
          await monitor.refresh(force: true);
          await monitor.refresh(force: true);
        });
        final key = await _open(
          tester,
          location: '/settings/reliability',
          mode: mode,
        );
        await _show(tester, find.text(LocaleKeys.weekly_check_title.tr()));
        await _save(tester, key, 'reliability_${name}_${mode.name}');
      });
    }

    for (final (name, isHosted, isPro) in icons) {
      capture('app_icon_${name}_${mode.name}', (tester) async {
        await tester.runAsync(() => _hold(isHosted: isHosted, isPro: isPro));
        final key = await _open(tester, location: '/app-icon', mode: mode);
        // On to the first paid icon.
        await tester.drag(find.byType(PageView), const Offset(-300, 0));
        for (var i = 0; i < 4; i++) {
          await tester.pump(const Duration(milliseconds: 200));
        }
        await _save(tester, key, 'app_icon_${name}_${mode.name}');
      });
    }

    capture('settings_free_${mode.name}', (tester) async {
      await tester.runAsync(() => _hold(isHosted: false, isPro: false));
      final key = await _open(tester, location: '/settings', mode: mode);
      await _show(
        tester,
        find.text(LocaleKeys.settings_storage_row_title.tr()),
      );
      await _save(tester, key, 'settings_free_${mode.name}');
    });

    capture('storage_free_${mode.name}', (tester) async {
      await tester.runAsync(() => _hold(isHosted: false, isPro: false));
      final key = await _open(
        tester,
        location: '/settings/alarms',
        mode: mode,
      );
      await _save(tester, key, 'storage_free_${mode.name}');
    });
  }
}
